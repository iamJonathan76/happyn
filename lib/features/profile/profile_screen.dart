import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/core/providers/user_profile_provider.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/core/widgets/event_list_card.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventDeleted,
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFF1A1535),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('event_has_tickets')
            ? "Can't delete: this event has sold tickets. Cancel it instead."
            : AppLocalizations.of(context).couldNotDeleteEvent;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFF1A1535),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
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
      backgroundColor: const Color(0xFF08080F),
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
                      colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFEC4899)],
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
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
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
                                style: GoogleFonts.poppins(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _userHandle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.45),
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
                _statItem('${myEvents.length}', AppLocalizations.of(context).statEvents),
                _divider(),
                _statItem('0', AppLocalizations.of(context).followers),
                _divider(),
                _statItem('0', AppLocalizations.of(context).following),
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
                            size: 13, color: Colors.white.withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  if (bio.isNotEmpty) ...[
                    if (city.isNotEmpty) const SizedBox(height: 8),
                    Text(
                      bio,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.7),
                      ),
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
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).editProfile,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
            delegate: _SliverTabBar(
              child: Container(
                color: const Color(0xFF08080F),
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
          color: const Color(0xFF7C3AED),
          backgroundColor: const Color(0xFF1A1535),
          onRefresh: () async {
            ref.invalidate(eventsProvider);
            ref.invalidate(favoritesProvider);
            ref.invalidate(userProfileProvider);
            await ref.read(eventsProvider.future);
          },
          child: _selectedTab == 0
              ? _buildMyEvents(isLoading, myEvents)
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
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
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
                      isActive ? Colors.white : Colors.white.withOpacity(0.45)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color:
                      isActive ? Colors.white : Colors.white.withOpacity(0.45),
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
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
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
                Icon(icon, size: 48, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.white.withOpacity(0.35))),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white.withOpacity(0.25))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyEvents(bool isLoading, List<Map<String, dynamic>> myEvents) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      );
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
        return _EventTile(event: ev, onDelete: () => _deleteEvent(ev['id']));
      },
    );
  }

  // ── About Tab ──────────────────────────────────────────────────────────────

  String _monthYear(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    const m = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${m[dt.month - 1]} ${dt.year}';
  }

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
                color: const Color(0xFFFF4B4B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF4B4B).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Color(0xFFFF4B4B), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).signOut,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFF4B4B),
                    ),
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
        color: const Color(0xFF1A1535),
        child: Center(
          child: Text(
            _userInitials,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
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
          Icon(icon, color: const Color(0xFFA78BFA), size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.38),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ─── Event Tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onDelete;

  const _EventTile({required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (event['image_url'] ?? '') as String;
    final date = event['start_date'] != null
        ? DateTime.parse(event['start_date']).toString().substring(0, 10)
        : 'TBD';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(color: const Color(0xFF1A1535)),
              errorWidget: (_, _, _) => Container(
                color: const Color(0xFF1A1535),
                child: const Icon(Icons.event, color: Color(0xFF7C3AED)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event['category'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    ...(() {
                      final st = eventStatus(event);
                      final (label, color) = st == 'cancelled'
                          ? (AppLocalizations.of(context).statusCancelled,
                              const Color(0xFFFF4B4B))
                          : st == 'draft'
                              ? (AppLocalizations.of(context).statusUnpublished,
                                  const Color(0xFFFBBF24))
                              : isEventPast(event)
                                  ? (AppLocalizations.of(context).statusEnded,
                                      Colors.white.withOpacity(0.5))
                                  : (null, Colors.white);
                      if (label == null) return <Widget>[];
                      return [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ];
                    })(),
                  ],
                ),
              ],
            ),
          ),

          // Delete
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B4B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Color(0xFFFF4B4B),
                size: 16,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context).deleteEventTitle,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context).deleteEventBody,
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.55)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel,
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Text(AppLocalizations.of(context).delete,
                style: GoogleFonts.inter(
                    color: const Color(0xFFFF4B4B),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// Header épinglé pour les onglets du profil (reste en haut quand on scrolle).
class _SliverTabBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabBar({required this.child});

  static const double _height = 56;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _SliverTabBar oldDelegate) => true;
}