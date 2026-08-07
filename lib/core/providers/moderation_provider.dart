import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';

/// Comptes bloqués par l'utilisateur connecté.
/// Les événements de ces comptes sont retirés de la découverte
/// (voir `eventsProvider`).
final blockedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return <String>{};
  final data = await Supabase.instance.client
      .from('blocked_users')
      .select('blocked_id')
      .eq('blocker_id', uid);
  return List<Map<String, dynamic>>.from(data)
      .map((e) => e['blocked_id'] as String)
      .toSet();
});

/// Bloque un compte. Ses événements disparaissent des fils de l'utilisateur.
Future<void> blockUser(String blockedId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || uid == blockedId) return;
  await Supabase.instance.client.from('blocked_users').upsert({
    'blocker_id': uid,
    'blocked_id': blockedId,
  });
}

Future<void> unblockUser(String blockedId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  await Supabase.instance.client
      .from('blocked_users')
      .delete()
      .eq('blocker_id', uid)
      .eq('blocked_id', blockedId);
}

/// Motifs de signalement. Les clés sont stockées en base (stables, non
/// traduites) ; l'affichage est localisé côté app.
const List<String> kReportReasons = [
  'spam',
  'inappropriate',
  'scam',
  'misleading',
  'other',
];

/// Enregistre un signalement (événement ou utilisateur).
Future<void> submitReport({
  required String targetType, // 'event' | 'user'
  required String targetId,
  required String reason,
  String? details,
}) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  await Supabase.instance.client.from('reports').insert({
    'reporter_id': uid,
    'target_type': targetType,
    'target_id': targetId,
    'reason': reason,
    if (details != null && details.trim().isNotEmpty)
      'details': details.trim(),
  });
}
