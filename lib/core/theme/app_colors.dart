import 'package:flutter/material.dart';

/// Palette centrale de HAPPYN. Source unique de vérité des couleurs :
/// on référence ces constantes au lieu de coder les hex en dur.
class AppColors {
  // ── Fonds ────────────────────────────────────────────────────────────────
  /// Fond principal des pages (près du noir).
  static const Color background = Color(0xFF08080F);
  static const Color backgroundSecondary = Color(0xFF120F24);
  /// Fond des cartes / surfaces sombres (dialogs, snackbars).
  static const Color card = Color(0xFF1A1535);
  /// Carte encore plus sombre (billets, hero).
  static const Color cardDark = Color(0xFF13111C);
  /// Fond des bottom sheets / dialogs violets.
  static const Color sheet = Color(0xFF16122B);
  /// Fond de remplacement d'image (placeholder).
  static const Color imagePlaceholder = Color(0xFF1A0F3D);

  // ── Marque ───────────────────────────────────────────────────────────────
  /// Violet principal.
  static const Color primary = Color(0xFF7C3AED);
  /// Rose / accent secondaire.
  static const Color pink = Color(0xFFEC4899);
  /// Rose clair.
  static const Color pinkLight = Color(0xFFF472B6);
  /// Lavande (accents doux, liens).
  static const Color lavender = Color(0xFFA78BFA);
  /// Lavande claire.
  static const Color lavenderLight = Color(0xFFC4B5FD);

  /// Dégradé de marque (violet → rose).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Sémantique ───────────────────────────────────────────────────────────
  /// Rouge (danger / erreurs / annulation).
  static const Color error = Color(0xFFFF4B4B);
  /// Orange (avertissement / « draft »).
  static const Color warning = Color(0xFFF97316);
  /// Ambre (statut dépublié).
  static const Color amber = Color(0xFFFBBF24);
  /// Vert (succès / admis).
  static const Color green = Color(0xFF34D399);
  /// Vert « validé » plus saturé.
  static const Color success = Color(0xFF1DB954);
  /// Bleu (accents ponctuels).
  static const Color blue = Color(0xFF60A5FA);

  // ── Texte ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0A8D4);
  static const Color textMuted = Color(0xFF6B6280);
  /// Blanc cassé (texte sur fond sombre).
  static const Color textLight = Color(0xFFF0EEFF);

  // ── Tokens sémantiques de foreground (texte/icônes sur fond sombre) ────────
  // 4 niveaux d'emphase. Aujourd'hui basés sur du blanc translucide ; le jour
  // où on ajoute un mode clair, ce sont ces tokens qui s'inverseront (via une
  // ThemeExtension) sans toucher aux écrans.
  /// Emphase haute (≈ blanc plein). Titres, valeurs importantes.
  static const Color textHigh = Color(0xFFFFFFFF);
  /// Emphase moyenne. Corps de texte secondaire.
  static final Color textMed = Colors.white.withOpacity(0.65);
  /// Emphase basse. Légendes, méta.
  static final Color textLow = Colors.white.withOpacity(0.40);
  /// Emphase très basse. Placeholders, hints.
  static final Color textFaint = Colors.white.withOpacity(0.25);

  // ── Divers ───────────────────────────────────────────────────────────────
  static const Color border = Color(0xFF2A2448);
}
