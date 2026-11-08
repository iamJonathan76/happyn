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

  /// Date et heure locales pour les messages. Les horodatages Supabase sont
  /// stockés en UTC ; les convertir avant affichage évite une heure erronée.
  static String messageDateTime(BuildContext c, String? iso) {
    final parsed = _parse(iso);
    if (parsed == null) return '';
    final dt = parsed.toLocal();
    final locale = _loc(c);
    return '${DateFormat.yMMMd(locale).format(dt)} · ${DateFormat.jm(locale).format(dt)}';
  }

  /// Mois court en MAJUSCULES pour les badges. Ex. « JAN » / « JANV. ».
  static String monthBadge(BuildContext c, String? iso) {
    final dt = _parse(iso);
    if (dt == null) return '';
    return DateFormat.MMM(_loc(c)).format(dt).toUpperCase();
  }

  /// Horodatage compact pour une liste de conversations : l'heure si c'est
  /// aujourd'hui, sinon la date courte (« Mar 14 » / « 14 mars »). Évite
  /// d'écraser le nom quand les deux partagent une ligne.
  static String messageListTime(BuildContext c, String? iso) {
    final dt = _parse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final loc = _loc(c);
    return sameDay
        ? DateFormat.jm(loc).format(dt)
        : DateFormat.MMMd(loc).format(dt);
  }

  /// Séparateur de jour dans un fil : « Fri, Mar 14 » / « ven. 14 mars ».
  static String daySeparator(BuildContext c, String? iso) {
    final dt = _parse(iso)?.toLocal();
    if (dt == null) return '';
    return DateFormat.MMMEd(_loc(c)).format(dt);
  }

  /// Vrai quand deux instants ISO tombent un jour civil différent (heure
  /// locale) : sert à n'insérer un séparateur de date qu'au changement de jour.
  static bool differentDay(String? isoA, String? isoB) {
    final a = _parse(isoA)?.toLocal();
    final b = _parse(isoB)?.toLocal();
    if (a == null || b == null) return a != b;
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  static DateTime? _parse(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);
}
