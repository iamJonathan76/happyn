import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/admin_provider.dart';
import 'package:happyn/core/providers/comments_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/utils/post_image.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/features/events/join_private_event_screen.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/features/social/widgets/comments_sheet.dart';
import 'package:happyn/features/social/widgets/share_sheet.dart';
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
  // Fermeture des commentaires basculée ici, avant que le fil ne se recharge.
  bool? _commentsDisabledOverride;

  bool get _commentsDisabled =>
      _commentsDisabledOverride ?? (_p['comments_disabled'] == true);
  int get _commentCount => (_p['comment_count'] as num?)?.toInt() ?? 0;

  Future<void> _openComments() async {
    await showCommentsSheet(
        context, {..._p, 'comments_disabled': _commentsDisabled});
    // Le compteur vient du fil : on lui demande de se recharger.
    widget.onChanged?.call();
  }

  Future<void> _toggleComments(AppLocalizations l) async {
    final next = !_commentsDisabled;
    try {
      await setCommentsDisabled(_p['id'] as String, next);
      if (!mounted) return;
      setState(() => _commentsDisabledOverride = next);
      showAppSnack(context, next ? l.commentsTurnedOff : l.commentsTurnedOn);
      widget.onChanged?.call();
    } catch (e) {
      debugPrint('setCommentsDisabled failed: $e');
      if (mounted) showAppSnack(context, l.moderationFailed);
    }
  }

  Map<String, dynamic> get _p => widget.post;

  bool get _liked =>
      _likedOverride ?? (_p['liked_by_me'] as bool? ?? false);

  int get _likeCount =>
      ((_p['like_count'] as num?)?.toInt() ?? 0) + _likeDelta;

  bool get _isMine =>
      _p['author_id'] == Supabase.instance.client.auth.currentUser?.id;

  /// L'auteur est l'organisateur de l'événement rattaché.
  ///
  /// Calculé par la vue `feed_posts` (`e.created_by = p.author_id`), jamais
  /// par le client : c'est un signe de confiance, il ne doit pas dépendre
  /// d'une donnée que l'app pourrait interpréter de travers.
  bool get _isOrganizer => _p['author_is_organizer'] as bool? ?? false;

  /// L'événement est privé : on ne peut pas y prendre de billet, seulement y
  /// être invité. La pastille doit le dire, sinon elle promet une billetterie
  /// qui n'existe pas et le toucher n'aboutit qu'à une demande de code.
  bool get _eventIsPrivate => _p['event_visibility'] == 'private';

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
    if (!mounted) return;

    // Introuvable = la RLS nous le cache, donc c'est un evenement prive
    // auquel on n'a pas acces. On ne peut pas ouvrir la fiche, mais rester
    // muet serait pire : la pastille dirait « voir l'evenement » et ne ferait
    // rien. On explique, et on emmene la ou le code se saisit.
    if (ev == null) {
      showAppSnack(context, AppLocalizations.of(context).privateEventNeedsCode);
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const JoinPrivateEventScreen()));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
    );
  }

  /// Corriger sa légende, sans avoir à supprimer puis republier.
  ///
  /// Republier coûtait les mentions « j'aime » déjà reçues et remontait la
  /// publication en tête du fil pour une virgule — deux raisons de laisser la
  /// faute plutôt que de la corriger.
  ///
  /// La photo n'est pas modifiable ici : c'est elle que les gens ont aimée,
  /// et la remplacer changerait le contenu sous leur approbation. Une légende
  /// corrigée, elle, reste la même publication — et la base marque l'édition.
  Future<void> _editCaption(AppLocalizations l) async {
    final controller =
        TextEditingController(text: (_p['caption'] as String?) ?? '');
    final hasImage = ((_p['image_url'] as String?) ?? '').isNotEmpty;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        // Sans ça, le clavier recouvre le champ qu'on est en train d'écrire.
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.editPost, style: AppText.h4.copyWith(color: Colors.white)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              style: AppText.body.copyWith(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: Text(l.cancel, style: AppText.body),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // Une publication sans photo ET sans texte n'existe pas :
                    // la contrainte `post_not_empty` la refuse en base. Mieux
                    // vaut le dire ici que laisser partir une erreur SQL.
                    if (!hasImage && controller.text.trim().isEmpty) {
                      showAppSnack(sheetCtx, l.postNeedsText);
                      return;
                    }
                    Navigator.of(sheetCtx).pop(true);
                  },
                  child: Text(l.saveChanges,
                      style: AppText.smallBold
                          .copyWith(color: AppColors.lavenderLight)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    try {
      await updatePost(_p['id'] as String, controller.text);
    } catch (e) {
      debugPrint('updatePost: $e');
      if (mounted) showAppSnack(context, l.actionFailed);
      return;
    }
    if (!mounted) return;
    showAppSnack(context, l.postUpdated);
    widget.onChanged?.call();
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


  /// Retrait par un moderateur, depuis le contenu lui-meme.
  ///
  /// Tomber sur un contenu problematique en naviguant ne devrait pas obliger a
  /// le retenir, ouvrir les reglages, et esperer que quelqu'un l'ait signale.
  /// Passe par la meme fonction que la file : l'action est donc tracee dans
  /// admin_actions, et le droit revérifié en base.
  Future<void> _adminRemove(AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.actionRemove,
            style: AppText.h4.copyWith(color: Colors.white)),
        content: Text(l.adminRemoveConfirm, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.keep, style: AppText.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.actionRemove,
                style: AppText.smallBold.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await removeContent('post', _p['id'] as String);
      if (!mounted) return;
      showAppSnack(context, l.contentRemoved);
      widget.onChanged?.call();
    } catch (e) {
      debugPrint('adminRemove failed: $e');
      if (mounted) showAppSnack(context, l.moderationFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final caption = (_p['caption'] as String?)?.trim() ?? '';
    final imageUrl = (_p['image_url'] as String?) ?? '';
    final eventTitle = _p['event_title'] as String?;
    final author = ((_p['author_name'] as String?) ?? '').trim();

    // Bord a bord, sans cadre : une publication est une bande du fil, comme
    // sur Instagram. Un trait fin la separe de la suivante.
    return Container(
      padding: const EdgeInsets.only(bottom: 18),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(l),
          // L'image dans sa forme, bornee entre 4:5 et 1.91:1 : une affiche
          // paysage n'est plus rognee. La forme est connue avant que l'image
          // arrive (`image_aspect`), donc le fil ne saute pas au chargement.
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio:
                  displayAspect((_p['image_aspect'] as num?)?.toDouble()),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.imagePlaceholder),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.imagePlaceholder,
                  child: Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textLow),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                _action(
                  onTap: _toggleLike,
                  icon: AnimatedScale(
                    scale: _liked ? 1.12 : 1,
                    duration: const Duration(milliseconds: 140),
                    child: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      size: 25,
                      color: _liked ? AppColors.pink : Colors.white,
                    ),
                  ),
                  count: _likeCount,
                  countColor: _liked ? AppColors.pink : Colors.white,
                ),
                _action(
                  onTap: _openComments,
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: 23, color: Colors.white),
                  count: _commentCount,
                ),
                _action(
                  onTap: () => showShareSheet(context, ShareTarget.post(_p)),
                  icon: const Icon(Icons.send_outlined,
                      size: 23, color: Colors.white),
                ),
              ],
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              // Le nom en tete de la legende : on lit qui parle avant ce
              // qu'il dit, sans remonter jusqu'a l'en-tete.
              child: Text.rich(
                TextSpan(children: [
                  if (author.isNotEmpty)
                    TextSpan(
                      text: '$author  ',
                      style: AppText.bodySm.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  TextSpan(
                    text: caption,
                    style: AppText.bodySm
                        .copyWith(color: Colors.white, height: 1.45),
                  ),
                ]),
              ),
            ),
          if (eventTitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _eventCard(eventTitle, l),
            ),
        ],
      ),
    );
  }

  /// Une icone d'action et son compteur, comme sur Instagram : le chiffre
  /// colle a ce qu'il compte. Pas de « 0 » : une icone seule invite mieux.
  Widget _action({
    required VoidCallback onTap,
    required Widget icon,
    int count = 0,
    Color countColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
        child: Row(
          // `min` : cette Row est elle-meme dans une Row, qui donne a ses
          // enfants une largeur infinie.
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text('$count',
                  style: AppText.smallBold.copyWith(color: countColor)),
            ],
          ],
        ),
      ),
    );
  }


  Widget _header(AppLocalizations l) {
    final name = (_p['author_name'] as String?)?.trim();
    final avatar = (_p['author_avatar'] as String?) ?? '';
    final label = (name == null || name.isEmpty) ? 'HAPPYN' : name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          // L'auteur mene a son profil : c'est le point d'entree du graphe
          // social — sans lui, personne ne peut suivre personne.
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(userId: _p['author_id'] as String))),
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
                      ProfileScreen(userId: _p['author_id'] as String))),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.captionBold),
                      ),
                      if (_isOrganizer) ...[
                        const SizedBox(width: 6),
                        _organizerBadge(l),
                      ],
                    ],
                  ),
                  // « modifié » à côté de la date, pas à la place : on garde
                  // la date de publication (c'est elle qui situe le moment) et
                  // on signale que le texte a bougé depuis. Sans cette
                  // mention, une publication aimée par dix personnes pourrait
                  // dire autre chose que ce qu'elles ont approuvé.
                  Text(
                      _p['edited_at'] == null
                          ? AppDates.dayMonthYear(
                              context, _p['created_at'] as String?)
                          : '${AppDates.dayMonthYear(context, _p['created_at'] as String?)} · ${l.postEdited}',
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
              if (v == 'admin_remove') {
                await _adminRemove(l);
              } else if (v == 'report') {
                await showReportSheet(context,
                    targetType: 'post', targetId: _p['id'] as String);
              } else if (v == 'edit') {
                await _editCaption(l);
              } else if (v == 'toggle_comments') {
                await _toggleComments(l);
              } else if (v == 'delete') {
                await _confirmDelete(l);
              }
            },
            itemBuilder: (context) => [
              // Visible des seuls moderateurs. Ce n'est pas ce qui protege :
              // removeContent revérifie le droit en base.
              if (!_isMine &&
                  ref.watch(isAdminProvider).asData?.value == true)
                PopupMenuItem(
                  value: 'admin_remove',
                  child: Row(children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text(l.actionRemove,
                        style: AppText.body.copyWith(color: AppColors.error)),
                  ]),
                ),
              // Modifier avant supprimer : c'est l'action qu'on cherche le
              // plus souvent, et la plus reversible des deux.
              if (_isMine)
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(l.editPost, style: AppText.body),
                  ]),
                ),
              if (_isMine)
                PopupMenuItem(
                  value: 'toggle_comments',
                  child: Row(children: [
                    Icon(
                        _commentsDisabled
                            ? Icons.chat_bubble_outline
                            : Icons.comments_disabled_outlined,
                        size: 18,
                        color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                        _commentsDisabled
                            ? l.turnOnComments
                            : l.turnOffComments,
                        style: AppText.body),
                  ]),
                ),
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
        color: AppColors.primary.withValues(alpha: 0.2),
        child: Text(label[0].toUpperCase(),
            style: AppText.captionBold.copyWith(color: AppColors.lavenderLight)),
      );

  /// Pastille « organisateur ».
  ///
  /// Dire qui parle depuis la scène plutôt que depuis la foule : sans elle,
  /// l'annonce officielle d'un organisateur a exactement le même poids visuel
  /// que la photo floue d'un inconnu.
  Widget _organizerBadge(AppLocalizations l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_outlined,
                size: 11, color: AppColors.lavenderLight),
            const SizedBox(width: 4),
            Text(l.organizerBadge,
                style: AppText.micro.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.lavenderLight)),
          ],
        ),
      );

  /// La mini-carte de l'evenement sous la publication : vignette, titre,
  /// date et ville, et « Voir » qui ouvre la fiche.
  ///
  /// La date et le lieu donnent envie d'ouvrir avant meme de toucher : c'est
  /// le chemin vers les billets. Evenement prive : ni affiche ni lieu, seulement
  /// « Sur invitation » — la publication peut etre visible de gens a qui
  /// l'organisateur n'a pas ouvert l'evenement.
  Widget _eventCard(String title, AppLocalizations l) {
    final private = _eventIsPrivate;
    final image = (_p['event_image'] as String?) ?? '';
    final date =
        AppDates.dowDayMonthYear(context, _p['event_start_date'] as String?);
    final city = ((_p['event_city'] as String?) ?? '').trim();
    final subtitle = private
        ? l.onInvitationChip
        : [date, city].where((v) => v.isNotEmpty).join(' · ');

    final thumbFallback = Container(
      color: AppColors.primary.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Icon(private ? Icons.lock_outline : Icons.event_outlined,
          size: 20, color: AppColors.lavenderLight),
    );

    return GestureDetector(
      onTap: _openEvent,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 46,
                height: 46,
                child: private || image.isEmpty
                    ? thumbFallback
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => thumbFallback,
                        errorWidget: (_, _, _) => thumbFallback,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.smallBold.copyWith(color: Colors.white)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.micro.copyWith(color: AppColors.textLow)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.messageMine,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(l.viewAction,
                  style: AppText.smallBold.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
