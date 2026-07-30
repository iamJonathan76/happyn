import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/categories_provider.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/core/widgets/event_list_card.dart';
import 'package:happyn/features/events/join_private_event_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

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
    // Découverte : uniquement les events publiés et pas terminés.
    List<Map<String, dynamic>> result = all.where(isEventVisible).toList();

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

  /// Libellé affiché d'un filtre (les clés internes restent 'All'/'Tonight'/'Free').
  String _filterLabel(String f, AppLocalizations l) {
    switch (f) {
      case 'All':
        return l.categoryAll;
      case 'Tonight':
        return l.filterTonight;
      case 'Free':
        return l.free;
      default:
        return f; // nom de catégorie (non traduit)
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final eventsAsync = ref.watch(eventsProvider);
    _filters = ['All', 'Tonight', 'Free', ...ref.watch(categoryNamesProvider)];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text(
                  l.discoverTitle,
                  style: AppText.display.copyWith(color: Colors.white),
                ),
                const Spacer(),
                // Accès aux events privés via code d'invitation
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const JoinPrivateEventScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.vpn_key,
                            size: 14, color: AppColors.lavenderLight),
                        const SizedBox(width: 6),
                        Text(
                          l.haveACode,
                          style: AppText.captionBold,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                    color: AppColors.textLow,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppText.bodySm.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l.searchHintDiscover,
                        hintStyle: AppText.bodySm.copyWith(color: AppColors.textFaint),
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
                          color: AppColors.textLow,
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
                              colors: [AppColors.primary, AppColors.pink],
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
                                color: AppColors.primary.withOpacity(0.55),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _filterLabel(f, l),
                      style: AppText.smallBold.copyWith(color: isActive
                            ? Colors.white
                            : AppColors.textLow),
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
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text(
                  l.couldNotLoadEvents,
                  style: AppText.body.copyWith(color: AppColors.textLow),
                ),
              ),
              data: (allEvents) {
                final filtered = _applyFilters(allEvents);
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.card,
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
                              l.eventsFound(filtered.length),
                              style: AppText.captionBold.copyWith(color: AppColors.textLow),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
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
    final l = AppLocalizations.of(context);
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
                  color: AppColors.textFaint,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? l.noResultsFor(_searchQuery)
                      : l.noEventsInCategory,
                  style: AppText.body.copyWith(color: AppColors.textLow),
                ),
                const SizedBox(height: 8),
                Text(
                  l.tryDifferentSearch,
                  style: AppText.caption.copyWith(color: AppColors.textFaint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
