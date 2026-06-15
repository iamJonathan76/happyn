import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/features/events/event_detail_screen.dart';

const _categories = [
  'All',
  'Music',
  'Party',
  'Festival',
  'Networking',
  'Art',
  'Sports',
];

const _communities = [
  {'name': 'Ottawa Nightlife', 'members': '14.2K', 'emoji': '🌆'},
  {'name': 'EDM Heads', 'members': '8.9K', 'emoji': '🎧'},
  {'name': 'Gatineau Vibes', 'members': '6.1K', 'emoji': '⚡'},
  {'name': 'Rooftop Crew', 'members': '4.3K', 'emoji': '🌃'},
  {'name': 'Art Scene', 'members': '3.8K', 'emoji': '🎨'},
];

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _eventsFromDb = [];
  bool _isLoadingEvents = true;
  int _selectedCat = 0;

  final user = Supabase.instance.client.auth.currentUser;

  String get userName => user?.userMetadata?['full_name'] ?? 'User';

  String get userInitials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName.substring(0, 1).toUpperCase();
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_selectedCat == 0)
      return List<Map<String, dynamic>>.from(_eventsFromDb);
    final cat = _categories[_selectedCat];
    return _eventsFromDb
        .where((e) => e['category'] == cat)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _eventsFromDb = List<Map<String, dynamic>>.from(data);
        _isLoadingEvents = false;
      });
    } catch (e) {
      setState(() => _isLoadingEvents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
          ),
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildLocation()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(
            child: _buildSectionHeader('Featured Tonight', 'See all'),
          ),
          SliverToBoxAdapter(child: _buildHeroCards()),
          SliverToBoxAdapter(
            child: _buildSectionHeader('This Weekend', 'See all'),
          ),
          SliverToBoxAdapter(child: _buildCompactList()),
          SliverToBoxAdapter(
            child: _buildSectionHeader('Trending Scenes', 'Explore'),
          ),
          SliverToBoxAdapter(child: _buildCommunities()),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOOD EVENING',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF0EEFF).withOpacity(0.38),
                  letterSpacing: 2,
                ),
              ),
              Text(
                '$userName 🔥',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.09)),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                            ),
                            border: Border.all(
                              color: const Color(0xFF08080F),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.55),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    userInitials,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
            Icon(Icons.search, color: Colors.white.withOpacity(0.35), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search events, artists, venues...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.32),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, color: Color(0xFFA78BFA), size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Color(0xFFEC4899), size: 13),
          const SizedBox(width: 5),
          Text(
            'Ottawa, ON · ${_eventsFromDb.length} events near you',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF0EEFF).withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8, top: 6),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final isActive = i == _selectedCat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCat = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          color: const Color(0xFF7C3AED).withOpacity(0.55),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _categories[i],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : const Color(0xFFF0EEFF).withOpacity(0.45),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Text(
                action,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFA78BFA),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFA78BFA),
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCards() {
    if (_isLoadingEvents) {
      return const SizedBox(
        height: 210,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      );
    }
    final events = _filteredEvents;
    if (events.isEmpty) {
      return SizedBox(
        height: 210,
        child: Center(
          child: Text(
            'No events yet — create the first one! 🎉',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: events.length,
        itemBuilder: (context, i) => _HeroCard(event: events[i]),
      ),
    );
  }

  Widget _buildCompactList() {
    if (_eventsFromDb.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _eventsFromDb
            .skip(1)
            .take(4)
            .map((ev) => _CompactCard(event: ev))
            .toList(),
      ),
    );
  }

  Widget _buildCommunities() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: _communities.length,
        itemBuilder: (context, i) {
          final c = _communities[i];
          return Container(
            width: 104,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.09)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['emoji']!, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    c['name']!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${c['members']} members',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFA78BFA),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} // ← fin _HomeScreenState

// ─── Hero Card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  final Map<String, dynamic> event;
  const _HeroCard({required this.event});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)));
      },
      child: Container(
        width: 300,
        height: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              SizedBox(
                width: 300,
                height: 200,
                child: CachedNetworkImage(
                  imageUrl: (ev['image_url'] ?? '') as String,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF1A0F3D),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1A0F3D),
                    child: const Center(
                      child: Icon(
                        Icons.music_note,
                        color: Color(0xFF7C3AED),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x2608080F),
                      Color(0xFF08080F),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥 New',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => setState(() => _liked = !_liked),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? const Color(0xFFEC4899) : Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (ev['category'] ?? '') as String,
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (ev['title'] ?? '') as String,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFFA78BFA),
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                ((ev['location'] ?? '') as String).split(
                                  ',',
                                )[0],
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            (ev['price'] == 0 || ev['price'] == null)
                                ? 'Free'
                                : '\$${ev['price']}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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

// ─── Compact Card ─────────────────────────────────────────────────────────────

class _CompactCard extends StatefulWidget {
  final Map<String, dynamic> event;
  const _CompactCard({required this.event});

  @override
  State<_CompactCard> createState() => _CompactCardState();
}

class _CompactCardState extends State<_CompactCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    return GestureDetector(
      onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(event: ev),
    ),
  );
},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: (ev['image_url'] ?? '') as String,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF1A0F3D)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1A0F3D),
                  child: const Icon(
                    Icons.music_note,
                    color: Color(0xFF7C3AED),
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (ev['title'] ?? '') as String,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _liked = !_liked),
                        child: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked
                              ? const Color(0xFFEC4899)
                              : Colors.white.withOpacity(0.35),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFA78BFA),
                        size: 10,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          (ev['location'] ?? '') as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.white.withOpacity(0.35),
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ev['start_date'] != null
                                ? DateTime.parse(
                                    ev['start_date'],
                                  ).toString().substring(0, 10)
                                : 'TBD',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        (ev['price'] == 0 || ev['price'] == null)
                            ? 'Free'
                            : '\$${ev['price']}',
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
          ],
        ),
      ),
    );
  }
}
