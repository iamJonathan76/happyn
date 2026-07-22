import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider central pour la liste de TOUS les events (publics).
/// Home, Discover, et Profile s'abonnent tous à ce même provider.
/// Quand un event est créé/supprimé, on appelle `ref.invalidate(eventsProvider)`
/// et les 3 écrans se rafraîchissent automatiquement, sans GlobalKey ni hack.
final eventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;

  // On ne récupère que les events publics + les siens (pour que l'organisateur
  // voie ses propres events privés sur son profil). Les events privés des
  // AUTRES ne descendent jamais sur l'appareil — ils ne sont accessibles que
  // via leur code d'invitation (RPC unlock_private_event).
  final query = client.from('events').select();
  final filtered = uid == null
      ? query.eq('visibility', 'public')
      : query.or('visibility.eq.public,created_by.eq.$uid');

  final data = await filtered.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

/// Provider dérivé : uniquement les events créés par l'utilisateur connecté.
/// Utilisé par ProfileScreen. Se recalcule automatiquement quand eventsProvider
/// change, pas besoin de requête séparée.
final myEventsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final eventsAsync = ref.watch(eventsProvider);

  return eventsAsync.when(
    data: (events) =>
        events.where((e) => e['created_by'] == user.id).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});