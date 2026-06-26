import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/categories_provider.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/widgets/event_list_card.dart';

// ─── Home Screen ──────────────────────────────────────────────────────────────
// Note: ConsumerStatefulWidget au lieu de StatefulWidget car on garde
// le state local _selectedCat (filtre catégorie), mais les events viennent
// du provider partagé.

class HomeScreen extends ConsumerStatefulWidget {
  /// Appelé quand l'utilisateur tape la barre de recherche → bascule sur Discover.
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCat = 0;

  // Alimenté depuis le provider en début de build : ['All', ...catégories].
  List<String> _categories = const ['All'];
  // Données catégories (nom + emoji) pour les cercles.
  List<Map<String, dynamic>> _catData = const [];

  final user = Supabase.instance.client.auth.currentUser;

  String get userName => user?.userMetadata?['full_name'] ?? 'User';

  String get userInitials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName.substring(0, 1).toUpperCase();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  List<Map<String, dynamic>> _filterByCategory(
    List<Map<String, dynamic>> events,
  ) {
    if (_selectedCat <= 0 || _selectedCat >= _categories.length) return events;
    final cat = _categories[_selectedCat];
    return events.where((e) => e['category'] == cat).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(eventsProvider);
    // on attend que le nouveau fetch soit terminé pour que le
    // RefreshIndicator se ferme au bon moment
    await ref.read(eventsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    _catData = ref.watch(categoriesProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const [],
        );
    _categories = ['All', ..._catData.map((c) => c['name'] as String)];

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: RefreshIndicator(
        color: const Color(0xFF7C3AED),
        backgroundColor: const Color(0xFF1A1535),
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
            ),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildLocation(eventsAsync)),
            SliverToBoxAdapter(child: _buildCategories()),
            SliverToBoxAdapter(
                child: _buildSectionHeader('For you', seeAll: true)),
            SliverToBoxAdapter(child: _buildHeroCards(eventsAsync)),
            SliverToBoxAdapter(
                child: _buildSectionHeader('Popular near you', seeAll: true)),
            SliverToBoxAdapter(child: _buildCompactList(eventsAsync)),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$_greeting,\n',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFF0EEFF).withOpacity(0.5),
                    ),
                  ),
                  TextSpan(
                    text: '$userName 👋',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _comingSoon('Notifications'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.09)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
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

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1535),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: widget.onSearchTap,
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
      ),
    );
  }

  Widget _buildLocation(AsyncValue<List<Map<String, dynamic>>> eventsAsync) {
    final count = eventsAsync.asData?.value.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Color(0xFFEC4899), size: 13),
          const SizedBox(width: 5),
          Text(
            '$count events to discover',
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 86,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20, right: 8),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final isActive = i == _selectedCat;
            final label = _categories[i];
            final color =
                i == 0 ? const Color(0xFFA78BFA) : categoryColor(label);

            return GestureDetector(
              onTap: () => setState(() => _selectedCat = i),
              child: SizedBox(
                width: 66,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isActive
                            ? color
                            : color.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: color.withOpacity(isActive ? 0 : 0.30),
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.45),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          i == 0
                              ? Icons.auto_awesome
                              : categoryIcon(label),
                          color: isActive ? Colors.white : color,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFFF0EEFF).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool seeAll = false}) {
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
          if (seeAll)
            GestureDetector(
              onTap: widget.onSearchTap,
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFA78BFA),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFA78BFA), size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroCards(AsyncValue<List<Map<String, dynamic>>> eventsAsync) {
    return eventsAsync.when(
      loading: () => const SizedBox(
        height: 252,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      ),
      error: (err, _) => SizedBox(
        height: 252,
        child: Center(
          child: Text(
            'Could not load events',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ),
      ),
      data: (allEvents) {
        final events = _filterByCategory(allEvents);
        if (events.isEmpty) {
          return SizedBox(
            height: 252,
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
          height: 252,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: events.length,
            itemBuilder: (context, i) => _HeroCard(event: events[i]),
          ),
        );
      },
    );
  }

  Widget _buildCompactList(AsyncValue<List<Map<String, dynamic>>> eventsAsync) {
    final allEvents = eventsAsync.asData?.value ?? [];
    if (allEvents.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: allEvents
            .skip(1)
            .take(4)
            .map((ev) => EventListCard(event: ev))
            .toList(),
      ),
    );
  }

}

// ─── Hero Card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  final Map<String, dynamic> event;
  const _HeroCard({required this.event});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _liked = false;

  (String, String) _dateParts(String? s) {
    if (s == null) return ('', '');
    final dt = DateTime.parse(s);
    const m = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return (m[dt.month - 1], dt.day.toString());
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final cat = (ev['category'] ?? '') as String;
    final color = categoryColor(cat);
    final (mon, day) = _dateParts(ev['start_date'] as String?);
    final priceText = (ev['price'] == 0 || ev['price'] == null)
        ? 'Free'
        : '\$${ev['price']}';
    final city = (ev['city'] ?? ev['location'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
      ),
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF13111C),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image + badge date + cœur ─────────────────────────
              Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: (ev['image_url'] ?? '') as String,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: const Color(0xFF1A0F3D)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFF1A0F3D),
                        child: Center(
                          child: Icon(categoryIcon(cat),
                              color: const Color(0xFF7C3AED), size: 38),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(mon,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFEC4899),
                                letterSpacing: 0.5,
                              )),
                          Text(day,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF08080F),
                                height: 1,
                              )),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? const Color(0xFFEC4899) : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // ── Infos ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ev['title'] ?? '') as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(categoryIcon(cat), size: 12, color: color),
                        const SizedBox(width: 5),
                        Text(
                          cat,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.4)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priceText,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
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
    );
  }
}
