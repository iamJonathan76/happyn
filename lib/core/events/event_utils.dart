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
