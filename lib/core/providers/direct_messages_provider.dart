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
