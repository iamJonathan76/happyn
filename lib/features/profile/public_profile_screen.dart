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
/// Les données viennent de la vue `public_profiles`, qui n'expose que le nom,
/// l'avatar, la bio et la ville — jamais l'email ni la date de naissance.
///
/// Les publications affichées sont toutes rattachées à un événement : le profil
/// raconte donc ce que la personne a vécu, pas ce qu'elle publie.
class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  bool get _isMe =>
      Supabase.instance.client.auth.currentUser?.id == userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          profileAsync.asData?.value?['full_name'] as String? ?? '',
          style: AppText.h2,
        ),
        actions: [
          if (!_isMe)
            PopupMenuButton<String>(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              position: PopupMenuPosition.under,
              icon: Icon(Icons.more_horiz, color: AppColors.textLow),
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
                    const Icon(Icons.flag_outlined,
                        size: 18, color: Colors.white),
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
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) {
          debugPrint('publicProfileProvider error: $e');
          return Center(
            child: Text(l.couldNotLoadEvents,
                style: AppText.body.copyWith(color: AppColors.textLow)),
          );
        },
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(l.blockedAccount,
                  style: AppText.body.copyWith(color: AppColors.textLow)),
            );
          }
          final posts = postsAsync.asData?.value ?? const [];
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _header(context, profile, posts.length),
                const SizedBox(height: 18),
                if (!_isMe) _followButton(context, ref, l),
                const SizedBox(height: 22),
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
          );
        },
      ),
    );
  }

  Widget _header(
      BuildContext context, Map<String, dynamic> profile, int postCount) {
    final l = AppLocalizations.of(context);
    final name = (profile['full_name'] as String?)?.trim() ?? '';
    final avatar = (profile['avatar_url'] as String?) ?? '';
    final bio = (profile['bio'] as String?)?.trim() ?? '';
    final city = (profile['city'] as String?)?.trim() ?? '';
    final label = name.isEmpty ? '?' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: ClipOval(
                child: avatar.isEmpty
                    ? _initials(label)
                    : CachedNetworkImage(
                        imageUrl: avatar,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _initials(label),
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('$postCount', l.postsCount),
                  _stat('${profile['followers_count'] ?? 0}', l.followers),
                  _stat('${profile['following_count'] ?? 0}', l.following),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(label, style: AppText.h3.copyWith(fontSize: 17)),
        if (city.isNotEmpty) ...[
          const SizedBox(height: 3),
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
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(bio, style: AppText.bodySm.copyWith(height: 1.45)),
        ],
      ],
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: AppText.h4.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: AppText.micro),
          ),
        ],
      );

  Widget _initials(String label) => Container(
        alignment: Alignment.center,
        color: AppColors.primary.withOpacity(0.2),
        child: Text(label[0].toUpperCase(),
            style: AppText.h1.copyWith(color: AppColors.lavenderLight)),
      );

  /// Suivre / Abonné. Le suivi réciproque est ce qui ouvrira, plus tard, la
  /// visibilité des présences — d'où l'importance de rendre l'action évidente.
  Widget _followButton(BuildContext context, WidgetRef ref, AppLocalizations l) {
    final following =
        ref.watch(followingProvider).asData?.value ?? const <String>{};
    final isFollowing = following.contains(userId);

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: isFollowing
          ? OutlinedButton(
              onPressed: () async {
                await unfollowUser(userId);
                ref.invalidate(followingProvider);
                ref.invalidate(publicProfileProvider(userId));
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(l.unfollow,
                  style: AppText.h4.copyWith(color: Colors.white)),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () async {
                  await followUser(userId);
                  ref.invalidate(followingProvider);
                  ref.invalidate(publicProfileProvider(userId));
                },
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
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
