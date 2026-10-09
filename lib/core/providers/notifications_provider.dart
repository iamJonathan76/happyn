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
      // Les messages ont leur propre entrée (l'icône messages de l'accueil,
      // avec sa pastille) : dans la cloche, ils noyaient le reste. La
      // notification poussée sur le téléphone, elle, part toujours.
      .neq('type', 'direct_message')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

/// Nombre de conversations avec un message non lu (pastille de l'icône
/// messages).
///
/// La base garde une seule notification `direct_message` NON LUE par
/// conversation (la nouvelle remplace l'ancienne) : les compter, c'est compter
/// les conversations en attente, sans table de suivi de lecture de plus.
final unreadMessagesProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  final data = await Supabase.instance.client
      .from('notifications')
      .select('id')
      .eq('user_id', uid)
      .eq('type', 'direct_message')
      .eq('read', false);
  return (data as List).length;
});

/// Ouvrir une conversation la marque comme lue : sa pastille disparaît.
Future<void> markConversationRead(WidgetRef ref, String conversationId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    await Supabase.instance.client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', uid)
        .eq('type', 'direct_message')
        .eq('conversation_id', conversationId)
        .eq('read', false);
  } catch (_) {
    // Une pastille qui reste un peu trop longtemps ne vaut pas une erreur.
  }
  ref.invalidate(unreadMessagesProvider);
}

/// Supprime une notification, ou toutes celles de la cloche si [id] est nul.
///
/// « Toutes » épargne les messages : ils ne s'affichent pas dans la cloche,
/// et les effacer ferait disparaître sans prévenir la pastille de l'icône
/// messages.
Future<void> deleteNotifications(WidgetRef ref, {String? id}) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  var query = Supabase.instance.client
      .from('notifications')
      .delete()
      .eq('user_id', uid);
  query = id != null ? query.eq('id', id) : query.neq('type', 'direct_message');
  await query;
  ref.invalidate(notificationsProvider);
}

/// Nombre de notifications non lues (pour le badge de la cloche).
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).asData?.value ?? const [];
  return list.where((n) => n['read'] == false).length;
});
