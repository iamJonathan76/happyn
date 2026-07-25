import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formatage des dates localisé (FR/EN) via intl. La locale est lue depuis le
/// contexte, donc ça suit le choix de langue de l'utilisateur.
/// initializeDateFormatting() est appelé une fois dans main().
class AppDates {
  static String _loc(BuildContext c) => Localizations.localeOf(c).languageCode;

  /// Ex. « Fri, Jan 5, 2026 » / « ven. 5 janv. 2026 ».
  static String dowDayMonthYear(BuildContext c, String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '';
    return DateFormat.yMMMEd(_loc(c)).format(dt);
  }

  /// Ex. « Jan 5, 2026 » / « 5 janv. 2026 ».
  static String dayMonthYear(BuildContext c, String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '';
    return DateFormat.yMMMd(_loc(c)).format(dt);
  }

  /// Ex. « January 2026 » / « janvier 2026 ».
  static String monthYear(BuildContext c, String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '—';
    return DateFormat.yMMMM(_loc(c)).format(dt);
  }

  /// Heure localisée (12 h en EN, 24 h en FR). Ex. « 7:30 PM » / « 19:30 ».
  static String time(BuildContext c, String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '';
    return DateFormat.jm(_loc(c)).format(dt);
  }

  /// Mois court en MAJUSCULES pour les badges. Ex. « JAN » / « JANV. ».
  static String monthBadge(BuildContext c, String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '';
    return DateFormat.MMM(_loc(c)).format(dt).toUpperCase();
  }

  static DateTime? _parse(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);
}
