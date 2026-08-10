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
