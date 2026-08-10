import 'package:flutter/material.dart';
import 'widgets/sliver_tab_bar.dart';
import 'widgets/event_tile.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/core/providers/user_profile_provider.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/widgets/event_list_card.dart';
import 'package:happyn/features/settings/edit_profile_screen.dart';
import 'package:happyn/features/settings/settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  int _selectedTab = 0; // 0 = events, 1 = about

  String get _userName {
    final user = _supabase.auth.currentUser;
    return user?.userMetadata?['full_name'] ?? 'User';
  }

  String get _userEmail {
    return _supabase.auth.currentUser?.email ?? '';
  }

  String get _userHandle {
    final e = _userEmail;
    if (e.contains('@')) return '@${e.split('@').first}';
    final n = _userName.trim().toLowerCase().replaceAll(' ', '');
    return n.isEmpty ? '@user' : '@$n';
  }

  String? get _avatarUrl =>
      _supabase.auth.currentUser?.userMetadata?['avatar_url'] as String?;

  String get _userInitials {
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _userName.substring(0, 1).toUpperCase();
  }

  /// Compteurs d'abonnes/abonnements du compte courant, via le meme provider
  /// que le profil public — une seule source pour les deux ecrans.
  Map<String, dynamic>? _counts(Map<String, dynamic>? _) {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    return ref.watch(publicProfileProvider(uid)).asData?.value;
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  Future<void> _deleteEvent(String id) async {
    try {
      await _supabase.from('events').delete().eq('id', id);
      // Invalide le provider partagé : Home, Discover ET Profile
      // se rafraîchissent tous automatiquement, sans rien faire de plus.
      ref.invalidate(eventsProvider);
      if (mounted) {
        showAppSnack(context, AppLocalizations.of(context).eventDeleted);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('event_has_tickets')
            ? AppLocalizations.of(context).cantDeleteHasTickets
            : AppLocalizations.of(context).couldNotDeleteEvent;
        showAppSnack(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final myEvents = ref.watch(myEventsProvider);
    ref.watch(authStateProvider); // rebuild au changement de nom/photo
    final profileRow = ref.watch(userProfileProvider).asData?.value;
    final bio = (profileRow?['bio'] ?? '') as String;
    final city = (profileRow?['city'] ?? '') as String;
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
                      colors: [Color(0xFF4C1D95), AppColors.primary, AppColors.pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Gear par-dessus la bannière
                Positioned(
                  top: 8,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsScreen())),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
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
                          child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: _avatarUrl!,
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _initialsAvatar(),
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
                                style: AppText.h1.copyWith(fontSize: 19, color: Colors.white),
                              ),
                              Text(
                                _userHandle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(color: AppColors.textLow),
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
                _statItem('${myEvents.length}', AppLocalizations.of(context).statEvents),
                _divider(),
                _statItem('${_counts(profileRow)?['followers_count'] ?? 0}',
                    AppLocalizations.of(context).followers),
                _divider(),
                _statItem('${_counts(profileRow)?['following_count'] ?? 0}',
                    AppLocalizations.of(context).following),
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
                        Icon(Icons.location_on,
                            size: 13, color: AppColors.textLow),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: AppText.caption,
                        ),
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

          // ── Edit Profile ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const EditProfileScreen()));
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
            ),
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
                    _tabChip(0, Icons.event_outlined, AppLocalizations.of(context).myEvents),
                    _tabChip(1, Icons.favorite_border, AppLocalizations.of(context).favorites),
                    _tabChip(2, Icons.info_outline, AppLocalizations.of(context).sectionAbout),
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
          child: _selectedTab == 0
              ? _buildMyEvents(isLoading, myEvents,
                  failed: eventsAsync.hasError)
              : _selectedTab == 1
                  ? _buildFavorites()
                  : _buildAbout(),
        ),
      ),
    );
  }

  // ── My Events Tab ──────────────────────────────────────────────────────────

  Widget _tabChip(int index, IconData icon, String label) {
    final isActive = index == _selectedTab;
    return Expanded(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color:
                      isActive ? Colors.white : AppColors.textLow),
              const SizedBox(width: 5),
              // Flexible + FittedBox : le libellé se réduit pour tenir dans
              // l'onglet plutôt que déborder (utile en FR, mots plus longs).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppText.smallBold.copyWith(fontSize: 11.5, color: isActive ? Colors.white : AppColors.textLow),
                  ),
                ),
              ),
            ],
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
      return _emptyScrollable(Icons.favorite_border, AppLocalizations.of(context).noFavoritesYet,
          AppLocalizations.of(context).tapHeartToSave);
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
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: AppColors.textLow)),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(subtitle,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(color: AppColors.textFaint)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyEvents(bool isLoading, List<Map<String, dynamic>> myEvents,
      {bool failed = false}) {
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
          AppLocalizations.of(context).tryDifferentSearch);
    }

    if (myEvents.isEmpty) {
      return _emptyScrollable(Icons.event_outlined,
          AppLocalizations.of(context).noEventsCreated,
          AppLocalizations.of(context).tapPlusToCreate);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: myEvents.length,
      itemBuilder: (context, i) {
        final ev = myEvents[i];
        return EventTile(event: ev, onDelete: () => _deleteEvent(ev['id']));
      },
    );
  }

  // ── About Tab ──────────────────────────────────────────────────────────────

  String _monthYear(String? iso) => AppDates.monthYear(context, iso);

  Widget _buildAbout() {
    final city =
        (ref.watch(userProfileProvider).asData?.value?['city'] ?? '') as String;
    final memberSince =
        _monthYear(_supabase.auth.currentUser?.createdAt);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
          _aboutTile(Icons.mail_outline, AppLocalizations.of(context).emailLabel, _userEmail),
          if (city.isNotEmpty)
            _aboutTile(Icons.location_on_outlined, AppLocalizations.of(context).aboutLocation, city),
          _aboutTile(
              Icons.calendar_today_outlined, AppLocalizations.of(context).memberSince, memberSince),
          const SizedBox(height: 24),
          // Sign out
          GestureDetector(
            onTap: _signOut,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                ),
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

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppText.h1.copyWith(color: Colors.white),
          ),
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
                  style: AppText.bodySm.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
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

