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
          const SizedBox(height: 8),
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
