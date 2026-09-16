import 'package:flutter/material.dart';
import 'widgets/hero_event_card.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/providers/categories_provider.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/notifications_provider.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/features/notifications/notifications_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/features/social/widgets/post_card.dart';
import 'package:happyn/core/providers/social_provider.dart';

// ─── Home Screen ──────────────────────────────────────────────────────────────
// Note: ConsumerStatefulWidget au lieu de StatefulWidget car on garde
// le state local _selectedCat (filtre catégorie), mais les events viennent
// du provider partagé.

class HomeScreen extends ConsumerStatefulWidget {
  /// Appelé quand l'utilisateur tape la barre de recherche → bascule sur Discover.
  final VoidCallback? onSearchTap;

  /// Controller partagé par MainShell pour le « scroll-to-top » au tap Home.
  final ScrollController? scrollController;

  const HomeScreen({super.key, this.onSearchTap, this.scrollController});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCat = 0;
  List<String> _categories = const ['All'];
  List<Map<String, dynamic>> _catData = const [];

  // Getter (pas un champ figé) → toujours la valeur à jour après un updateUser.
  User? get user => Supabase.instance.client.auth.currentUser;

  String get userName => user?.userMetadata?['full_name'] ?? 'User';

  String get userInitials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName.substring(0, 1).toUpperCase();
  }

  String? get avatarUrl => user?.userMetadata?['avatar_url'] as String?;

  String get _greeting {
    final l = AppLocalizations.of(context);
    final h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning;
    if (h < 18) return l.greetingAfternoon;
    return l.greetingEvening;
  }

  List<Map<String, dynamic>> _filterByCategory(
    List<Map<String, dynamic>> events,
  ) {
    final upcoming = sortedByStart(events.where(isEventVisible).toList());
    if (_selectedCat <= 0 || _selectedCat >= _categories.length) return upcoming;
    return upcoming
        .where((e) => e['category'] == _categories[_selectedCat])
        .toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(eventsProvider);
    ref.invalidate(notificationsProvider); // maj du badge cloche
    ref.invalidate(discoverFeedProvider);
    // on attend que le nouveau fetch soit terminé pour que le
    // RefreshIndicator se ferme au bon moment
    await ref.read(eventsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    ref.watch(authStateProvider); // rebuild au changement de nom/photo
    _catData = ref.watch(categoriesProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const [],
        );
    _categories = ['All', ..._catData.map((c) => c['name'] as String)];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
            ),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildLocation(eventsAsync)),
            SliverToBoxAdapter(child: _buildCategories()),
            // Un seul bandeau d'evenements, trie par date de tenue : « ce que
            // je peux faire bientot ». Classer par popularite ou par distance
            // demanderait du volume qu'on n'a pas encore ; le temps, lui, on
            // l'a des le premier jour. « Tout voir » mene a Decouvrir.
            SliverToBoxAdapter(
                child: _buildSectionHeader(
                    AppLocalizations.of(context).onNow, seeAll: true)),
            SliverToBoxAdapter(child: _buildHeroCards(eventsAsync)),
            // Puis la couche sociale : des moments vecus autour des events.
            SliverToBoxAdapter(child: _buildMomentsHeader()),
            _buildFeedSliver(),
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
                    style: AppText.caption.copyWith(fontWeight: FontWeight.w500, color: AppColors.textLight.withOpacity(0.5)),
                  ),
                  TextSpan(
                    text: '$userName 👋',
                    style: AppText.h1.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationsScreen())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.09)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    if (ref.watch(unreadCountProvider) > 0)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: AppColors.pink,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.background, width: 1.5),
                          ),
                          child: Text(
                            '${ref.watch(unreadCountProvider)}',
                            textAlign: TextAlign.center,
                            style: AppText.microBold.copyWith(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.55),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Center(
                            child: Text(
                              userInitials,
                              style: AppText.h5.copyWith(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            userInitials,
                            style: AppText.h5.copyWith(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
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
            Icon(Icons.search, color: AppColors.textLow, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context).searchHint,
                style: AppText.bodySm.copyWith(color: AppColors.textLow),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, color: AppColors.lavender, size: 14),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocation(AsyncValue<List<Map<String, dynamic>>> eventsAsync) {
    final count =
        (eventsAsync.asData?.value ?? []).where(isEventVisible).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: AppColors.pink, size: 13),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.of(context).eventsToDiscover(count),
            style: AppText.small.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textLight.withOpacity(0.45)),
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
            final label = i == 0
                ? AppLocalizations.of(context).categoryAll
                : _categories[i];
            final color = i == 0 ? AppColors.lavender : categoryColor(label);

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
                        color: isActive ? color : color.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: color.withOpacity(isActive ? 0 : 0.30)),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.45),
                                    blurRadius: 14)
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          i == 0 ? Icons.auto_awesome : categoryIcon(label),
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
                      style: AppText.micro.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppColors.textLight.withOpacity(0.5)),
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

  /// Quelques evenements en liste sous le bandeau. Volontairement court :
  /// la liste complete vit sur Decouvrir.
  /// En-tete de la couche sociale. Le titre compte : « Moments » dit que ce
  /// contenu documente des experiences, la ou « Fil » aurait dit reseau social.
    /// Onglets du fil : Découvrir (tout le monde) / Abonnements.
    /// En-tete de la couche sociale : titre a gauche, bascule discrete a droite.
  ///
  /// Volontairement leger. Deux gros boutons pleine largeur donneraient au fil
  /// un poids de navigation principale, alors que c'est une couche au-dessus
  /// des evenements.
    /// En-tete de la couche sociale.
  ///
  /// Un seul fil, sans selecteur de mode : c'est ce qui prepare un classement
  /// par recommandation, ou un bouton « Abonnements » deviendrait redondant.
  /// Voir ce que font ses connexions passera par un filtre sur Decouvrir, et
  /// portera sur les EVENEMENTS auxquels elles vont — pas sur leurs
  /// publications.
  Widget _buildMomentsHeader() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.moments,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h3.copyWith(fontSize: 17)),
        ],
      ),
    );
  }

  /// Le fil lui-même, en sliver pour rester dans le même défilement que
  /// l'en-tête et le bandeau d'événements.
  Widget _buildFeedSliver() {
    final l = AppLocalizations.of(context);
    final async = ref.watch(discoverFeedProvider);

    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ),
      error: (e, _) {
        debugPrint('feed error: $e');
        return SliverToBoxAdapter(
          child: _feedMessage(Icons.cloud_off, l.couldNotLoadEvents, ''),
        );
      },
      data: (posts) {
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: _feedMessage(Icons.photo_camera_outlined,
                l.feedEmpty, l.feedEmptyBody),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) => PostCard(
              post: posts[i],
              onChanged: () => ref.invalidate(discoverFeedProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _feedMessage(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textLow)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.textFaint)),
            ],
          ],
        ),
      );

  Widget _buildSectionHeader(String title,
      {bool seeAll = false, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded + ellipsis : les titres FR plus longs ne débordent pas
          // sur le « Tout voir ».
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h3.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          if (seeAll)
            GestureDetector(
              onTap: onSeeAll ?? widget.onSearchTap,
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context).seeAll,
                    style: AppText.smallBold.copyWith(color: AppColors.lavender),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.lavender, size: 14),
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
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => SizedBox(
        height: 252,
        child: Center(
          child: Text(
            AppLocalizations.of(context).couldNotLoadEvents,
            style: AppText.bodySm.copyWith(color: AppColors.textLow),
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
                AppLocalizations.of(context).noEventsYet,
                style: AppText.bodySm.copyWith(color: AppColors.textLow),
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
            itemBuilder: (context, i) => HeroEventCard(event: events[i]),
          ),
        );
      },
    );
  }

  }


