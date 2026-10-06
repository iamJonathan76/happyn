import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final directConversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final data = await Supabase.instance.client.rpc(
        'my_direct_conversations',
      );
      return List<Map<String, dynamic>>.from(data as List);
    });

final directMessagesProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, conversationId) {
      return Supabase.instance.client
          .from('direct_messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          // `ascending: true` EXPLICITEMENT : dans le client Dart, `order()`
          // trie par defaut en DESCENDANT — l'inverse du client JavaScript.
          // Sans ce parametre, les nouveaux messages apparaissaient en haut.
          .order('created_at', ascending: true)
          .map((rows) => List<Map<String, dynamic>>.from(rows));
    });

Future<String> startDirectConversation(String recipientId) async {
  final result = await Supabase.instance.client.rpc(
    'start_direct_conversation',
    params: {'p_recipient': recipientId},
  );
  return result as String;
}

Future<void> sendDirectMessage(String conversationId, String body) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('not_authenticated');

  await client.from('direct_messages').insert({
    'conversation_id': conversationId,
    'sender_id': userId,
    'body': body.trim(),
  });
}

/// Faux quand l'un des deux membres a supprimé son compte.
///
/// La conversation reste lisible par celui qui reste — ce qu'on lui a écrit
/// lui appartient aussi — mais on ne peut plus y répondre : la base refuse
/// l'envoi (migration 20261006000000). Lu depuis la conversation elle-même
/// plutôt que passé par l'écran appelant : le fil s'ouvre depuis la liste, un
/// profil et une notification, et aucun des trois ne doit pouvoir l'oublier.
final directConversationOpenProvider = FutureProvider.family
    .autoDispose<bool, String>((ref, conversationId) async {
      final row = await Supabase.instance.client
          .from('direct_conversations')
          .select('member_a, member_b')
          .eq('id', conversationId)
          .maybeSingle();
      return row != null && row['member_a'] != null && row['member_b'] != null;
    });
