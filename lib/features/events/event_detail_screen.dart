import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/features/ticketing/ticket_selection_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _liked = false;

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    final dt = DateTime.parse(dateStr);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'TBD';
    final dt = DateTime.parse(dateStr);
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final imageUrl = (ev['image_url'] ?? '') as String;
    final price = ev['price'];
    final priceText = (price == null || price == 0) ? 'Free' : '\$$price';
    final isOrganizer = false; // TODO: check if current user is organizer

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Stack(
        children: [
          // ── Scrollable Content ───────────────────────────────────
          CustomScrollView(
            slivers: [
              // Hero Image
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFF1A0F3D)),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1A0F3D),
                          child: const Center(
                            child: Icon(
                              Icons.event,
                              color: Color(0xFF7C3AED),
                              size: 48,
                            ),
                          ),
                        ),
                      ),

                      // Gradient overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66080F0F),
                              Colors.transparent,
                              Color(0xCC08080F),
                              Color(0xFF08080F),
                            ],
                            stops: [0.0, 0.35, 0.78, 1.0],
                          ),
                        ),
                      ),

                      // Top bar
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),

                              // Share + Like
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.12),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.share_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _liked = !_liked),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.12),
                                        ),
                                      ),
                                      child: Icon(
                                        _liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: _liked
                                            ? const Color(0xFFEC4899)
                                            : Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Category badge
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🔥 ${(ev['category'] ?? 'Event') as String}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        (ev['title'] ?? '') as String,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info grid
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              Icons.calendar_today_outlined,
                              'Date',
                              _formatDate(ev['start_date'] as String?),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _infoCard(
                              Icons.access_time_outlined,
                              'Time',
                              _formatTime(ev['start_date'] as String?),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              Icons.location_on_outlined,
                              'Venue',
                              (ev['location'] ?? 'TBD') as String,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _infoCard(
                              Icons.location_city_outlined,
                              'City',
                              (ev['city'] ?? 'TBD') as String,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Description
                      if (ev['description'] != null &&
                          (ev['description'] as String).isNotEmpty) ...[
                        Text(
                          'About this event',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ev['description'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.55),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tag(ev['category'] ?? 'Event'),
                          if ((ev['city'] ?? '').toString().isNotEmpty)
                            _tag(ev['city']),
                          if ((ev['price'] ?? 0) == 0) _tag('Free Entry'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky Bottom CTA ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF08080F).withOpacity(0),
                    const Color(0xFF08080F),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Starting from',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.38),
                        ),
                      ),
                      Text(
                        priceText,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // CTA Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TicketSelectionScreen(event: ev),
                          ),
                        );
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withOpacity(0.55),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Get Tickets',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFA78BFA), size: 14),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.38),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _tag(dynamic label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.28)),
      ),
      child: Text(
        '#$label',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFC4B5FD),
        ),
      ),
    );
  }
}
