import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/features/social/widgets/post_card.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Profil public d'un utilisateur.
///
/// Données issues de la vue `public_profiles` : nom, avatar, bio, ville —
/// jamais l'email ni la date de naissance.
///
/// Le compteur « Événements » compte les événements distincts que la personne
/// a publiquement documentés. Il ne révèle donc rien de sa présence privée :
/// afficher ses événements à venir demanderait son consentement explicite,
/// géré par ailleurs (visibilité par événement).
class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  bool get _isMe => Supabase.instance.client.auth.currentUser?.id == userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final posts = ref.watch(userPostsProvider(userId)).asData?.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) {
          debugPrint('publicProfileProvider error: $e');
          return _centered(l.couldNotLoadEvents);
        },
        data: (profile) {
          if (profile == null) return _centered(l.blockedAccount);
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              ref.invalidate(publicProfileProvider(userId));
              ref.invalidate(userPostsProvider(userId));
              await ref.read(publicProfileProvider(userId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _banner(context, ref, l, profile),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _identity(profile),
                      const SizedBox(height: 16),
                      _stats(context, profile, posts),
                      const SizedBox(height: 16),
                      if ((profile['bio'] as String?)?.trim().isNotEmpty ==
                          true) ...[
                        Text((profile['bio'] as String).trim(),
                            style: AppText.bodySm.copyWith(height: 1.5)),
                        const SizedBox(height: 18),
                      ],
                      if (!_isMe) _followButton(context, ref, l),
                      const SizedBox(height: 24),
                      if (posts.isEmpty)
                        _empty(l)
                      else
                        ...posts.map((p) => PostCard(
                              post: p,
                              onChanged: () =>
                                  ref.invalidate(userPostsProvider(userId)),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _centered(String text) => Center(
        child: Text(text,
            style: AppText.body.copyWith(color: AppColors.textLow)),
      );

  /// Bannière dégradée + avatar en anneau, comme sur le profil personnel :
  /// les deux écrans doivent se ressembler.
  Widget _banner(BuildContext context, WidgetRef ref, AppLocalizations l,
      Map<String, dynamic> profile) {
    final name = (profile['full_name'] as String?)?.trim() ?? '';
    final avatar = (profile['avatar_url'] as String?) ?? '';
    final label = name.isEmpty ? '?' : name;

    return SizedBox(
      height: 196,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 132,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4C1D95), AppColors.primary, AppColors.pink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 12,
            right: 8,
            child: Row(
              children: [
                _roundButton(
                  Icons.arrow_back_ios_new,
                  () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (!_isMe) _moreMenu(context, ref, l),
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: 0,
            child: Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: avatar.isEmpty
                    ? _initials(label)
                    : CachedNetworkImage(
                        imageUrl: avatar,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _initials(label),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget _moreMenu(BuildContext context, WidgetRef ref, AppLocalizations l) =>
      PopupMenuButton<String>(
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
            await showReportSheet(context,
                targetType: 'user', targetId: userId);
          } else if (v == 'block') {
            final blocked =
                await confirmBlockUser(context, ref, userId: userId);
            if (blocked && context.mounted) {
              ref.invalidate(discoverFeedProvider);
              showAppSnack(context, l.userBlocked);
              Navigator.of(context).pop();
            }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'report',
            child: Row(children: [
              const Icon(Icons.flag_outlined, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(l.report, style: AppText.body),
            ]),
          ),
          PopupMenuItem(
            value: 'block',
            child: Row(children: [
              const Icon(Icons.block, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Text(l.block,
                  style: AppText.body.copyWith(color: AppColors.error)),
            ]),
          ),
        ],
      );

  Widget _identity(Map<String, dynamic> profile) {
    final name = (profile['full_name'] as String?)?.trim() ?? '';
    final city = (profile['city'] as String?)?.trim() ?? '';
    final handle =
        name.isEmpty ? '@happyn' : '@${name.toLowerCase().replaceAll(' ', '')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(name.isEmpty ? '—' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.h1.copyWith(fontSize: 22)),
        const SizedBox(height: 2),
        Text(handle, style: AppText.bodySm.copyWith(color: AppColors.lavender)),
        if (city.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 13, color: AppColors.textLow),
              const SizedBox(width: 4),
              Flexible(
                child: Text(city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _stats(BuildContext context, Map<String, dynamic> profile,
      List<Map<String, dynamic>> posts) {
    final l = AppLocalizations.of(context);
    // Événements distincts publiquement documentés — pas sa présence privée.
    final eventCount =
        posts.map((p) => p['event_id']).whereType<String>().toSet().length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          _stat('$eventCount', l.statEvents),
          _divider(),
          _stat('${profile['followers_count'] ?? 0}', l.followers),
          _divider(),
          _stat('${profile['following_count'] ?? 0}', l.following),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: AppText.h1.copyWith(fontSize: 19)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: AppText.micro),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
      width: 1, height: 30, color: Colors.white.withOpacity(0.08));

  Widget _initials(String label) => Container(
        alignment: Alignment.center,
        color: AppColors.primary.withOpacity(0.25),
        child: Text(label[0].toUpperCase(),
            style: AppText.h1.copyWith(color: AppColors.lavenderLight)),
      );

  /// Suivre / Abonné. Le suivi réciproque conditionne la visibilité des
  /// présences — d'où un bouton bien visible.
  Widget _followButton(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final following =
        ref.watch(followingProvider).asData?.value ?? const <String>{};
    final isFollowing = following.contains(userId);

    Future<void> toggle() async {
      isFollowing ? await unfollowUser(userId) : await followUser(userId);
      ref.invalidate(followingProvider);
      ref.invalidate(publicProfileProvider(userId));
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: isFollowing
          ? OutlinedButton.icon(
              onPressed: toggle,
              icon: const Icon(Icons.check, size: 17, color: Colors.white),
              label: Text(l.unfollow,
                  style: AppText.h4.copyWith(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: toggle,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(l.follow,
                    style: AppText.h4.copyWith(color: Colors.white)),
              ),
            ),
    );
  }

  Widget _empty(AppLocalizations l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 46),
        child: Column(
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(l.feedEmpty,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textLow)),
          ],
        ),
      );
}
