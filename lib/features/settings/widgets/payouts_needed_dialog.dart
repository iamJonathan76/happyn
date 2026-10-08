import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// « Configure tes versements » : avant de creer ou de publier un evenement
/// payant sans compte de versement actif.
///
/// Sans ce moment, l'organisateur publiait un evenement qui ne pouvait rien
/// vendre, et l'acheteur ne l'apprenait qu'au paiement. Renvoie vrai si la
/// personne choisit de continuer (vers le brouillon ou les versements).
Future<bool> showPayoutsNeededDialog(
  BuildContext context, {
  required String body,
  required String confirmLabel,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.payoutsNeededTitle,
          style: AppText.h4.copyWith(color: Colors.white)),
      content: Text(body, style: AppText.body.copyWith(height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l.cancel, style: AppText.body),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(confirmLabel,
              style: AppText.smallBold.copyWith(color: AppColors.lavenderLight)),
        ),
      ],
    ),
  );
  return ok == true;
}
