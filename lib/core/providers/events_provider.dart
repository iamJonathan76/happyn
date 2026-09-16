import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/events/event_utils.dart';
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


/// Billets vendus sur un événement, tous paliers confondus.
///
/// Un organisateur n'avait nulle part où voir combien de monde vient. Il créait
/// l'événement, les gens achetaient, et il ne l'apprenait qu'en scannant à la
/// porte — trop tard pour commander plus de boissons ou pour annuler faute de
/// monde.
///
/// `quantity_sold` est tenu à jour côté serveur à chaque émission de billet :
/// on ne recompte pas la table `tickets`, qui n'est de toute façon lisible que
/// par le détenteur de chaque billet.
///
/// `total` vaut 0 quand aucune quantité n'est plafonnée — l'affichage doit
/// alors montrer le nombre vendu seul, pas « 12 sur 0 ».
/// `autoDispose` : sans lui la valeur resterait en cache toute la session et
/// l'organisateur verrait un compteur fige, ce qui est pire que pas de
/// compteur du tout. La requete est relancee a chaque ouverture de la fiche.
final eventSalesProvider =
    FutureProvider.autoDispose.family<({int sold, int total}), String>(
        (ref, eventId) async {
  final data = await Supabase.instance.client
      .from('ticket_types')
      .select('quantity_sold, quantity_total')
      .eq('event_id', eventId);

  var sold = 0;
  var total = 0;
  for (final row in List<Map<String, dynamic>>.from(data)) {
    sold += (row['quantity_sold'] as num?)?.toInt() ?? 0;
    total += (row['quantity_total'] as num?)?.toInt() ?? 0;
  }
  return (sold: sold, total: total);
});


/// Les evenements dont JE suis l'organisateur, du plus proche au plus lointain.
///
/// Derive de `eventsProvider` plutot que d'une requete a part : celui-ci
/// remonte deja « les events publics + les miens », brouillons et prives
/// compris. Une seconde requete pourrait le contredire d'une seconde a
/// l'autre, et on paierait deux allers-retours pour la meme donnee.
///
/// L'ordre est celui de la tenue, pas de la creation : ce qu'un organisateur
/// veut voir en haut, c'est l'evenement dont il doit s'occuper cette semaine.
final myOrganizedEventsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(eventsProvider).whenData((events) {
    if (uid == null) return const <Map<String, dynamic>>[];
    return sortedByStart(
        events.where((e) => e['created_by'] == uid).toList());
  });
});
