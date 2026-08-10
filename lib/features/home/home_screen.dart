import 'package:flutter/material.dart';
import 'widgets/hero_event_card.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
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

  /// 0 = Découvrir (tout le monde), 1 = Abonnements.
  /// Découvrir par défaut : au lancement personne ne suit personne, un fil
  /// limité aux abonnements serait vide pour chaque nouvel inscrit.
  int _feedTab = 0;

  Future<void> _refresh() async {
    ref.invalidate(eventsProvider);
    ref.invalidate(notificationsProvider); // maj du badge cloche
    ref.invalidate(discoverFeedProvider);
    ref.invalidate(followingFeedProvider);
    // on attend que le nouveau fetch soit terminé pour que le
    // RefreshIndicator se ferme au bon moment
    await ref.read(eventsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    ref.watch(authStateProvider); // rebuild au changement de nom/photo

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
            // Bandeau d'événements : un aperçu, « Tout voir » mène à Découvrir
            // (qui porte les catégories, filtres et la liste complète).
            SliverToBoxAdapter(
                child: _buildSectionHeader(
                    AppLocalizations.of(context).onNow, seeAll: true)),
            SliverToBoxAdapter(child: _buildHeroCards(eventsAsync)),
            // Puis le fil social : c'est lui qui donne du contenu à l'app même
            // quand il n'y a que quelques événements.
            SliverToBoxAdapter(child: _buildFeedTabs()),
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

  /// Onglets du fil : Découvrir (tout le monde) / Abonnements.
  Widget _buildFeedTabs() {
    final l = AppLocalizations.of(context);
    Widget tab(int index, String label) {
      final active = index == _feedTab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _feedTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              gradient: active ? AppColors.primaryGradient : null,
              color: active ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: active
                  ? null
                  : Border.all(color: Colors.white.withOpacity(0.09)),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppText.smallBold.copyWith(
                      fontSize: 12,
                      color: active ? Colors.white : AppColors.textLow),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [tab(0, l.feedDiscover), tab(1, l.feedFollowing)],
      ),
    );
  }

  /// Le fil lui-même, en sliver pour rester dans le même défilement que
  /// l'en-tête et le bandeau d'événements.
  Widget _buildFeedSliver() {
    final l = AppLocalizations.of(context);
    final async = _feedTab == 0
        ? ref.watch(discoverFeedProvider)
        : ref.watch(followingFeedProvider);

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
            child: _feedMessage(
              Icons.photo_camera_outlined,
              _feedTab == 0 ? l.feedEmpty : l.feedFollowingEmpty,
              _feedTab == 0 ? l.feedEmptyBody : l.feedFollowingEmptyBody,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) => PostCard(
              post: posts[i],
              onChanged: () {
                ref.invalidate(discoverFeedProvider);
                ref.invalidate(followingFeedProvider);
              },
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

  Widget _buildSectionHeader(String title, {bool seeAll = false}) {
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
              onTap: widget.onSearchTap,
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
        final events = allEvents.where(isEventVisible).toList();
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


