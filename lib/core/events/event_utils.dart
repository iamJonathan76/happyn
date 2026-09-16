/// Un event est « passé/terminé » quand sa date de fin (ou de début à défaut)
/// est dépassée. Dérivé de la date — pas de statut stocké, pas de cron.
bool isEventPast(Map<String, dynamic> event) {
  final raw = event['end_date'] ?? event['start_date'];
  if (raw == null) return false;
  final dt = DateTime.tryParse(raw as String);
  return dt != null && dt.isBefore(DateTime.now());
}

String eventStatus(Map<String, dynamic> event) =>
    (event['status'] ?? 'published') as String;

bool isEventCancelled(Map<String, dynamic> event) =>
    eventStatus(event) == 'cancelled';

bool isEventPrivate(Map<String, dynamic> event) =>
    (event['visibility'] ?? 'public') == 'private';

/// Visible dans la découverte (Home/Discover) : publié, pas terminé, ET public.
/// Un event privé n'apparaît jamais dans les feeds — seulement via son code.
bool isEventVisible(Map<String, dynamic> event) =>
    eventStatus(event) == 'published' &&
    !isEventPast(event) &&
    !isEventPrivate(event);

/// Trie par date de TENUE croissante — le plus proche d'abord.
///
/// A ne pas confondre avec l'ordre de `eventsProvider`, qui est par date de
/// CREATION : pertinent sur son propre profil (« mes derniers events »), faux
/// sur un bandeau « Bientot », ou un event de decembre publie hier passerait
/// devant celui de samedi.
List<Map<String, dynamic>> sortedByStart(List<Map<String, dynamic>> events) {
  final list = [...events];
  list.sort((a, b) {
    final da = DateTime.tryParse((a['start_date'] ?? '') as String);
    final db = DateTime.tryParse((b['start_date'] ?? '') as String);
    // Sans date on ne peut rien promettre : ces events finissent en queue.
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return list;
}
