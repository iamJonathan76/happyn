import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Affiche le code d'invitation après la création (ou le passage en privé)
/// d'un événement, avec copie du code seul ou du message d'invitation complet.
Future<void> showInviteCodeDialog(
  BuildContext context, {
  required String eventTitle,
  required String code,
}) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => Dialog(
      backgroundColor: AppColors.sheet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline,
                color: AppColors.lavenderLight, size: 34),
            const SizedBox(height: 12),
            Text(
              l.privateEventCreated,
              textAlign: TextAlign.center,
              style: AppText.h2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              l.privateEventCreatedBody,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            // Le code, bien lisible
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  code,
                  style: AppText.display
                      .copyWith(color: Colors.white, letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showAppSnack(context, l.codeCopied);
                    },
                    icon:
                        const Icon(Icons.copy, size: 16, color: Colors.white),
                    label: Text(l.copyCode,
                        style: AppText.body.copyWith(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.textFaint),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: l.inviteShareText(eventTitle, code)));
                      showAppSnack(context, l.inviteCopied);
                    },
                    icon: const Icon(Icons.ios_share,
                        size: 16, color: Colors.white),
                    label: Text(l.share,
                        style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l.done, style: AppText.body),
            ),
          ],
        ),
      ),
    ),
  );
}
