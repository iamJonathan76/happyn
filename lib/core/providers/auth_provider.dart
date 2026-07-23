import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Émet à chaque changement d'auth (login, logout, et surtout `userUpdated`
/// après un `updateUser`). Les écrans qui affichent le nom/la photo le
/// surveillent pour se rafraîchir automatiquement, même montés en IndexedStack.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Id de l'utilisateur connecté, recalculé à chaque changement d'auth.
/// Les providers « user-scoped » (profil, tickets, favoris, notifs, events)
/// le surveillent : quand on change de compte (ou qu'on se déconnecte), sa
/// valeur change et tous les caches dépendants sont recalculés automatiquement
/// — plus de données de l'ancien compte affichées après un switch.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider); // se recalcule à chaque login/logout
  return Supabase.instance.client.auth.currentUser?.id;
});
