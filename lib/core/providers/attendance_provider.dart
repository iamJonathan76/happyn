import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';

/// Présence de l'utilisateur sur un événement : `going` ou `attended`, plus le
/// drapeau de visibilité.
///
/// La ligne est créée automatiquement par un trigger à l'émission d'un billet —
/// l'app ne l'écrit jamais directement.
final myAttendanceProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, eventId) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final data = await Supabase.instance.client
      .from('event_attendance')
      .select()
      .eq('user_id', uid)
      .eq('event_id', eventId)
      .maybeSingle();
  return data == null ? null : Map<String, dynamic>.from(data);
});

/// Active ou coupe la visibilité de sa présence sur UN événement.
///
/// ⚠️ Visibilité, pas diffusion : ça autorise ses connexions mutuelles à voir
/// cette présence quand elles consultent l'événement. Ça ne publie rien, ne
/// notifie personne et n'alimente aucun fil.
///
/// Passe par une RPC : un UPDATE direct laisserait le client modifier aussi son
/// statut et se déclarer « attended » sans être venu.
Future<void> setAttendanceVisibility(String eventId, bool visible) async {
  await Supabase.instance.client.rpc(
    'set_attendance_visibility',
    params: {'p_event': eventId, 'p_visible': visible},
  );
}

/// Identifiants des événements où au moins une connexion mutuelle va.
///
/// Alimente le filtre « Mes connexions » de Découvrir. Ne renvoie que des
/// identifiants : l'écran les croise avec les événements qu'il a déjà le droit
/// de lire, donc un événement privé inaccessible ne peut pas apparaître.
final connectionEventIdsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return <String>{};
  final data =
      await Supabase.instance.client.rpc('events_from_connections');
  return List<dynamic>.from(data as List).map((e) => e as String).toSet();
});

/// Connexions mutuelles ayant rendu leur présence visible sur cet événement.
///
/// Passe par une fonction SECURITY DEFINER : `event_attendance` n'est jamais
/// lisible directement, et `tickets` n'est jamais consultée — détenir un billet
/// n'est pas une déclaration publique de présence.
final whoIsGoingProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, eventId) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  // Se recalcule quand on suit quelqu'un ou qu'on change sa propre visibilité.
  ref.watch(myAttendanceProvider(eventId));
  final data = await Supabase.instance.client
      .rpc('who_is_going', params: {'p_event': eventId});
  return List<Map<String, dynamic>>.from(data as List);
});
