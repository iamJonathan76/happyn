import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Échelle typographique de HAPPYN. Source unique de vérité des styles de
/// texte : on référence ces constantes au lieu d'appeler `GoogleFonts` partout.
///
/// Deux familles :
///   • **Poppins** — titres et éléments à forte emphase (weights 700–900)
///   • **Inter**   — texte courant, légendes, méta
///
/// La **couleur n'est volontairement pas figée** dans la plupart des styles :
/// elle varie beaucoup selon le contexte (accent de catégorie, état…). On la
/// précise à l'appel via `.copyWith(color: …)`.
///
/// Changer de police pour toute l'app = éditer ce fichier uniquement.
class AppText {
  // ── Poppins : titres / emphase ───────────────────────────────────────────
  /// 24 · w900 — titre de page (« Discover », « My Tickets »).
  static TextStyle get display => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: AppColors.textHigh,
      );

  /// 20 · w900 — gros titre (nom d'utilisateur, en-tête d'écran).
  static TextStyle get h1 => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.textHigh,
      );

  /// 17 · w800 — titre de barre d'app.
  static TextStyle get h2 => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textHigh,
      );

  /// 15 · w700 — titre de section, libellé de bouton principal.
  static TextStyle get h3 => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textHigh,
      );

  /// 14 · w700 — sous-titre, bouton secondaire.
  static TextStyle get h4 => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textHigh,
      );

  /// 13 · w700 — petit titre (titre de carte).
  static TextStyle get h5 => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textHigh,
      );

  // ── Inter : texte courant ────────────────────────────────────────────────
  /// 14 — corps de texte standard.
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textMed,
      );

  /// 13 — corps de texte réduit.
  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 13,
        color: AppColors.textMed,
      );

  /// 12 — légende.
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textMed,
      );

  /// 12 · w600 — légende accentuée.
  static TextStyle get captionBold => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textHigh,
      );

  /// 11 — méta, petites infos.
  static TextStyle get small => GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.textLow,
      );

  /// 11 · w700 — méta accentuée (liens « Voir tout », puces).
  static TextStyle get smallBold => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textHigh,
      );

  /// 10 — très petit texte (badges, mentions).
  static TextStyle get micro => GoogleFonts.inter(
        fontSize: 10,
        color: AppColors.textLow,
      );

  /// 9 · w700 — étiquettes minuscules en majuscules.
  static TextStyle get microBold => GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: AppColors.textHigh,
      );
}
