import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adresse précise d'un événement, telle que le serveur accepte de la donner.
///
/// `null` ne veut pas dire « pas d'adresse » : ça veut dire **« pas pour toi »**.
/// La policy de `event_addresses` n'ouvre la ligne qu'à l'organisateur, aux
/// détenteurs d'un billet, et à tout le monde sur un événement public. Un
/// événement privé déverrouillé par code n'y donne pas accès — connaître
/// l'existence d'une soirée et savoir où elle se tient sont deux niveaux
/// différents.
///
/// Le filtrage est en base, pas ici : l'app ne reçoit tout simplement jamais
/// l'adresse qu'elle n'a pas le droit d'afficher.
class EventAddress {
  final String? addressLine;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  const EventAddress({
    this.addressLine,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

final eventAddressProvider =
    FutureProvider.autoDispose.family<EventAddress?, String>((ref, eventId) async {
  final data = await Supabase.instance.client
      .from('event_addresses')
      .select('address_line, postal_code, latitude, longitude')
      .eq('event_id', eventId)
      .maybeSingle();
  if (data == null) return null;
  return EventAddress(
    addressLine: data['address_line'] as String?,
    postalCode: data['postal_code'] as String?,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
  );
});

/// Enregistre l'adresse précise d'un événement.
///
/// Séparé de la création de l'événement : si cette écriture échoue, l'événement
/// existe quand même. Un événement sans coordonnées est récupérable — il
/// n'apparaîtra pas dans « Near You » jusqu'à modification — alors qu'un
/// événement perdu parce que le géocodage a échoué ne l'est pas.
Future<void> saveEventAddress({
  required String eventId,
  required String addressLine,
  required String postalCode,
  required double latitude,
  required double longitude,
  required String placeId,
}) async {
  await Supabase.instance.client.from('event_addresses').upsert({
    'event_id': eventId,
    'address_line': addressLine,
    'postal_code': postalCode,
    'latitude': latitude,
    'longitude': longitude,
    'place_id': placeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
}
