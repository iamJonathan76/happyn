import 'package:flutter/material.dart';
import 'widgets/sliver_tab_bar.dart';
import 'widgets/event_tile.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/push/push_service.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/features/social/follow_list_screen.dart';
import 'package:happyn/core/providers/user_profile_provider.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/features/social/widgets/post_card.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/core/widgets/event_list_card.dart';
import 'package:happyn/features/settings/edit_profile_screen.dart';
import 'package:happyn/features/settings/settings_screen.dart';

/// Profil — le sien ou celui de quelqu'un d'autre.
///
/// Un SEUL ecran pour les deux : deux ecrans distincts donnaient l'impression
/// d'avoir deux profils pour un meme compte. Seules les ACTIONS changent
/// (reglages et edition chez soi, suivre et signaler ailleurs).
class ProfileScreen extends ConsumerStatefulWidget {
  /// null = le compte connecte.
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  // 0 = evenements, 1 = moments, 2 = favoris (soi), 3 = a propos
  int _selectedTab = 0;

  String get _uid => widget.userId ?? _supabase.auth.currentUser?.id ?? '';

  bool get _isMe =>
      widget.userId == null || widget.userId == _supabase.auth.currentUser?.id;

  /// Profil public : nom, avatar, bio, ville — jamais email ni date de
  /// naissance. Sert aux deux cas, pour que les deux affichages coincident.
  Map<String, dynamic>? get _pub =>
      ref.watch(publicProfileProvider(_uid)).asData?.value;

  String get _userName {
    if (_isMe) {
      final meta = _supabase.auth.currentUser?.userMetadata?['full_name'];
      if (meta is String && meta.trim().isNotEmpty) return meta;
    }
    final n = (_pub?['full_name'] as String?)?.trim();
    return (n == null || n.isEmpty) ? 'User' : n;
  }

  String get _userEmail =>
      _isMe ? (_supabase.auth.currentUser?.email ?? '') : '';

  /// L'identifiant enregistre en base. Il etait fabrique ici : tire de
  /// l'e-mail sur son propre profil, du nom chez les autres — on ne se voyait
  /// donc pas comme les autres nous voyaient. Vide tant que la ligne n'est pas
  /// chargee : mieux vaut rien qu'un identifiant invente.
  String get _userHandle {
    final row = _isMe ? ref.watch(userProfileProvider).asData?.value : _pub;
    final u = (row?['username'] as String?) ?? '';
    return u.isEmpty ? '' : '@$u';
  }

  String? get _avatarUrl {
    if (_isMe) {
      final meta = _supabase.auth.currentUser?.userMetadata?['avatar_url'];
      if (meta is String && meta.isNotEmpty) return meta;
    }
    return _pub?['avatar_url'] as String?;
  }

  String get _userInitials {
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _userName.substring(0, 1).toUpperCase();
  }

  /// Compteurs d'abonnes/abonnements de la personne REGARDEE.
  ///
  /// Cette fonction lisait l'utilisateur connecte : sur le profil de
  /// quelqu'un d'autre, on voyait donc ses propres compteurs a la place des
  /// siens.
  Map<String, dynamic>? _counts(Map<String, dynamic>? _) {
    if (_uid.isEmpty) return null;
    return ref.watch(publicProfileProvider(_uid)).asData?.value;
  }

  void _openFollows(FollowListKind kind) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FollowListScreen(
              userId: _uid,
              title: _userName,
              initial: kind,
            )));
  }

  Future<void> _signOut() async {
    // AVANT la deconnexion : sinon la ligne reste attachee a ce compte et la
    // personne suivante a se connecter sur ce telephone recevrait ses
    // notifications. C'est une fuite, pas un detail de confort.
    await PushService.unregister();
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    ref.watch(authStateProvider); // rebuild au changement de nom/photo
    // Les evenements organises par la personne regardee. Pour un autre compte,
    // `eventsProvider` ne contient que ses evenements publics.
    final myEvents = (eventsAsync.asData?.value ?? [])
        .where((e) => e['created_by'] == _uid)
        .toList();
    final profileRow = _isMe
        ? ref.watch(userProfileProvider).asData?.value
        : _pub;
    final bio = (profileRow?['bio'] ?? _pub?['bio'] ?? '') as String;
    final city = (profileRow?['city'] ?? _pub?['city'] ?? '') as String;
    final isLoading = eventsAsync.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top),

                // ── Banner + avatar + gear ───────────────────────────────
                SizedBox(
                  height: 168,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bannière (dégradé)
                      Container(
                        height: 120,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF4C1D95),
                              AppColors.primary,
                              AppColors.pink,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Reglages a droite, retour a gauche : ce ne sont pas
                      // les memes gestes, ils n'ont pas a partager un coin.
                      Positioned(
                        top: 8,
                        left: _isMe ? null : 16,
                        right: _isMe ? 16 : null,
                        child: GestureDetector(
                          onTap: () => _isMe
                              ? Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                )
                              : Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isMe
                                  ? Icons.settings_outlined
                                  : Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: _isMe ? 18 : 15,
                            ),
                          ),
                        ),
                      ),
                      if (!_isMe)
                        Positioned(top: 8, right: 12, child: _moreMenu()),
                      // Avatar (anneau dégradé) + nom + @handle
                      Positioned(
                        left: 20,
                        right: 20,
                        top: 78,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.pink],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: ClipOval(
                                child:
                                    (_avatarUrl != null &&
                                        _avatarUrl!.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: _avatarUrl!,
                                        width: 78,
                                        height: 78,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) =>
                                            _initialsAvatar(),
                                      )
                                    : _initialsAvatar(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.h1.copyWith(
                                        fontSize: 19,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_userHandle.isNotEmpty)
                                    Text(
                                      _userHandle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption.copyWith(
                                        color: AppColors.textLow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Stats ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _statItem(
                        '${myEvents.length}',
                        AppLocalizations.of(context).statEvents,
                      ),
                      _divider(),
                      _statItem(
                        '${_counts(profileRow)?['followers_count'] ?? 0}',
                        AppLocalizations.of(context).followers,
                        onTap: () => _openFollows(FollowListKind.followers),
                      ),
                      _divider(),
                      _statItem(
                        '${_counts(profileRow)?['following_count'] ?? 0}',
                        AppLocalizations.of(context).following,
                        onTap: () => _openFollows(FollowListKind.following),
                      ),
                    ],
                  ),
                ),

                // ── Ville + Bio ───────────────────────────────────────────
                if (city.isNotEmpty || bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (city.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 13,
                                color: AppColors.textLow,
                              ),
                              const SizedBox(width: 4),
                              Text(city, style: AppText.caption),
                            ],
                          ),
                        if (bio.isNotEmpty) ...[
                          if (city.isNotEmpty) const SizedBox(height: 8),
                          Text(
                            bio,
                            style: AppText.bodySm.copyWith(height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Action : editer (soi) ou suivre (autre) ───────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isMe
                      ? GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            );
                            ref.invalidate(userProfileProvider); // ville/bio
                            if (mounted) setState(() {}); // nom/photo
                          },
                          child: Container(
                            width: double.infinity,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.pink],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context).editProfile,
                                style: AppText.h4.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        )
                      : _followButton(),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          // ── Onglets épinglés ─────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: SliverTabBarDelegate(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    _tabChip(
                      0,
                      Icons.event_outlined,
                      AppLocalizations.of(context).profileTabEvents,
                    ),
                    _tabChip(
                      1,
                      Icons.photo_camera_outlined,
                      AppLocalizations.of(context).profileTabPosts,
                    ),
                    // Les favoris sont prives : jamais sur le profil d'autrui.
                    if (_isMe)
                      _tabChip(
                        2,
                        Icons.favorite_border,
                        AppLocalizations.of(context).favorites,
                      ),
                    _tabChip(
                      3,
                      Icons.info_outline,
                      AppLocalizations.of(context).sectionAbout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () async {
            ref.invalidate(eventsProvider);
            ref.invalidate(favoritesProvider);
            ref.invalidate(userProfileProvider);
            await ref.read(eventsProvider.future);
          },
          child: switch (_selectedTab) {
            0 => _buildMyEvents(
              isLoading,
              myEvents,
              failed: eventsAsync.hasError,
            ),
            1 => _buildMoments(),
            2 when _isMe => _buildFavorites(),
            _ => _buildAbout(),
          },
        ),
      ),
    );
  }

  // ── My Events Tab ──────────────────────────────────────────────────────────

  /// Publications de la personne. Toutes rattachees a un evenement, donc cet
  /// onglet raconte ce qu'elle a vecu.
  Widget _buildMoments() {
    final l = AppLocalizations.of(context);
    final posts = ref.watch(userPostsProvider(_uid)).asData?.value ?? const [];
    if (posts.isEmpty) {
      return _emptyScrollable(
        Icons.photo_camera_outlined,
        l.feedEmpty,
        l.feedEmptyBody,
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: posts
          .map(
            (p) => PostCard(
              post: p,
              onChanged: () => ref.invalidate(userPostsProvider(_uid)),
            ),
          )
          .toList(),
    );
  }

  /// Suivre / Abonne. Le suivi reciproque conditionne la visibilite des
  /// presences, d'ou un bouton bien visible.
  Widget _followButton() {
    final l = AppLocalizations.of(context);
    final following =
        ref.watch(followingProvider).asData?.value ?? const <String>{};
    final isFollowing = following.contains(_uid);

    Future<void> toggle() async {
      isFollowing ? await unfollowUser(_uid) : await followUser(_uid);
      ref.invalidate(followingProvider);
      ref.invalidate(publicProfileProvider(_uid));
    }

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: isFollowing
          ? OutlinedButton.icon(
              onPressed: toggle,
              icon: const Icon(Icons.check, size: 17, color: Colors.white),
              label: Text(
                l.unfollow,
                style: AppText.h4.copyWith(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: toggle,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.follow,
                  style: AppText.h4.copyWith(color: Colors.white),
                ),
              ),
            ),
    );
  }

  Widget _moreMenu() {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
      ),
      onSelected: (v) async {
        if (v == 'report') {
          await showReportSheet(context, targetType: 'user', targetId: _uid);
        } else if (v == 'block') {
          final blocked = await confirmBlockUser(context, ref, userId: _uid);
          if (blocked && mounted) {
            ref.invalidate(discoverFeedProvider);
            showAppSnack(context, l.userBlocked);
            Navigator.of(context).pop();
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(l.report, style: AppText.body),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              const Icon(Icons.block, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Text(
                l.block,
                style: AppText.body.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabChip(int index, IconData icon, String label) {
    final isActive = index == _selectedTab;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          selected: isActive,
          button: true,
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isActive ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: isActive
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.09)),
              ),
              // Icone seule : les libelles rendaient la barre chargee et sautaient
              // de largeur entre FR et EN. Le libelle reste expose aux lecteurs
              // d'ecran via Semantics, et en info-bulle sur appui long.
              child: Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: isActive ? Colors.white : AppColors.textLow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavorites() {
    final favEvents = ref.watch(favoriteEventsProvider);
    final loading = ref.watch(favoritesProvider).isLoading;

    if (loading && favEvents.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (favEvents.isEmpty) {
      return _emptyScrollable(
        Icons.favorite_border,
        AppLocalizations.of(context).noFavoritesYet,
        AppLocalizations.of(context).tapHeartToSave,
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: favEvents.map((e) => EventListCard(event: e)).toList(),
    );
  }

  // État vide scrollable (pour que le pull-to-refresh marche même sans contenu).
  Widget _emptyScrollable(IconData icon, String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 380,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: AppColors.textFaint),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.textLow),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyEvents(
    bool isLoading,
    List<Map<String, dynamic>> myEvents, {
    bool failed = false,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Une requête en échec et une liste vide se ressemblent à l'écran :
    // on distingue les deux, sinon un bug backend passe pour « rien à afficher ».
    if (failed) {
      return _emptyScrollable(
        Icons.cloud_off,
        AppLocalizations.of(context).couldNotLoadEvents,
        AppLocalizations.of(context).tryDifferentSearch,
      );
    }

    if (myEvents.isEmpty) {
      return _emptyScrollable(
        Icons.event_outlined,
        AppLocalizations.of(context).noEventsCreated,
        AppLocalizations.of(context).tapPlusToCreate,
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: myEvents.length,
      itemBuilder: (context, i) {
        final ev = myEvents[i];
        return EventTile(event: ev);
      },
    );
  }

  // ── About Tab ──────────────────────────────────────────────────────────────

  String _monthYear(String? iso) => AppDates.monthYear(context, iso);

  Widget _buildAbout() {
    final city =
        (ref.watch(userProfileProvider).asData?.value?['city'] ?? '') as String;
    final memberSince = _monthYear(_supabase.auth.currentUser?.createdAt);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (_isMe)
          _aboutTile(
            Icons.mail_outline,
            AppLocalizations.of(context).emailLabel,
            _userEmail,
          ),
        if (city.isNotEmpty)
          _aboutTile(
            Icons.location_on_outlined,
            AppLocalizations.of(context).aboutLocation,
            city,
          ),
        _aboutTile(
          Icons.calendar_today_outlined,
          AppLocalizations.of(context).memberSince,
          memberSince,
        ),
        const SizedBox(height: 24),
        // Sign out — uniquement sur son propre profil
        if (_isMe)
          GestureDetector(
            onTap: _signOut,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).signOut,
                    style: AppText.h4.copyWith(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _initialsAvatar() => Container(
    width: 78,
    height: 78,
    color: AppColors.card,
    child: Center(
      child: Text(
        _userInitials,
        style: AppText.display.copyWith(fontSize: 28, color: Colors.white),
      ),
    ),
  );

  Widget _statItem(String value, String label, {VoidCallback? onTap}) {
    final column = Column(
      children: [
        Text(value, style: AppText.h1.copyWith(color: Colors.white)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppText.small,
          ),
        ),
      ],
    );
    return Expanded(
      child: onTap == null
          ? column
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: column,
              ),
            ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _aboutTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lavender, size: 18),
          const SizedBox(width: 12),
          // Expanded + ellipsis : un long email ou libellé FR ne déborde pas.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.micro,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Header épinglé pour les onglets du profil (reste en haut quand on scrolle).
