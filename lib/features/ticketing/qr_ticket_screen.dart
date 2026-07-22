import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/providers/tickets_provider.dart';
import 'package:happyn/core/events/event_utils.dart';

class QrTicketScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> ticket;
  final Map<String, dynamic> event;
  final Map<String, dynamic> ticketType;

  /// Nombre total de billets émis dans cet achat (pour le bandeau « 1 of N »).
  final int totalTickets;

  const QrTicketScreen({
    super.key,
    required this.ticket,
    required this.event,
    required this.ticketType,
    this.totalTickets = 1,
  });

  @override
  ConsumerState<QrTicketScreen> createState() => _QrTicketScreenState();
}

class _QrTicketScreenState extends ConsumerState<QrTicketScreen> {
  // Payload signé renvoyé par l'Edge Function `mint-qr`, valable 5 min.
  // Régénéré automatiquement avant expiration tant que l'écran est ouvert.
  String? _qrPayload;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  static const _bg = Color(0xFF13111C);
  static const _page = Color(0xFF08080F);

  @override
  void initState() {
    super.initState();
    // Block screenshots on this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    _mintQr();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  /// Demande un QR signé fraîchement au serveur, puis programme un rafraîchissement
  /// automatique avant l'expiration (TTL renvoyé par la fonction, moins une marge).
  Future<void> _mintQr() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'mint-qr',
        body: {'ticket_id': widget.ticket['id']},
      );

      final data = res.data as Map<String, dynamic>;
      final payload = data['qr_payload'] as String?;
      final ttl = (data['ttl_seconds'] as num?)?.toInt() ?? 300;

      if (payload == null) throw Exception('empty_payload');

      // DEBUG : permet de copier le payload depuis la console pour tester
      // le scanner sans caméra (mode « coller le payload »).
      assert(() {
        debugPrint('QR_PAYLOAD => $payload');
        return true;
      }());

      if (!mounted) return;
      setState(() {
        _qrPayload = payload;
        _loading = false;
      });

      // Rafraîchit ~1 min avant l'expiration (TTL 5 min -> refresh à 4 min).
      final refreshIn = Duration(seconds: (ttl - 60).clamp(30, ttl));
      _refreshTimer?.cancel();
      _refreshTimer = Timer(refreshIn, _mintQr);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your ticket QR. Tap to retry.';
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    final dt = DateTime.parse(dateStr);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final ticket = widget.ticket;
    final ticketType = widget.ticketType;
    final cat = (ev['category'] ?? '') as String;
    final accent = categoryColor(cat);
    final cancelled = (ev['status'] ?? 'published') == 'cancelled';
    final priceText = ticketType['price'] == 0 || ticketType['price'] == null
        ? 'Free'
        : '\$${ticketType['price']}';

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.09)),
                      ),
                      child: const Icon(Icons.home_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'My Ticket',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    // Bandeau annulation
                    if (cancelled)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4B4B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF4B4B).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel,
                                color: Color(0xFFFF4B4B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This event was cancelled by the organizer. '
                                'This ticket is no longer valid.',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Bandeau achat multiple
                    if (widget.totalTickets > 1)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.confirmation_number,
                                color: Color(0xFFC4B5FD), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ticket 1 of ${widget.totalTickets} · all ${widget.totalTickets} are in “My Tickets”',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Le billet ─────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.3),
                            blurRadius: 44,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            // Image hero + catégorie + titre
                            SizedBox(
                              height: 148,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: (ev['image_url'] ?? '') as String,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                        color: const Color(0xFF1A0F3D)),
                                    errorWidget: (_, _, _) => Container(
                                      color: const Color(0xFF1A0F3D),
                                      child: Icon(categoryIcon(cat),
                                          color: const Color(0xFF7C3AED),
                                          size: 40),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.15),
                                          Colors.transparent,
                                          _bg,
                                        ],
                                        stops: const [0, 0.4, 1],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 16,
                                    right: 16,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(categoryIcon(cat),
                                                size: 13, color: accent),
                                            const SizedBox(width: 5),
                                            Text(
                                              cat,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (ev['title'] ?? '') as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Infos date / type / prix
                            Container(
                              color: _bg,
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                              child: Row(
                                children: [
                                  _info('DATE',
                                      _formatDate(ev['start_date'] as String?)),
                                  _info('TYPE',
                                      (ticketType['name'] ?? '') as String),
                                  _info('PRICE', priceText),
                                ],
                              ),
                            ),

                            // Perforation
                            _perforation(),

                            // Zone QR
                            Container(
                              width: double.infinity,
                              color: _bg,
                              padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                              child: Column(
                                children: [
                                  _qrBox(),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error ?? 'Scan at entry',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (_error == null)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_outline,
                                            size: 12,
                                            color:
                                                Colors.white.withOpacity(0.35)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Secure code · refreshes automatically',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color:
                                                Colors.white.withOpacity(0.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Détails ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket Details',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _detailRow(
                              'Order ID',
                              ticket['id']
                                  .toString()
                                  .substring(0, 8)
                                  .toUpperCase()),
                          _detailRow('Type',
                              (ticketType['name'] ?? '') as String),
                          _detailRow('Status', 'Valid ✓'),
                          _detailRow('Venue', (ev['location'] ?? '—') as String),
                        ],
                      ),
                    ),

                    // ── Transfert ──────────────────────────────────
                    if (!cancelled && !isEventPast(ev)) ...[
                      const SizedBox(height: 14),
                      _TransferButton(onTap: _openTransferSheet),
                      const SizedBox(height: 4),
                      Text(
                        'Send this ticket to another HAPPYN user by email.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transfert de billet ────────────────────────────────────────────────────
  void _openTransferSheet() {
    final controller = TextEditingController();
    bool sending = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            Future<void> submit() async {
              final email = controller.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                setSheet(() => errorText = 'Enter a valid email address.');
                return;
              }
              setSheet(() {
                sending = true;
                errorText = null;
              });
              try {
                await Supabase.instance.client.rpc('transfer_ticket', params: {
                  'p_ticket_id': widget.ticket['id'],
                  'p_recipient_email': email,
                });
                // Le billet a changé de propriétaire : rafraîchir "My Tickets".
                ref.invalidate(myTicketsProvider);
                if (!sheetCtx.mounted) return;
                Navigator.of(sheetCtx).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF16A34A),
                    content: Text('Ticket sent to $email 🎟️',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                );
                // On quitte l'écran : ce billet ne nous appartient plus.
                Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                setSheet(() {
                  sending = false;
                  errorText = _transferError(e);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Transfer ticket',
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The recipient must already have a HAPPYN account. '
                    'Once sent, this ticket leaves your account.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.white.withOpacity(0.55),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    enabled: !sending,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'friend@email.com',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      prefixIcon: Icon(Icons.alternate_email,
                          color: Colors.white.withOpacity(0.4), size: 20),
                      errorText: errorText,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.09)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.09)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: sending ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        disabledBackgroundColor:
                            const Color(0xFF7C3AED).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(
                              'Send ticket',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _transferError(Object e) {
    final msg = e.toString();
    if (msg.contains('recipient_not_found')) {
      return 'No HAPPYN account found with that email.';
    }
    if (msg.contains('cannot_transfer_self')) {
      return 'That ticket is already yours.';
    }
    if (msg.contains('ticket_not_transferable')) {
      return 'This ticket can no longer be transferred.';
    }
    if (msg.contains('event_cancelled')) {
      return 'This event was cancelled.';
    }
    if (msg.contains('event_ended')) {
      return 'This event has already ended.';
    }
    return 'Transfer failed. Please try again.';
  }

  // ── QR (loading / error / code) ────────────────────────────────────────────
  Widget _qrBox() {
    return GestureDetector(
      onTap: _error != null ? _mintQr : null,
      child: Container(
        width: 210,
        height: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.6, color: Color(0xFF7C3AED)),
                ),
              )
            : _error != null
                ? Center(
                    child: Icon(Icons.refresh,
                        color: _page.withOpacity(0.6), size: 44),
                  )
                : QrImageView(
                    data: _qrPayload!,
                    version: QrVersions.auto,
                    size: 182,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _page,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _page,
                    ),
                  ),
      ),
    );
  }

  // ── Perforation (encoches + pointillés) ────────────────────────────────────
  Widget _perforation() {
    return Container(
      color: _bg,
      height: 26,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 26,
            decoration: const BoxDecoration(
              color: _page,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (c.maxWidth / 12).floor(),
                  (_) => Container(
                    width: 6,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 16,
            height: 26,
            decoration: const BoxDecoration(
              color: _page,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton « Transfer ticket » (contour discret, ne concurrence pas le QR).
class _TransferButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TransferButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.send_outlined, size: 18, color: Colors.white),
        label: Text(
          'Transfer ticket',
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.16)),
          backgroundColor: Colors.white.withOpacity(0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
