import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final directConversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await client
      .from('direct_conversations')
      .select()
      .or('user_a.eq.$userId,user_b.eq.$userId')
      .order('last_message_at', ascending: false)
      .limit(50);
  final conversations = List<Map<String, dynamic>>.from(rows);
  if (conversations.isEmpty) return [];

  final otherIds = conversations
      .map((row) => row['user_a'] == userId ? row['user_b'] : row['user_a'])
      .cast<String>()
      .toSet()
      .toList();
  final profiles = await client
      .from('public_profiles')
      .select('id, full_name, avatar_url')
      .inFilter('id', otherIds);
  final profileById = {
    for (final profile in List<Map<String, dynamic>>.from(profiles))
      profile['id'] as String: profile,
  };
  final conversationIds = conversations
      .map((row) => row['id'] as String)
      .toList();
  final messageRows = await client
      .from('direct_messages')
      .select('conversation_id, body, created_at')
      .inFilter('conversation_id', conversationIds)
      .order('created_at', ascending: false);
  final latestMessages = <String, Map<String, dynamic>>{};
  for (final message in List<Map<String, dynamic>>.from(messageRows)) {
    latestMessages.putIfAbsent(
        message['conversation_id'] as String, () => message);
  }

  return conversations.map((conversation) {
    final otherId = conversation['user_a'] == userId
        ? conversation['user_b'] as String
        : conversation['user_a'] as String;
    return {
      ...conversation,
      'other_user_id': otherId,
      'other_user': profileById[otherId] ?? const <String, dynamic>{},
      'last_message': latestMessages[conversation['id']],
    };
  }).toList();
});

final directMessagesProvider = StreamProvider.family
    <List<Map<String, dynamic>>, String>((ref, conversationId) {
  return Supabase.instance.client
      .from('direct_messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map(List<Map<String, dynamic>>.from);
});

Future<String> startDirectConversation(String userId) async {
  final result = await Supabase.instance.client.rpc(
    'start_direct_conversation',
    params: {'p_user_id': userId},
  );
  return result as String;
}

Future<void> sendDirectMessage(String conversationId, String body) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw const AuthException('Not authenticated');

  await client.from('direct_messages').insert({
    'conversation_id': conversationId,
    'sender_id': userId,
    'body': body.trim(),
  });
}