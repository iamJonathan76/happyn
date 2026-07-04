import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/events_provider.dart';

/// Ensemble des event_id mis en favori par l'utilisateur connecté.
final favoritesProvider = FutureProvider<Set<String>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return <String>{};
  final data = await Supabase.instance.client
      .from('favorites')
      .select('event_id')
      .eq('user_id', user.id);
  return List<Map<String, dynamic>>.from(data)
      .map((e) => e['event_id'] as String)
      .toSet();
});

/// Liste des events favoris (dérivée de eventsProvider + favoritesProvider).
/// Utilisée par l'onglet Favoris du profil.
final favoriteEventsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final favIds = ref.watch(favoritesProvider).asData?.value ?? <String>{};
  final events = ref.watch(eventsProvider).asData?.value ?? const [];
  return events.where((e) => favIds.contains(e['id'])).toList();
});

/// Ajoute/retire un event des favoris. Le widget invalide `favoritesProvider`
/// après pour rafraîchir l'état des cœurs partout.
Future<void> toggleFavorite(String eventId, bool isCurrentlyFav) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  if (isCurrentlyFav) {
    await client
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('event_id', eventId);
  } else {
    await client
        .from('favorites')
        .insert({'user_id': user.id, 'event_id': eventId});
  }
}
