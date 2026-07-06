import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Émet à chaque changement d'auth (login, logout, et surtout `userUpdated`
/// après un `updateUser`). Les écrans qui affichent le nom/la photo le
/// surveillent pour se rafraîchir automatiquement, même montés en IndexedStack.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
