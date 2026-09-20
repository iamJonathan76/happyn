import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/admin_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/features/events/join_private_event_screen.dart';
import 'package:happyn/features/profile/profile_screen.dart';
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

  /// L'événement n'a pas encore eu lieu — il reste donc quelque chose à
  /// réserver. Proposer « Obtenir des billets » sous une photo d'un concert
  /// d'il y a trois mois serait une promesse creuse.
  bool get _eventUpcoming {
    final raw = _p['event_start_date'] as String?;
    final date = raw == null ? null : DateTime.tryParse(raw);
    return date != null && date.isAfter(DateTime.now());
  }

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
          // Ratio contraint a 4:5. Sans cela une photo en portrait prenait
          // toute la hauteur de l'ecran et poussait la legende hors du champ.
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
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
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eventTitle != null) ...[
                  _eventChip(eventTitle, l),
                  const SizedBox(height: 10),
                ],
                if (caption.isNotEmpty) ...[
                  Text(caption, style: AppText.bodySm.copyWith(height: 1.45)),
                  const SizedBox(height: 10),
                ],
                GestureDetector(
                  onTap: _toggleLike,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        AnimatedScale(
                          scale: _liked ? 1.12 : 1,
                          duration: const Duration(milliseconds: 140),
                          child: Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            size: 21,
                            color: _liked ? AppColors.pink : AppColors.textLow,
                          ),
                        ),
                        if (_likeCount > 0) ...[
                          const SizedBox(width: 7),
                          Text('$_likeCount',
                              style: AppText.smallBold.copyWith(
                                  color: _liked
                                      ? AppColors.pink
                                      : AppColors.textMed)),
                        ],
                      ],
                    ),
                  ),
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

  /// Pastille « organisateur ».
  ///
  /// Dire qui parle depuis la scène plutôt que depuis la foule : sans elle,
  /// l'annonce officielle d'un organisateur a exactement le même poids visuel
  /// que la photo floue d'un inconnu.
  Widget _organizerBadge(AppLocalizations l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
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

  /// Pastille « événement » : c'est elle qui transforme une publication en
  /// point d'entrée vers la billetterie.
  ///
  /// Deux versions volontairement différentes. Événement à venir : l'action
  /// est nommée (« Obtenir des billets ») et la date rappelée, parce qu'il
  /// reste quelque chose à faire. Événement passé : la pastille redevient
  /// discrète et dit seulement « Voir l'événement » — promettre des billets
  /// pour une soirée déjà finie ne serait pas une incitation mais un mensonge.
  Widget _eventChip(String title, AppLocalizations l) {
    final upcoming = _eventUpcoming;
    final date = AppDates.dayMonthYear(context, _p['event_start_date'] as String?);

    return GestureDetector(
      onTap: _openEvent,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(upcoming ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primary.withOpacity(upcoming ? 0.45 : 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.confirmation_number_outlined,
                size: 14, color: AppColors.lavenderLight),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.smallBold
                          .copyWith(color: AppColors.lavenderLight)),
                  const SizedBox(height: 1),
                  Text(
                    _eventIsPrivate
                        ? l.onInvitationChip
                        : upcoming && date.isNotEmpty
                            ? '${l.getTickets} · $date'
                            : l.viewEvent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.micro,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.lavenderLight),
          ],
        ),
      ),
    );
  }
}
