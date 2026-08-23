import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/auth_provider.dart';

/// L'utilisateur connecté a-t-il le droit de modérer ?
///
/// Sert uniquement à décider d'afficher ou non l'entrée « Modération ». Ce n'est
/// PAS une protection : chaque fonction de modération revérifie le droit côté
/// base. Un client bidouillé qui forcerait l'écran à s'ouvrir n'obtiendrait
/// qu'une file vide et des erreurs `not_admin`.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return false;
  try {
    final data = await Supabase.instance.client.rpc('i_am_admin');
    return data == true;
  } catch (_) {
    return false;
  }
});

/// File de modération, par statut. `pending` par défaut, le plus ancien
/// d'abord — c'est celui qui approche des 24 h.
///
/// `autoDispose` : une file de modération figée ferait retraiter deux fois le
/// même signalement, ou croire qu'il n'y a plus rien à faire.
final adminReportsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, status) async {
  final data = await Supabase.instance.client
      .rpc('admin_reports', params: {'p_status': status});
  return List<Map<String, dynamic>>.from(data as List);
});

/// Marque un signalement traité. `reviewed` (vu, rien à faire), `actioned`
/// (contenu retiré ou compte suspendu), `dismissed` (non fondé).
Future<void> resolveReport(String reportId, String status,
    {String? note}) async {
  await Supabase.instance.client.rpc('admin_resolve_report', params: {
    'p_report': reportId,
    'p_status': status,
    'p_note': note,
  });
}

/// Retire un contenu signalé.
///
/// Une publication est supprimée ; un événement est seulement dépublié — des
/// gens ont peut-être acheté des billets, et effacer la ligne les priverait de
/// la trace de ce qu'ils ont payé.
Future<void> removeContent(String type, String id,
    {String? reportId, String? note}) async {
  await Supabase.instance.client.rpc('admin_remove_content', params: {
    'p_type': type,
    'p_id': id,
    'p_report': reportId,
    'p_note': note,
  });
}

/// Suspend ou réactive un compte.
///
/// Suspendre ne supprime rien et ne touche pas aux billets déjà achetés : la
/// personne garde ce qu'elle a payé, elle perd la capacité de publier.
Future<void> setUserSuspended(String userId, bool suspended,
    {String? reportId, String? note}) async {
  await Supabase.instance.client.rpc('admin_set_suspended', params: {
    'p_user': userId,
    'p_suspended': suspended,
    'p_report': reportId,
    'p_note': note,
  });
}
