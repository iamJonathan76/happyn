import 'package:flutter/material.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happyn/core/config/stripe_config.dart';
import 'package:happyn/core/providers/tickets_provider.dart';
import 'package:happyn/core/providers/notifications_provider.dart';
import 'package:happyn/core/utils/age.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'qr_ticket_screen.dart';
import 'payment_processing_screen.dart';

class TicketSelectionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const TicketSelectionScreen({super.key, required this.event});

  @override
  ConsumerState<TicketSelectionScreen> createState() =>
      _TicketSelectionScreenState();
}

class _TicketSelectionScreenState
    extends ConsumerState<TicketSelectionScreen> {
  List<Map<String, dynamic>> _ticketTypes = [];
  bool _isLoading = true;
  int? _selectedTypeIndex;
  int _quantity = 1;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadTicketTypes();
  }

  Future<void> _loadTicketTypes() async {
    try {
      final data = await Supabase.instance.client
          .from('ticket_types')
          .select()
          .eq('event_id', widget.event['id'])
          .order('price');

      setState(() {
        _ticketTypes = List<Map<String, dynamic>>.from(data);
        if (_ticketTypes.isNotEmpty) _selectedTypeIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _totalPrice {
    if (_selectedTypeIndex == null) return 0;
    final price = _ticketTypes[_selectedTypeIndex!]['price'] ?? 0;
    return (price as num).toDouble() * _quantity;
  }

  // Limite de billets par personne, fixée par l'organisateur sur le tier.
  int get _maxQuantity {
    if (_selectedTypeIndex == null) return 10;
    final m = _ticketTypes[_selectedTypeIndex!]['max_per_order'];
    return (m is int && m > 0) ? m : 10;
  }

  String get _priceText {
    if (_totalPrice == 0) return AppLocalizations.of(context).free;
    return '\$${_totalPrice.toStringAsFixed(2)}';
  }

  void _showAgeBlocked(int minAge) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.ageRequirementLabel,
            style: AppText.h4.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          l.ageBlockedBody(minAge),
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.ok,
                style: AppText.body.copyWith(color: AppColors.lavender)),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseTicket() async {
    if (_selectedTypeIndex == null) return;
    final l = AppLocalizations.of(context);

    // Soft-gate d'âge : si l'event a une exigence et que l'âge connu est en
    // dessous, on bloque. Âge inconnu (ancien compte) → on laisse passer.
    final minAge = (widget.event['min_age'] ?? 0) as int;
    if (minAge > 0) {
      final age = currentUserAge();
      if (age != null && age < minAge) {
        _showAgeBlocked(minAge);
        return;
      }
    }

    setState(() => _isPurchasing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final selectedType = _ticketTypes[_selectedTypeIndex!];
      final ticketTypeId = selectedType['id'] as String;
      final unitPrice = (selectedType['price'] ?? 0 as num).toDouble();

      // ── Event GRATUIT : émission directe, pas de Stripe ────────────────
      if (unitPrice <= 0) {
        final rows = await Supabase.instance.client.rpc(
          'issue_tickets',
          params: {
            'p_ticket_type_id': ticketTypeId,
            'p_quantity': _quantity,
          },
        );
        final tickets = List<Map<String, dynamic>>.from(rows as List);
        if (tickets.isEmpty) throw Exception('no_ticket_created');

        ref.invalidate(myTicketsProvider); // My Tickets se rafraîchit
        ref.invalidate(notificationsProvider); // notif « billet confirmé »

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QrTicketScreen(
                ticket: tickets.first,
                event: widget.event,
                ticketType: selectedType,
                totalTickets: tickets.length,
              ),
            ),
          );
        }
        return;
      }

      // ── Event PAYANT : paiement Stripe avant émission ──────────────────
      if (!StripeConfig.isConfigured) {
        throw Exception('payments_not_configured');
      }

      // 1. PaymentIntent (montant calculé côté serveur)
      final res = await Supabase.instance.client.functions.invoke(
        'create-payment-intent',
        body: {'ticket_type_id': ticketTypeId, 'quantity': _quantity},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      final clientSecret = data['client_secret'] as String;
      final paymentIntentId = data['payment_intent_id'] as String;

      // 2. PaymentSheet Stripe
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'HAPPYN',
          style: ThemeMode.dark,
        ),
      );
      // Lance `StripeException` si l'utilisateur annule ou si le paiement échoue.
      await Stripe.instance.presentPaymentSheet();

      // 3. Paiement OK -> l'émission se fait via webhook ; on poll le ticket.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentProcessingScreen(
              paymentIntentId: paymentIntentId,
              event: widget.event,
              ticketType: selectedType,
            ),
          ),
        );
      }
    } on StripeException catch (_) {
      // Annulation ou échec côté Stripe : on reste sur l'écran, message discret.
      if (mounted) {
        showAppSnack(context, l.paymentCancelled);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final friendly = msg.contains('event_ended')
            ? l.errEventEndedTickets
            : msg.contains('exceeds_max_per_order')
            ? l.errLimitPerPerson
            : msg.contains('insufficient_stock')
            ? l.errNotEnoughTickets
            : msg.contains('not_authenticated')
                ? l.errSignInAgain
                : msg.contains('ticket_type_not_found')
                    ? l.errTicketUnavailable
                    : msg.contains('payments_not_configured')
                        ? l.errPaymentsNotSetup
                        : l.errSomethingWrong;
        showAppSnack(context, friendly);
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ev = widget.event;
    final imageUrl = (ev['image_url'] ?? '') as String;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.imagePlaceholder),
                  errorWidget: (_, _, _) => Container(color: AppColors.imagePlaceholder),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x44080F0F), AppColors.background],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (ev['title'] ?? '') as String,
                        style: AppText.h1.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.lavender, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            (ev['location'] ?? '') as String,
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _ticketTypes.isEmpty
                    ? _buildNoTickets()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.selectTicketType,
                              style: AppText.h2.copyWith(fontSize: 18, color: Colors.white),
                            ),
                            const SizedBox(height: 14),

                            // Ticket types
                            ...List.generate(_ticketTypes.length, (i) {
                              final t = _ticketTypes[i];
                              final isSelected = i == _selectedTypeIndex;
                              final price = t['price'] ?? 0;
                              final priceText = (price == 0) ? 'Free' : '\$$price';
                              final sold = t['quantity_sold'] ?? 0;
                              final total = t['quantity_total'] ?? 100;
                              final remaining = total - sold;
                              final isSoldOut = remaining <= 0;

                              return GestureDetector(
                                onTap: isSoldOut
                                    ? null
                                    : () => setState(() {
                                          _selectedTypeIndex = i;
                                          _quantity = 1;
                                        }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white.withOpacity(0.08),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Radio
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textLow,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Center(
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  (t['name'] ?? '') as String,
                                                  style: AppText.h4.copyWith(color: isSoldOut
                                                        ? AppColors.textLow
                                                        : Colors.white),
                                                ),
                                                if (remaining <= 10 && !isSoldOut) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.pink
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      l.onlyLeft(remaining),
                                                      style: AppText.microBold.copyWith(color: AppColors.pink),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if ((t['perks'] as List?)?.isNotEmpty == true) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                (t['perks'] as List).join(' · '),
                                                style: AppText.small,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Price
                                      Text(
                                        isSoldOut ? l.soldOut : priceText,
                                        style: AppText.h3.copyWith(fontWeight: FontWeight.w900, color: isSoldOut
                                              ? AppColors.textLow
                                              : AppColors.lavenderLight),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 20),

                            // Quantity selector
                            if (_selectedTypeIndex != null) ...[
                              Text(
                                l.quantity,
                                style: AppText.h3.copyWith(fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _qtyButton(
                                    Icons.remove,
                                    () => setState(() {
                                      if (_quantity > 1) _quantity--;
                                    }),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Text(
                                      '$_quantity',
                                      style: AppText.display.copyWith(fontSize: 22, color: Colors.white),
                                    ),
                                  ),
                                  _qtyButton(
                                    Icons.add,
                                    () => setState(() {
                                      if (_quantity < _maxQuantity) _quantity++;
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),

      // ── Bottom CTA ────────────────────────────────────────────────
      bottomNavigationBar: _selectedTypeIndex != null
          ? Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0B1A),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.07))),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.total,
                        style: AppText.small,
                      ),
                      Text(
                        _priceText,
                        style: AppText.display.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isPurchasing ? null : _purchaseTicket,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.pink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.55),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isPurchasing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_outline,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      l.checkout,
                                      style: AppText.h3.copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildNoTickets() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 48, color: AppColors.textFaint),
          const SizedBox(height: 16),
          Text(
            l.noTicketsAvailable,
            style: AppText.body.copyWith(color: AppColors.textLow),
          ),
          const SizedBox(height: 8),
          Text(
            l.organizerNoTickets,
            style: AppText.caption.copyWith(color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}