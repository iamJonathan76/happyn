import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/moderation_provider.dart';

/// Nombre de publications chargées par page de fil.
const int _kFeedLimit = 50;

/// Comptes suivis par l'utilisateur connecté.
final followingProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return <String>{};
  final data = await Supabase.instance.client
      .from('follows')
      .select('following_id')
      .eq('follower_id', uid);
  return List<Map<String, dynamic>>.from(data)
      .map((e) => e['following_id'] as String)
      .toSet();
});

/// Fil « Découvrir » : toutes les publications récentes.
///
/// C'est le fil par défaut, et c'est volontaire : au lancement personne ne
/// suit personne, un fil limité aux abonnements serait vide pour chaque
/// nouvel inscrit.
final discoverFeedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('feed_posts')
      .select()
      .order('created_at', ascending: false)
      .limit(_kFeedLimit);
  return _withoutBlocked(ref, data);
});

/// Fil « Abonnements » : publications des comptes suivis (et les siennes).
///
/// ⚠️ Plus branché à aucun écran depuis que l'accueil n'a qu'un seul fil.
/// Conservé le temps de trancher : voir ce que font ses connexions passera
/// probablement par un filtre sur Découvrir portant sur les ÉVÉNEMENTS
/// auxquels elles vont, auquel cas ce provider n'aura plus lieu d'être — un
/// profil public suffit à voir les publications d'une personne.
final followingFeedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final following = await ref.watch(followingProvider.future);
  final authors = {...following, uid}.toList();

  final data = await Supabase.instance.client
      .from('feed_posts')
      .select()
      .inFilter('author_id', authors)
      .order('created_at', ascending: false)
      .limit(_kFeedLimit);
  return _withoutBlocked(ref, data);
});

/// Publications d'un compte donné (profil public).
final userPostsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('feed_posts')
      .select()
      .eq('author_id', userId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

/// Profil public + compteurs d'abonnés/abonnements.
final publicProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final client = Supabase.instance.client;
  // Se recalcule quand on suit/ne suit plus, pour rafraîchir les compteurs.
  ref.watch(followingProvider);

  final profile = await client
      .from('public_profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  if (profile == null) return null;

  final followers = await client
      .from('follows')
      .count(CountOption.exact)
      .eq('following_id', userId);
  final following = await client
      .from('follows')
      .count(CountOption.exact)
      .eq('follower_id', userId);

  return {
    ...Map<String, dynamic>.from(profile),
    'followers_count': followers,
    'following_count': following,
  };
});

/// Retire les publications des comptes bloqués.
Future<List<Map<String, dynamic>>> _withoutBlocked(Ref ref, dynamic data) async {
  final list = List<Map<String, dynamic>>.from(data as List);
  final blocked = await ref.watch(blockedUsersProvider.future);
  if (blocked.isEmpty) return list;
  return list.where((p) => !blocked.contains(p['author_id'])).toList();
}

// ── Actions ─────────────────────────────────────────────────────────────────

Future<void> followUser(String userId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || uid == userId) return;
  await Supabase.instance.client
      .from('follows')
      .upsert({'follower_id': uid, 'following_id': userId});
}

Future<void> unfollowUser(String userId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  await Supabase.instance.client
      .from('follows')
      .delete()
      .eq('follower_id', uid)
      .eq('following_id', userId);
}

Future<void> setPostLiked(String postId, bool liked) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;
  if (liked) {
    await client
        .from('post_likes')
        .upsert({'post_id': postId, 'user_id': uid});
  } else {
    await client
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', uid);
  }
}

/// Événements que l'utilisateur peut légitimement documenter : ceux qu'il
/// organise, et ceux pour lesquels il détient un billet.
///
/// Le composeur s'en sert pour ne proposer QUE ces événements. La même règle
/// est appliquée côté base (`can_attach_event`) : le filtrage ici est du
/// confort, pas une sécurité.
final attachableEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final data =
      await Supabase.instance.client.rpc('my_attachable_events');
  return List<Map<String, dynamic>>.from(data as List);
});

/// Crée une publication. Toujours rattachée à un événement : Happyn documente
/// des expériences, pas des humeurs. [imageUrl] et [caption] ne peuvent pas
/// être vides tous les deux (contrainte en base).
Future<void> createPost({
  required String eventId,
  String? caption,
  String? imageUrl,
}) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  await Supabase.instance.client.from('posts').insert({
    'author_id': uid,
    'event_id': eventId,
    if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
    if (imageUrl != null) 'image_url': imageUrl,
  });
}

Future<void> deletePost(String postId) async {
  await Supabase.instance.client.from('posts').delete().eq('id', postId);
}
