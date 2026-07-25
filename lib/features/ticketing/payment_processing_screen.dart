import 'dart:async';
import 'package:happyn/core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/tickets_provider.dart';
import 'package:happyn/core/providers/notifications_provider.dart';
import 'qr_ticket_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Après un paiement réussi, l'émission du ticket se fait côté serveur (webhook
/// Stripe), donc de façon asynchrone. Cet écran poll la table `tickets` jusqu'à
/// ce que le ticket lié au PaymentIntent apparaisse, puis ouvre le QR.
class PaymentProcessingScreen extends ConsumerStatefulWidget {
  final String paymentIntentId;
  final Map<String, dynamic> event;
  final Map<String, dynamic> ticketType;

  const PaymentProcessingScreen({
    super.key,
    required this.paymentIntentId,
    required this.event,
    required this.ticketType,
  });

  @override
  ConsumerState<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState
    extends ConsumerState<PaymentProcessingScreen> {
  static const _maxAttempts = 20; // ~20s à 1s d'intervalle
  int _attempts = 0;
  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_timedOut) return;
    _attempts++;

    try {
      final rows = await Supabase.instance.client
          .from('tickets')
          .select()
          .eq('payment_intent_id', widget.paymentIntentId);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty) {
        _timer?.cancel();
        ref.invalidate(myTicketsProvider); // My Tickets se rafraîchit
        ref.invalidate(notificationsProvider); // notif « billet confirmé »
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QrTicketScreen(
              ticket: list.first,
              event: widget.event,
              ticketType: widget.ticketType,
              totalTickets: list.length,
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // on réessaiera au prochain tick
    }

    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      if (mounted) setState(() => _timedOut = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _timedOut ? _timeoutView() : _loadingView(),
        ),
      ),
    );
  }

  Widget _loadingView() {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        const SizedBox(height: 28),
        Text(
          l.paymentReceived,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.issuingTicket,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _timeoutView() {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_bottom,
            color: AppColors.warning, size: 64),
        const SizedBox(height: 20),
        Text(
          l.almostThere,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.paymentDelayBody,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.pink],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l.backToHome,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
