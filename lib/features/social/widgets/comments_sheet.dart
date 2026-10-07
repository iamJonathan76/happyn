import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/comments_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Les commentaires d'une publication, dans une feuille qui monte du bas.
///
/// [post] est la ligne de `feed_posts` : elle dit qui en est l'auteur (qui
/// peut supprimer n'importe quel commentaire chez lui) et si les commentaires
/// sont fermés. Renvoie quand la feuille se ferme ; l'appelant rafraîchit son
/// compteur.
Future<void> showCommentsSheet(
  BuildContext context,
  Map<String, dynamic> post,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CommentsSheet(post: post),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  const _CommentsSheet({required this.post});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  String get _postId => widget.post['id'] as String;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await addComment(_postId, text);
      _input.clear();
      ref.invalidate(postCommentsProvider(_postId));
    } catch (e) {
      debugPrint('addComment failed: $e');
      if (mounted) {
        showAppSnack(context, AppLocalizations.of(context).commentSendFailed);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Appui long : supprimer (le sien, ou tout commentaire sous sa propre
  /// publication) ou signaler (celui des autres). Un menu plutôt que des
  /// icônes sur chaque ligne : une liste couverte de drapeaux donne un ton de
  /// surveillance à ce qui est, le plus souvent, « trop bien la soirée ».
  Future<void> _actions(Map<String, dynamic> c, String? me) async {
    final l = AppLocalizations.of(context);
    final mine = c['author_id'] == me;
    final onMyPost = widget.post['author_id'] == me;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (mine || onMyPost)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: Text(
                  l.deleteComment,
                  style: AppText.bodySm.copyWith(color: AppColors.error),
                ),
                onTap: () => Navigator.of(sheetCtx).pop('delete'),
              ),
            if (!mine)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: AppColors.textMed),
                title: Text(
                  l.reportComment,
                  style: AppText.bodySm.copyWith(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetCtx).pop('report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'report') {
      await showReportSheet(
        context,
        targetType: 'comment',
        targetId: c['id'] as String,
      );
    } else if (choice == 'delete') {
      try {
        await deleteComment(c['id'] as String);
        ref.invalidate(postCommentsProvider(_postId));
        if (mounted) showAppSnack(context, l.commentDeleted);
      } catch (e) {
        debugPrint('deleteComment failed: $e');
        if (mounted) showAppSnack(context, l.commentDeleteFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(currentUserIdProvider);
    final comments = ref.watch(postCommentsProvider(_postId));
    final closed = widget.post['comments_disabled'] == true;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Text(l.comments, style: AppText.h4),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: comments.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, _) => _centered(l.commentsLoadFailed),
                data: (items) {
                  if (items.isEmpty) {
                    return _centered(
                      closed ? l.commentsClosed : l.commentsEmpty,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _CommentRow(
                      comment: items[i],
                      onLongPress: () => _actions(items[i], me),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            SafeArea(
              top: false,
              child: closed
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                      child: Text(
                        l.commentsClosed,
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          color: AppColors.textLow,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 500,
                              textCapitalization: TextCapitalization.sentences,
                              style: AppText.bodySm.copyWith(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: l.commentHint,
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.card,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sending ? null : _send,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centered(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.bodySm.copyWith(color: AppColors.textLow),
      ),
    ),
  );
}

class _CommentRow extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onLongPress;

  const _CommentRow({required this.comment, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final author = (comment['author'] as Map?)?.cast<String, dynamic>();
    final name = ((author?['full_name'] as String?) ?? '').trim();
    final username = (author?['username'] as String?) ?? '';
    final label = name.isNotEmpty
        ? name
        : (username.isNotEmpty ? '@$username' : 'HAPPYN');
    final avatar = (author?['avatar_url'] as String?) ?? '';
    final authorId = comment['author_id'] as String;

    final fallback = Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        label.replaceFirst('@', '')[0].toUpperCase(),
        style: AppText.smallBold.copyWith(color: AppColors.lavenderLight),
      ),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // L'auteur mène à son profil, comme sur une publication.
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: authorId),
                ),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: avatar.isEmpty
                      ? fallback
                      : CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => fallback,
                          errorWidget: (_, _, _) => fallback,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.smallBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppDates.messageDateTime(
                          context,
                          comment['created_at'] as String?,
                        ),
                        style: AppText.micro.copyWith(color: AppColors.textLow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (comment['body'] as String?) ?? '',
                    style: AppText.bodySm.copyWith(
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
