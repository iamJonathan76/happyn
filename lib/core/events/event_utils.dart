/// Un event est « passé/terminé » quand sa date de fin (ou de début à défaut)
/// est dépassée. Dérivé de la date — pas de statut stocké, pas de cron.
bool isEventPast(Map<String, dynamic> event) {
  final raw = event['end_date'] ?? event['start_date'];
  if (raw == null) return false;
  final dt = DateTime.tryParse(raw as String);
  return dt != null && dt.isBefore(DateTime.now());
}
