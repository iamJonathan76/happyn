import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/features/profile/public_profile_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Carte d'une publication du fil.
///
/// Point clé du produit : si la publication est rattachée à un événement, une
/// pastille cliquable mène à sa fiche — c'est la boucle « le social vend des
/// billets » (quelqu'un poste « J-3 avant ce concert », on tape, on réserve).
class PostCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;

  /// Appelé après suppression, pour que le fil se rafraîchisse.
  final VoidCallback? onChanged;

  const PostCard({super.key, required this.post, this.onChanged});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  // État optimiste : le like réagit tout de suite, sans attendre le serveur.
  bool? _likedOverride;
  int _likeDelta = 0;

  Map<String, dynamic> get _p => widget.post;

  bool get _liked =>
      _likedOverride ?? (_p['liked_by_me'] as bool? ?? false);

  int get _likeCount =>
      ((_p['like_count'] as num?)?.toInt() ?? 0) + _likeDelta;

  bool get _isMine =>
      _p['author_id'] == Supabase.instance.client.auth.currentUser?.id;

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() {
      _likedOverride = next;
      _likeDelta += next ? 1 : -1;
    });
    try {
      await setPostLiked(_p['id'] as String, next);
    } catch (e) {
      debugPrint('setPostLiked failed: $e');
      if (!mounted) return;
      // On remet l'état d'avant : mieux vaut un like qui « revient » qu'un
      // compteur qui ment.
      setState(() {
        _likedOverride = !next;
        _likeDelta += next ? -1 : 1;
      });
    }
  }

  Future<void> _openEvent() async {
    final eventId = _p['event_id'] as String?;
    if (eventId == null) return;
    final events = await ref.read(eventsProvider.future);
    final ev = events.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id'] == eventId,
          orElse: () => null,
        );
    if (!mounted || ev == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
    );
  }

  Future<void> _confirmDelete(AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.deletePost,
            style: AppText.h4.copyWith(color: Colors.white)),
        content: Text(l.deletePostConfirm, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.keep, style: AppText.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.delete,
                style: AppText.smallBold.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await deletePost(_p['id'] as String);
    if (!mounted) return;
    showAppSnack(context, l.postDeleted);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final caption = (_p['caption'] as String?)?.trim() ?? '';
    final imageUrl = (_p['image_url'] as String?) ?? '';
    final eventTitle = _p['event_title'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(l),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                    height: 220, color: AppColors.imagePlaceholder),
                errorWidget: (_, _, _) => Container(
                  height: 220,
                  color: AppColors.imagePlaceholder,
                  child: Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textLow),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eventTitle != null) ...[
                  _eventChip(eventTitle),
                  const SizedBox(height: 10),
                ],
                if (caption.isNotEmpty) ...[
                  Text(caption, style: AppText.bodySm.copyWith(height: 1.45)),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            size: 19,
                            color: _liked ? AppColors.pink : AppColors.textLow,
                          ),
                          if (_likeCount > 0) ...[
                            const SizedBox(width: 6),
                            Text('$_likeCount', style: AppText.small),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations l) {
    final name = (_p['author_name'] as String?)?.trim();
    final avatar = (_p['author_avatar'] as String?) ?? '';
    final label = (name == null || name.isEmpty) ? 'HAPPYN' : name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      child: Row(
        children: [
          // L'auteur mene a son profil : c'est le point d'entree du graphe
          // social — sans lui, personne ne peut suivre personne.
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    PublicProfileScreen(userId: _p['author_id'] as String))),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
          ClipOval(
            child: avatar.isEmpty
                ? _initials(label)
                : CachedNetworkImage(
                    imageUrl: avatar,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _initials(label),
                  ),
          ),
          const SizedBox(width: 10),
            ]),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      PublicProfileScreen(userId: _p['author_id'] as String))),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.captionBold),
                  Text(
                      AppDates.dayMonthYear(
                          context, _p['created_at'] as String?),
                      style: AppText.micro),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            position: PopupMenuPosition.under,
            icon: Icon(Icons.more_horiz, color: AppColors.textLow, size: 20),
            onSelected: (v) async {
              if (v == 'report') {
                await showReportSheet(context,
                    targetType: 'post', targetId: _p['id'] as String);
              } else if (v == 'delete') {
                await _confirmDelete(l);
              }
            },
            itemBuilder: (context) => [
              if (_isMine)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text(l.deletePost,
                        style: AppText.body.copyWith(color: AppColors.error)),
                  ]),
                )
              else
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    const Icon(Icons.flag_outlined,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(l.reportPost, style: AppText.body),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initials(String label) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        color: AppColors.primary.withOpacity(0.2),
        child: Text(label[0].toUpperCase(),
            style: AppText.captionBold.copyWith(color: AppColors.lavenderLight)),
      );

  /// Pastille « événement » : c'est elle qui transforme une publication en
  /// point d'entrée vers la billetterie.
  Widget _eventChip(String title) => GestureDetector(
        onTap: _openEvent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  size: 14, color: AppColors.lavenderLight),
              const SizedBox(width: 6),
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.smallBold
                        .copyWith(color: AppColors.lavenderLight)),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.lavenderLight),
            ],
          ),
        ),
      );
}
