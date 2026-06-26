import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/categories_provider.dart';
import 'package:happyn/core/widgets/event_list_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  String _activeFilter = 'All';
  String _searchQuery = '';

  // 'All' + filtres rapides + catégories (ces dernières viennent du provider,
  // ajoutées en début de build).
  List<String> _filters = const ['All', 'Tonight', 'Free'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    List<Map<String, dynamic>> result = List.from(all);

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

    return result;
  }

  Future<void> _refresh() async {
    ref.invalidate(eventsProvider);
    await ref.read(eventsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    _filters = ['All', 'Tonight', 'Free', ...ref.watch(categoryNamesProvider)];

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
                        setState(() => _searchQuery = '');
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
                  onTap: () => setState(() => _activeFilter = f),
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

          // ── Results ─────────────────────────────────────────────
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Could not load events',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
              ),
              data: (allEvents) {
                final filtered = _applyFilters(allEvents);
                return RefreshIndicator(
                  color: const Color(0xFF7C3AED),
                  backgroundColor: const Color(0xFF1A1535),
                  onRefresh: _refresh,
                  child: Column(
                    children: [
                      // Results count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20)
                            .copyWith(bottom: 12),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} event${filtered.length != 1 ? 's' : ''} found',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 0, 20, 90),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) =>
                                    EventListCard(event: filtered[i]),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // ListView (pas Center) pour que le RefreshIndicator marche
      // même quand la liste est vide
      children: [
        SizedBox(
          height: 360,
          child: Center(
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
          ),
        ),
      ],
    );
  }
}
