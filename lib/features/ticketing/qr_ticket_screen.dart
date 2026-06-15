import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrTicketScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Map<String, dynamic> event;
  final Map<String, dynamic> ticketType;

  const QrTicketScreen({
    super.key,
    required this.ticket,
    required this.event,
    required this.ticketType,
  });

  @override
  State<QrTicketScreen> createState() => _QrTicketScreenState();
}

class _QrTicketScreenState extends State<QrTicketScreen> {
  @override
  void initState() {
    super.initState();
    // Block screenshots on this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
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
    final qrToken = ticket['qr_token'] as String;

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
                                  // QR Code
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: QrImageView(
                                      data: qrToken,
                                      version: QrVersions.auto,
                                      size: 160,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF08080F),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF08080F),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Scan at entry',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    qrToken,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.25),
                                    ),
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