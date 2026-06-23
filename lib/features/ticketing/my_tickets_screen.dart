import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'qr_ticket_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = upcoming, 1 = past

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('tickets')
          .select('''
            *,
            events(*),
            ticket_types(*)
          ''')
          .eq('user_id', user.id)
          .order('purchased_at', ascending: false);

      setState(() {
        _tickets = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    final now = DateTime.now();
    return _tickets.where((t) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Tickets',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: _loadTickets,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: const Icon(Icons.refresh,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED)))
                : _filteredTickets.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredTickets.length,
                        itemBuilder: (context, i) =>
                            _TicketCard(
                              ticket: _filteredTickets[i],
                              onTap: () => _openTicket(_filteredTickets[i]),
                            ),
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

    String formatDate(String? d) {
      if (d == null) return 'TBD';
      final dt = DateTime.parse(d);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: status == 'used'
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFF7C3AED).withOpacity(0.25),
          ),
          boxShadow: status == 'valid'
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Image header
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: const Color(0xFF1A0F3D)),
                      errorWidget: (_, _, _) =>
                          Container(color: const Color(0xFF1A0F3D)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    // Status badge
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'valid'
                              ? const Color(0xFF1DB954)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status == 'valid' ? '✓ Valid' : status.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Event title
                    Positioned(
                      bottom: 10,
                      left: 12,
                      right: 12,
                      child: Text(
                        (event['title'] ?? '') as String,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Info row
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF13111C),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: Color(0xFFA78BFA), size: 11),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(event['start_date'] as String?),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (ticketType['name'] ?? 'Ticket') as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'View QR',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
    );
  }
}