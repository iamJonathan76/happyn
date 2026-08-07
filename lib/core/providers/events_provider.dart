import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/moderation_provider.dart';

/// Provider central pour la liste de TOUS les events (publics).
/// Home, Discover, et Profile s'abonnent tous à ce même provider.
/// Quand un event est créé/supprimé, on appelle `ref.invalidate(eventsProvider)`
/// et les 3 écrans se rafraîchissent automatiquement, sans GlobalKey ni hack.
final eventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final uid = ref.watch(currentUserIdProvider);

  // On ne récupère que les events publics + les siens (pour que l'organisateur
  // voie ses propres events privés sur son profil). Les events privés des
  // AUTRES ne descendent jamais sur l'appareil — ils ne sont accessibles que
  // via leur code d'invitation (RPC unlock_private_event).
  final query = client.from('events').select();
  final filtered = uid == null
      ? query.eq('visibility', 'public')
      : query.or('visibility.eq.public,created_by.eq.$uid');

  final data = await filtered.order('created_at', ascending: false);
  final list = List<Map<String, dynamic>>.from(data);

  // Les événements des comptes bloqués disparaissent des fils.
  final blocked = await ref.watch(blockedUsersProvider.future);
  if (blocked.isEmpty) return list;
  return list.where((e) => !blocked.contains(e['created_by'])).toList();
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
    // Ne pas avaler l'erreur en silence : une liste vide et un échec de
    // requête se ressemblent à l'écran, et ça masque les vrais problèmes
    // (une policy RLS cassée s'affichait comme « aucun événement »).
    error: (e, _) {
      debugPrint('myEventsProvider error: $e');
      return const [];
    },
  );
});