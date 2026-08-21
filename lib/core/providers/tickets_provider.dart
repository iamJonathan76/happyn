import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';

/// Billets de l'utilisateur connecté (avec event + ticket_type joints).
/// Invalidé après un achat pour que « My Tickets » se rafraîchisse tout seul.
final myTicketsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final data = await Supabase.instance.client
      .from('tickets')
      .select('*, events(*), ticket_types(*)')
      .eq('user_id', uid)
      .order('purchased_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});
