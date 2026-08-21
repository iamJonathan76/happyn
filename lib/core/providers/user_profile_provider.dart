import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';

/// Ligne `profiles` de l'utilisateur connecté (city, bio, interests, avatar_url…).
/// À invalider après une modification du profil pour rafraîchir l'affichage.
final userProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('id', uid)
      .maybeSingle();
});
