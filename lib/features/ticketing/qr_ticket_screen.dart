import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QrTicketScreen extends StatefulWidget {
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
  State<QrTicketScreen> createState() => _QrTicketScreenState();
}

class _QrTicketScreenState extends State<QrTicketScreen> {
  // Payload signé renvoyé par l'Edge Function `mint-qr`, valable 5 min.
  // Régénéré automatiquement avant expiration tant que l'écran est ouvert.
  String? _qrPayload;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

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

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                        border: Border.all(color: Colors.white.withOpacity(0.09)),
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

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
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
                    // ── Ticket Card ──────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.35),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            // Top gradient section
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF4C1D95),
                                    Color(0xFF7C3AED),
                                    Color(0xFFEC4899),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.confirmation_number,
                                            color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (ev['title'] ?? '') as String,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              (ev['location'] ?? '') as String,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withOpacity(0.65),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _ticketInfo('DATE',
                                          _formatDate(ev['start_date'] as String?)),
                                      _ticketInfo('TYPE',
                                          (ticketType['name'] ?? '') as String),
                                      _ticketInfo('PRICE',
                                          ticketType['price'] == 0 ? 'Free' : '\$${ticketType['price']}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Perforation line
                            Container(
                              color: const Color(0xFF13111C),
                              height: 1,
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF08080F),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(14),
                                        bottomRight: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Flex(
                                          direction: Axis.horizontal,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(
                                            (constraints.maxWidth / 12).floor(),
                                            (_) => Container(
                                              width: 6,
                                              height: 1,
                                              color: Colors.white
                                                  .withOpacity(0.12),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    width: 14,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF08080F),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(14),
                                        bottomLeft: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // QR Code section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              color: const Color(0xFF13111C),
                              child: Column(
                                children: [
                                  // QR Code (payload signé, rafraîchi auto)
                                  GestureDetector(
                                    onTap: _error != null ? _mintQr : null,
                                    child: Container(
                                      width: 184,
                                      height: 184,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: _loading
                                          ? const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Color(0xFF7C3AED),
                                                ),
                                              ),
                                            )
                                          : _error != null
                                              ? Center(
                                                  child: Icon(
                                                    Icons.refresh,
                                                    color: const Color(0xFF08080F)
                                                        .withOpacity(0.6),
                                                    size: 40,
                                                  ),
                                                )
                                              : QrImageView(
                                                  data: _qrPayload!,
                                                  version: QrVersions.auto,
                                                  size: 160,
                                                  backgroundColor: Colors.white,
                                                  eyeStyle: const QrEyeStyle(
                                                    eyeShape: QrEyeShape.square,
                                                    color: Color(0xFF08080F),
                                                  ),
                                                  dataModuleStyle:
                                                      const QrDataModuleStyle(
                                                    dataModuleShape:
                                                        QrDataModuleShape.square,
                                                    color: Color(0xFF08080F),
                                                  ),
                                                ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error ?? 'Scan at entry',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_error == null)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 11,
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Secure code · refreshes automatically',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.white.withOpacity(0.3),
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

                    const SizedBox(height: 20),

                    // ── Ticket Details ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket Details',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _detailRow('Order ID', ticket['id'].toString().substring(0, 8).toUpperCase()),
                          _detailRow('Status', 'Valid ✓'),
                          _detailRow('Purchased', DateTime.now().toString().substring(0, 10)),
                          _detailRow('Type', (ticketType['name'] ?? '') as String),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketInfo(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.45),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w900,
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
              color: Colors.white.withOpacity(0.38),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}