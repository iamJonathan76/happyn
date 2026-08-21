import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/moderation_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Libellé localisé d'un motif de signalement (les clés restent en base).
String reportReasonLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'spam':
      return l.reportReasonSpam;
    case 'inappropriate':
      return l.reportReasonInappropriate;
    case 'scam':
      return l.reportReasonScam;
    case 'misleading':
      return l.reportReasonMisleading;
    default:
      return l.reportReasonOther;
  }
}

/// Feuille de signalement : choix d'un motif + précisions optionnelles.
/// [targetType] vaut 'event' ou 'user'.
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) {
  final l = AppLocalizations.of(context);
  final detailsController = TextEditingController();
  String? selected;
  bool sending = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(l.reportReason, style: AppText.h3),
            const SizedBox(height: 14),

            for (final key in kReportReasons)
              GestureDetector(
                onTap: sending ? null : () => setSheet(() => selected = key),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: selected == key
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected == key
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected == key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: selected == key
                            ? AppColors.primary
                            : AppColors.textLow,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(reportReasonLabel(l, key),
                            style: AppText.bodySm),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 6),
            TextField(
              controller: detailsController,
              enabled: !sending,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: appInputDecoration(l.reportDetailsHint),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (selected == null || sending)
                    ? null
                    : () async {
                        setSheet(() => sending = true);
                        try {
                          await submitReport(
                            targetType: targetType,
                            targetId: targetId,
                            reason: selected!,
                            details: detailsController.text,
                          );
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          if (context.mounted) {
                            showAppSnack(context, l.reportThanks);
                          }
                        } catch (e) {
                          debugPrint('submitReport failed: $e');
                          setSheet(() => sending = false);
                          if (sheetCtx.mounted) {
                            showAppSnack(sheetCtx, l.reportFailed);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(l.reportSubmit,
                        style: AppText.h4.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Demande confirmation puis bloque un organisateur.
/// Renvoie `true` si le blocage a eu lieu.
Future<bool> confirmBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.blockConfirmTitle,
          style: AppText.h4.copyWith(color: Colors.white)),
      content: Text(l.blockConfirmBody, style: AppText.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l.keep, style: AppText.body),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(l.block,
              style: AppText.smallBold.copyWith(color: AppColors.error)),
        ),
      ],
    ),
  );

  if (ok != true) return false;
  await blockUser(userId);
  ref.invalidate(blockedUsersProvider);
  return true;
}
