import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';

/// Notifications de l'utilisateur connecté (plus récentes d'abord).
final notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final data = await Supabase.instance.client
      .from('notifications')
      .select()
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

/// Nombre de notifications non lues (pour le badge de la cloche).
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).asData?.value ?? const [];
  return list.where((n) => n['read'] == false).length;
});
