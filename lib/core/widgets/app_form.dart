import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';

/// Briques de formulaire partagées. Avant, chaque écran redéfinissait sa propre
/// `_inputDec` / `_label` / `_snack` — quatre copies quasi identiques qui
/// dérivaient les unes des autres. Tout passe désormais par ici.

/// Décoration standard des champs de saisie (fond translucide, bordure douce,
/// bordure violette au focus).
///
/// [radius] : 14 partout, sauf l'écran de connexion qui utilise 16.
InputDecoration appInputDecoration(
  String hint, {
  IconData? icon,
  double radius = 14,
  EdgeInsetsGeometry? contentPadding,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.body.copyWith(color: AppColors.textFaint),
    prefixIcon:
        icon == null ? null : Icon(icon, color: AppColors.textLow, size: 18),
    filled: true,
    fillColor: Colors.white.withOpacity(0.055),
    border: border(Colors.white.withOpacity(0.09)),
    enabledBorder: border(Colors.white.withOpacity(0.09)),
    focusedBorder: border(AppColors.primary, width: 1.5),
    contentPadding: contentPadding,
  );
}

/// Libellé au-dessus d'un champ de formulaire.
class AppLabel extends StatelessWidget {
  final String text;
  const AppLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: AppText.captionBold
              .copyWith(color: AppColors.textMed, letterSpacing: 0.3),
        ),
      );
}

/// Affiche un message court en bas de l'écran, au style de l'app.
/// [background] permet un fond sémantique (vert de succès, rouge d'erreur…).
void showAppSnack(BuildContext context, String message, {Color? background}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppText.body.copyWith(color: Colors.white)),
      backgroundColor: background ?? AppColors.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
