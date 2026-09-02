import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce que la base répond quand on lui demande si un billet peut être annulé.
class CancelCheck {
  final bool allowed;
  final String reason;
  final DateTime? deadline;
  final double amount;

  const CancelCheck({
    required this.allowed,
    required this.reason,
    this.deadline,
    this.amount = 0,
  });

  bool get isPaid => amount > 0;

  static const CancelCheck none =
      CancelCheck(allowed: false, reason: 'unknown');
}

/// Peut-on annuler ce billet, et jusqu'à quand ?
///
/// Sert uniquement à l'affichage : montrer un bouton qui échouera est pire que
/// ne rien montrer. La décision réelle est reprise côté serveur au moment de
/// l'annulation — cette réponse peut avoir vieilli, et la fenêtre se referme
/// toute seule avec le temps.
///
/// `autoDispose` pour cette raison : une réponse mise en cache dirait encore
/// « annulation possible » une heure après la date limite.
final cancelCheckProvider =
    FutureProvider.autoDispose.family<CancelCheck, String>((ref, ticketId) async {
  final data = await Supabase.instance.client
      .rpc('can_cancel_ticket', params: {'p_ticket': ticketId});
  final rows = List<Map<String, dynamic>>.from(data as List);
  if (rows.isEmpty) return CancelCheck.none;
  final row = rows.first;
  return CancelCheck(
    allowed: row['allowed'] == true,
    reason: (row['reason'] as String?) ?? 'unknown',
    deadline: row['deadline'] == null
        ? null
        : DateTime.tryParse(row['deadline'] as String),
    amount: (row['amount'] as num?)?.toDouble() ?? 0,
  );
});

/// Résultat d'une annulation, tel que l'app doit le raconter à l'utilisateur.
class CancelResult {
  final bool ok;

  /// Code d'erreur du serveur, pour choisir le bon message.
  final String? error;

  /// Vrai si de l'argent a réellement été rendu — un billet gratuit s'annule
  /// sans remboursement, et promettre un virement qui n'arrivera jamais serait
  /// pire que de ne rien dire.
  final bool refunded;

  const CancelResult(this.ok, {this.error, this.refunded = false});
}

/// Annule un billet.
///
/// Passe par la fonction Edge et non par une RPC : le remboursement exige la
/// clé secrète Stripe, et l'ordre compte — on rembourse d'abord, on annule
/// ensuite. L'inverse laisserait quelqu'un sans place et sans argent.
Future<CancelResult> cancelTicket(String ticketId) async {
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'cancel-ticket',
      body: {'ticket_id': ticketId},
    );
    final data = res.data;
    if (data is Map && data['ok'] == true) {
      return CancelResult(true, refunded: data['refunded'] == true);
    }
    final error = data is Map ? data['error'] as String? : null;
    return CancelResult(false, error: error);
  } on FunctionException catch (e) {
    final details = e.details;
    final error = details is Map ? details['error'] as String? : null;
    return CancelResult(false, error: error);
  } catch (_) {
    return const CancelResult(false);
  }
}
