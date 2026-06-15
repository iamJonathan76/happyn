import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/features/events/event_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;
  String _activeFilter = 'All';
  String _searchQuery = '';

  final _filters = [
    'All',
    'Tonight',
    'Free',
    'Music',
    'Party',
    'Networking',
    'Festival',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _allEvents = List<Map<String, dynamic>>.from(data);
        _filteredEvents = _allEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_allEvents);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((ev) {
        final title = (ev['title'] ?? '').toString().toLowerCase();
        final location = (ev['location'] ?? '').toString().toLowerCase();
        final category = (ev['category'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) ||
            location.contains(_searchQuery) ||
            category.contains(_searchQuery);
      }).toList();
    }

    // Category/quick filter
    if (_activeFilter != 'All') {
      if (_activeFilter == 'Free') {
        result = result.where((ev) => (ev['price'] ?? 0) == 0).toList();
      } else if (_activeFilter == 'Tonight') {
        final now = DateTime.now();
        final tonight = DateTime(now.year, now.month, now.day);
        result = result.where((ev) {
          if (ev['start_date'] == null) return false;
          final date = DateTime.parse(ev['start_date']);
          return date.year == tonight.year &&
              date.month == tonight.month &&
              date.day == tonight.day;
        }).toList();
      } else {
        result = result
            .where(
              (ev) =>
                  (ev['category'] ?? '').toString().toLowerCase() ==
                  _activeFilter.toLowerCase(),
            )
            .toList();
      }
    }

    _filteredEvents = result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Discover',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Search Bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.09)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.38),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Events, venues, artists...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.38),
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Filters ─────────────────────────────────────────────
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, right: 8),
              itemCount: _filters.length,
              itemBuilder: (context, i) {
                final f = _filters[i];
                final isActive = f == _activeFilter;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeFilter = f;
                      _applyFilters();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : Colors.white.withOpacity(0.055),
                      borderRadius: BorderRadius.circular(20),
                      border: isActive
                          ? null
                          : Border.all(color: Colors.white.withOpacity(0.09)),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF7C3AED,
                                ).withOpacity(0.55),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.42),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Results count ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${_filteredEvents.length} event${_filteredEvents.length != 1 ? 's' : ''} found',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Results ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  )
                : _filteredEvents.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, i) =>
                        _DiscoverCard(event: _filteredEvents[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 52,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No events in this category yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or filter',
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

// ─── Discover Card ────────────────────────────────────────────────────────────

class _DiscoverCard extends StatefulWidget {
  final Map<String, dynamic> event;
  const _DiscoverCard({required this.event});

  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final imageUrl = (ev['image_url'] ?? '') as String;
    final price = ev['price'];
    final priceText = (price == null || price == 0) ? 'Free' : '\$$price';
    final date = ev['start_date'] != null
        ? DateTime.parse(ev['start_date']).toString().substring(0, 10)
        : 'TBD';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: widget.event),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                      size: 32,
                    ),
                  ),
                ),
              ),

              // Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xAA08080F),
                      Color(0xFF08080F),
                    ],
                    stops: [0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // Category badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (ev['category'] ?? '') as String,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Like button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _liked = !_liked),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? const Color(0xFFEC4899) : Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),

              // Content bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (ev['title'] ?? '') as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  color: Color(0xFFA78BFA),
                                  size: 9,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    date,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white.withOpacity(0.55),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            priceText,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC4B5FD),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
