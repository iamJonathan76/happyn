import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les commentaires d'une publication, du plus ancien au plus récent, chacun
/// avec le nom et la photo de son auteur.
///
/// Ce que la personne a le droit de voir est décidé en base : la politique
/// retire déjà les commentaires des comptes bloqués, dans les deux sens, et
/// ceux d'une publication qu'elle ne peut pas lire. Ici, rien à filtrer.
///
/// Les auteurs viennent de `public_profiles` en une seconde requête : un
/// commentaire référence `auth.users`, pas `profiles`, et l'API ne sait donc
/// pas les joindre d'elle-même.
final postCommentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, postId) async {
      final client = Supabase.instance.client;
      final rows = List<Map<String, dynamic>>.from(
        await client
            .from('post_comments')
            .select('id, post_id, author_id, body, created_at')
            .eq('post_id', postId)
            .order('created_at', ascending: true)
            .limit(200),
      );
      if (rows.isEmpty) return rows;

      final authorIds = {
        for (final r in rows) r['author_id'] as String,
      }.toList();
      final profiles = List<Map<String, dynamic>>.from(
        await client
            .from('public_profiles')
            .select('id, full_name, username, avatar_url')
            .inFilter('id', authorIds),
      );
      final byId = {for (final p in profiles) p['id'] as String: p};

      return [
        for (final r in rows) {...r, 'author': byId[r['author_id']]},
      ];
    });

Future<void> addComment(String postId, String body) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('not_authenticated');
  await client.from('post_comments').insert({
    'post_id': postId,
    'author_id': userId,
    'body': body.trim(),
  });
}

/// Le sien, ou n'importe lequel sous sa propre publication — la base vérifie.
Future<void> deleteComment(String commentId) async {
  await Supabase.instance.client
      .from('post_comments')
      .delete()
      .eq('id', commentId);
}

/// Seul l'auteur de la publication peut fermer ou rouvrir ses commentaires :
/// la politique de mise à jour des publications ne laisse passer que lui.
Future<void> setCommentsDisabled(String postId, bool disabled) async {
  await Supabase.instance.client
      .from('posts')
      .update({'comments_disabled': disabled})
      .eq('id', postId);
}
