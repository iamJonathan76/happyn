import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Détenteurs de billets d'un événement, pour son organisateur.
///
/// Une ligne par PERSONNE, pas par billet : qui a pris trois places est un
/// invité qui vient à trois, pas trois inscrits.
///
/// Passe par la RPC `event_attendees` : la table `tickets` n'est lisible que
/// par le détenteur de chaque billet, et on ne veut pas élargir cette policy
/// pour un besoin d'affichage (voir l'en-tête de la migration). La RPC refuse
/// l'appel de quiconque n'est pas `events.created_by`.
///
/// `autoDispose` pour la même raison que le compteur de ventes : une liste de
/// porte figée en cache est pire que pas de liste — on la relit à chaque
/// ouverture de l'écran.
final eventAttendeesProvider = FutureProvider.autoDispose
    .family<List<EventAttendee>, String>((ref, eventId) async {
  final data = await Supabase.instance.client
      .rpc('event_attendees', params: {'p_event': eventId});

  return List<Map<String, dynamic>>.from(data as List)
      .map(EventAttendee.fromRow)
      .toList();
});

/// Un participant et ce qu'il détient sur l'événement.
class EventAttendee {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  /// Billets encore valables, billets scannés inclus.
  final int ticketCount;

  /// Combien de ces billets ont déjà été scannés à l'entrée.
  final int scannedCount;

  const EventAttendee({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.ticketCount,
    required this.scannedCount,
  });

  factory EventAttendee.fromRow(Map<String, dynamic> row) => EventAttendee(
        id: row['id'] as String,
        fullName: (row['full_name'] as String?)?.trim(),
        avatarUrl: row['avatar_url'] as String?,
        ticketCount: (row['ticket_count'] as num?)?.toInt() ?? 0,
        scannedCount: (row['scanned_count'] as num?)?.toInt() ?? 0,
      );

  /// Tout le monde est entré. Sert à distinguer « arrivé » de « en partie
  /// arrivé » : quelqu'un avec 3 billets dont 1 scanné n'est pas au complet,
  /// et l'afficher comme présent tromperait le comptage à la porte.
  bool get allScanned => ticketCount > 0 && scannedCount >= ticketCount;

  bool get partlyScanned => scannedCount > 0 && !allScanned;
}
