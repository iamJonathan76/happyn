import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/admin_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// File de modération, réservée aux administrateurs.
///
/// Elle vit dans l'app plutôt que dans un outil séparé : on est déjà connecté,
/// et un signalement se traite en regardant le contenu — ce que l'app sait
/// déjà afficher. Un back-office web aurait demandé de tout reconstruire.
///
/// L'écran n'est qu'une commodité : chaque action est revérifiée en base
/// (`i_am_admin`). Forcer son ouverture ne donnerait qu'une file vide.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reports = ref.watch(adminReportsProvider('pending'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.moderationQueue, style: AppText.h3),
      ),
      body: reports.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        // On distingue « échec » de « vide » : les trois fois où une erreur a
        // ete avalee dans ce projet, elle s'est deguisee en liste vide.
        error: (e, _) => _message(Icons.error_outline, '$e'),
        data: (list) => list.isEmpty
            ? _message(Icons.inbox_outlined, l.noReports)
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                onRefresh: () async =>
                    ref.invalidate(adminReportsProvider('pending')),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _ReportCard(report: list[i]),
                ),
              ),
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textFaint),
              const SizedBox(height: 14),
              Text(text,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textLow)),
            ],
          ),
        ),
      );
}

class _ReportCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> report;
  const _ReportCard({required this.report});

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _busy = false;

  Map<String, dynamic> get _r => widget.report;
  String get _type => _r['target_type'] as String;

  /// Exécute une action puis marque le signalement traité, et ne rafraîchit la
  /// file qu'en cas de succès : sinon la carte disparaîtrait alors que rien
  /// n'a été fait, et le signalement serait perdu de vue.
  Future<void> _run(Future<void> Function() action, String status) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      await resolveReport(_r['id'] as String, status);
      if (!mounted) return;
      showAppSnack(context, l.actionDone);
      ref.invalidate(adminReportsProvider('pending'));
    } catch (e) {
      debugPrint('moderation action failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnack(context, l.moderationFailed);
    }
  }

  String _typeLabel(AppLocalizations l) => switch (_type) {
        'event' => l.reportedEvent,
        'post' => l.reportedPost,
        _ => l.reportedUser,
      };

  IconData get _fallbackIcon => switch (_type) {
        'event' => Icons.event_outlined,
        'post' => Icons.image_outlined,
        _ => Icons.person_outline,
      };

  /// La vignette du contenu visé.
  ///
  /// Une vignette de 58 px suffit pour reconnaître une affiche, pas pour juger
  /// une image litigieuse : un appui l'ouvre en grand. Sans image (contenu déjà
  /// retiré, publication de texte seul, compte sans avatar) on montre une
  /// pastille, jamais un trou — un vide se lit comme un bug.
  Widget _thumbnail(String? url) {
    final placeholder = Container(
      color: AppColors.card,
      child: Icon(_fallbackIcon, color: AppColors.textFaint, size: 22),
    );

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        height: 58,
        child: url == null || url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );

    if (url == null || url.isEmpty) return thumb;
    return GestureDetector(
      onTap: () => _openFullSize(url),
      child: thumb,
    );
  }

  /// Le dossier complet du signalement, avant de trancher.
  ///
  /// Retirer un événement prive des gens de ce qu'ils ont payé ; suspendre un
  /// compte fait taire quelqu'un. Ces deux gestes ne se décident pas sur un
  /// titre et une vignette de 58 px — il faut la description, les dates, le
  /// lieu, et surtout combien de personnes sont concernées.
  ///
  /// Les actions restent sur la carte, pas ici : on lit, on referme, on
  /// décide. Un bouton « Suspendre » au bas d'un écran de lecture s'appuie
  /// trop facilement.
  void _openDossier(AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Consumer(
          builder: (ctx, ref, _) {
            final target =
                ref.watch(adminReportTargetProvider(_r['id'] as String));
            return target.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e',
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(color: AppColors.textLow)),
                ),
              ),
              data: (t) => t == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.reportTargetGone,
                            textAlign: TextAlign.center,
                            style: AppText.body
                                .copyWith(color: AppColors.textLow)),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: _dossierLines(l, t),
                    ),
            );
          },
        ),
      ),
    );
  }

  /// Ce qu'on affiche dépend du type : un événement se juge sur ses dates et
  /// ses billets, une publication sur son texte et son audience, un compte sur
  /// ce qu'il a produit.
  List<Widget> _dossierLines(AppLocalizations l, Map<String, dynamic> t) {
    final image = (t['image_url'] ?? t['avatar_url']) as String?;
    final lines = <Widget>[];

    if (image != null && image.isNotEmpty) {
      lines.add(ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: image,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
              height: 200, color: AppColors.card),
          errorWidget: (_, __, ___) => Container(
              height: 200, color: AppColors.card),
        ),
      ));
      lines.add(const SizedBox(height: 18));
    }

    void title(String? value) {
      if (value == null || value.trim().isEmpty) return;
      lines.add(Text(value,
          style: AppText.h3.copyWith(color: Colors.white)));
      lines.add(const SizedBox(height: 10));
    }

    void row(IconData icon, String? value) {
      if (value == null || value.trim().isEmpty) return;
      lines.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.textFaint),
            const SizedBox(width: 10),
            Expanded(child: Text(value, style: AppText.small)),
          ],
        ),
      ));
    }

    int count(String key) => (t[key] as num?)?.toInt() ?? 0;

    switch (t['type'] as String?) {
      case 'event':
        title(t['title'] as String?);
        row(Icons.person_outline, t['author_name'] as String?);
        row(Icons.calendar_today_outlined,
            AppDates.dayMonthYear(context, t['start_date'] as String?));
        row(Icons.place_outlined,
            [t['location'], t['city']]
                .where((v) => v != null && '$v'.trim().isNotEmpty)
                .join(' · '));
        row(Icons.sell_outlined, t['category'] as String?);
        row(Icons.info_outline, t['status'] as String?);
        if (t['visibility'] == 'private') {
          row(Icons.lock_outline, l.reportPrivateEvent);
        }
        // Le chiffre qui pèse le plus dans la décision.
        row(Icons.confirmation_number_outlined,
            l.reportTicketsSold(count('tickets_sold')));
        final desc = (t['description'] as String?)?.trim();
        if (desc != null && desc.isNotEmpty) {
          lines.add(const SizedBox(height: 10));
          lines.add(Text(desc, style: AppText.body.copyWith(height: 1.5)));
        }
        break;

      case 'post':
        title((t['caption'] as String?)?.trim().isEmpty ?? true
            ? null
            : t['caption'] as String?);
        row(Icons.person_outline, t['author_name'] as String?);
        row(Icons.event_outlined, t['event_title'] as String?);
        row(Icons.schedule,
            AppDates.dayMonthYear(context, t['created_at'] as String?));
        row(Icons.favorite_border, l.reportLikes(count('like_count')));
        break;

      case 'user':
        title(t['full_name'] as String?);
        final username = (t['username'] as String?)?.trim();
        row(Icons.alternate_email,
            username == null || username.isEmpty ? null : '@$username');
        row(Icons.article_outlined,
            l.reportAuthorActivity(count('post_count'), count('event_count')));
        if (t['is_suspended'] == true) {
          row(Icons.block, l.actionSuspend);
        }
        break;
    }

    return lines;
  }

  void _openFullSize(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (dialogContext) => GestureDetector(
        // N'importe où en dehors de l'image referme : à ce moment-là on regarde,
        // on ne manipule pas, et chercher une croix fait perdre du temps.
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              errorWidget: (_, __, ___) => Icon(Icons.broken_image_outlined,
                  color: AppColors.textFaint, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = (_r['target_label'] as String?)?.trim();
    final author = _r['target_author'] as String?;
    final authorName = (_r['author_name'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_typeLabel(l),
                    style: AppText.microBold
                        .copyWith(color: AppColors.lavenderLight)),
              ),
              const Spacer(),
              Text(AppDates.dayMonthYear(context, _r['created_at'] as String?),
                  style: AppText.micro),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(_r['target_image'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label == null || label.isEmpty ? '—' : label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: Colors.white),
                    ),
                    if (authorName != null && authorName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(authorName, style: AppText.micro),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.reportedBy(_r['reason'] as String), style: AppText.small),
          if ((_r['details'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(_r['details'] as String,
                style: AppText.small.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 14),
          if (_busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // En premier, et dans une couleur qui n'alarme pas : c'est
                // l'action a faire AVANT les deux autres, pas une de plus.
                _action(l.reportSeeDetails, AppColors.lavenderLight,
                    () => _openDossier(l)),
                // Un signalement visant un compte n'a pas de contenu a retirer.
                if (_type != 'user')
                  _action(l.actionRemove, AppColors.error,
                      () => _run(
                            () => removeContent(_type, _r['target_id'] as String,
                                reportId: _r['id'] as String),
                            'actioned',
                          )),
                if (author != null)
                  _action(l.actionSuspend, AppColors.error,
                      () => _run(
                            () => setUserSuspended(author, true,
                                reportId: _r['id'] as String),
                            'actioned',
                          )),
                _action(l.actionDismiss, AppColors.textLow,
                    () => _run(() async {}, 'dismissed')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _action(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(label,
              style: AppText.smallBold.copyWith(color: color)),
        ),
      );
}
