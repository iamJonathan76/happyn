import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/providers/tickets_provider.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'qr_ticket_screen.dart';

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  int _selectedTab = 0; // 0 = upcoming, 1 = past

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> tickets) {
    final now = DateTime.now();
    return tickets.where((t) {
      final event = t['events'] as Map<String, dynamic>?;
      if (event == null) return false;
      final startDate = event['start_date'];
      if (startDate == null) return _selectedTab == 0;
      final eventDate = DateTime.parse(startDate as String);
      return _selectedTab == 0
          ? eventDate.isAfter(now)
          : eventDate.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Tickets',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['Upcoming', 'Past'].asMap().entries.map((e) {
                final isActive = e.key == _selectedTab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: isActive
                          ? null
                          : Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Text(
                      e.value,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
              error: (_, __) => _buildEmptyState(),
              data: (all) {
                final filtered = _filtered(all);
                return RefreshIndicator(
                  color: const Color(0xFF7C3AED),
                  backgroundColor: const Color(0xFF1A1535),
                  onRefresh: () async {
                    ref.invalidate(myTicketsProvider);
                    await ref.read(myTicketsProvider.future);
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                                height: 360, child: _buildEmptyState()),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _TicketCard(
                            ticket: filtered[i],
                            onTap: () => _openTicket(filtered[i]),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openTicket(Map<String, dynamic> ticket) {
    final event = ticket['events'] as Map<String, dynamic>? ?? {};
    final ticketType = ticket['ticket_types'] as Map<String, dynamic>? ?? {};

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrTicketScreen(
          ticket: ticket,
          event: event,
          ticketType: ticketType,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 52, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0
                ? 'No upcoming tickets'
                : 'No past tickets',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover events and buy your first ticket!',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final event = ticket['events'] as Map<String, dynamic>? ?? {};
    final ticketType = ticket['ticket_types'] as Map<String, dynamic>? ?? {};
    final imageUrl = (event['image_url'] ?? '') as String;
    final status = (ticket['status'] ?? 'valid') as String;
    final eventCancelled = (event['status'] ?? 'published') == 'cancelled';
    final cat = (event['category'] ?? '') as String;
    final accent = categoryColor(cat);
    final isValid = status == 'valid' && !eventCancelled;
    const bg = Color(0xFF13111C);

    String formatDate(String? d) {
      if (d == null) return 'TBD';
      final dt = DateTime.parse(d);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isValid ? 1 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: isValid
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    )
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                // ── Image (moitié haute du billet) ──────────────────
                SizedBox(
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: const Color(0xFF1A0F3D)),
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFF1A0F3D),
                          child: Icon(categoryIcon(cat),
                              color: const Color(0xFF7C3AED), size: 34),
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
                              bg,
                            ],
                            stops: const [0, 0.4, 1],
                          ),
                        ),
                      ),
                      // Status badge
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: eventCancelled
                                ? const Color(0xFFFF4B4B)
                                : isValid
                                    ? const Color(0xFF1DB954)
                                    : Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            eventCancelled
                                ? 'Cancelled'
                                : isValid
                                    ? '✓ Valid'
                                    : status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Category + title
                      Positioned(
                        bottom: 10,
                        left: 14,
                        right: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(categoryIcon(cat),
                                    size: 12, color: accent),
                                const SizedBox(width: 5),
                                Text(
                                  cat,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (event['title'] ?? '') as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
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

                // ── Perforation (encoches + pointillés) ─────────────
                _perforation(bg),

                // ── Bas du billet ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  color: bg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    color: accent, size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  formatDate(event['start_date'] as String?),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (ticketType['name'] ?? 'Ticket') as String,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: isValid
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFFEC4899)
                                  ],
                                )
                              : null,
                          color: isValid ? null : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code,
                                color: Colors.white, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              'View QR',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // Bande de perforation : encoches sur les côtés + pointillés (look billet).
  Widget _perforation(Color bg) {
    const notchColor = Color(0xFF08080F);
    return Container(
      color: bg,
      height: 22,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 22,
            decoration: const BoxDecoration(
              color: notchColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (c.maxWidth / 11).floor(),
                  (_) => Container(
                    width: 5,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 14,
            height: 22,
            decoration: const BoxDecoration(
              color: notchColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}