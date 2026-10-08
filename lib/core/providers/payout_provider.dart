import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// État de l'inscription Stripe d'un organisateur.
///
/// Quatre situations que l'écran doit distinguer, parce qu'elles n'appellent pas
/// la même action :
///
///   * pas de compte           → proposer de commencer
///   * formulaire commencé     → proposer de le reprendre
///   * compte bloqué           → renvoyer au formulaire (pièce manquante)
///   * `transfersEnabled`      → tout est en place
///
/// `detailsSubmitted` seul ne suffit pas à promettre un versement : la
/// vérification de Stripe peut échouer après l'envoi du formulaire. Seul
/// `transfersEnabled` l'autorise.
class PayoutAccount {
  final bool hasAccount;
  final bool transfersEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final bool blocked;

  const PayoutAccount({
    required this.hasAccount,
    required this.transfersEnabled,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
    required this.blocked,
  });

  static const none = PayoutAccount(
    hasAccount: false,
    transfersEnabled: false,
    payoutsEnabled: false,
    detailsSubmitted: false,
    blocked: false,
  );

  /// Peut vendre des billets payants. C'est le seul état où
  /// `create-payment-intent` acceptera un achat sur ses événements.
  bool get isReady => transfersEnabled && !blocked;

  /// A commencé sans finir : le formulaire n'a pas été envoyé.
  bool get isIncomplete => hasAccount && !detailsSubmitted && !blocked;

  /// Formulaire envoyé, vérification en cours. Rien à faire qu'attendre —
  /// et il faut le dire, sinon la personne recommence le formulaire en boucle.
  bool get isPending => hasAccount && detailsSubmitted && !transfersEnabled && !blocked;

  factory PayoutAccount.fromMap(Map<dynamic, dynamic> m) => PayoutAccount(
        hasAccount: m['has_account'] == true,
        transfersEnabled: m['transfers_enabled'] == true,
        payoutsEnabled: m['payouts_enabled'] == true,
        detailsSubmitted: m['details_submitted'] == true,
        blocked: m['blocked'] == true || m['disabled_reason'] != null,
      );
}

/// Un versement, par événement.
///
/// Les montants sont en CENTS, comme chez Stripe : la conversion en dollars se
/// fait à l'affichage seulement. Passer par des `double` dès la couche de
/// données est le chemin le plus court vers un total qui ne tombe pas juste.
class PayoutLine {
  final String eventId;
  final String eventTitle;
  final DateTime? eventEnd;
  final int grossCents;

  /// Ce qui ne reste pas : remboursements et paiements contestés confondus.
  /// L'organisateur n'a pas à distinguer les deux — dans les deux cas l'argent
  /// n'est plus là.
  final int withheldCents;
  final int stripeFeeCents;
  final int platformFeeCents;
  final int netCents;

  /// `pending` | `paid` | `failed` | `skipped` | `cancelled`
  final String status;
  final DateTime? paidAt;

  /// Date à partir de laquelle le versement peut partir (fin de l'événement +
  /// délai de retenue). Affichée pour éviter la question « où est mon argent ».
  final DateTime? eligibleAt;

  const PayoutLine({
    required this.eventId,
    required this.eventTitle,
    this.eventEnd,
    required this.grossCents,
    required this.withheldCents,
    required this.stripeFeeCents,
    required this.platformFeeCents,
    required this.netCents,
    required this.status,
    this.paidAt,
    this.eligibleAt,
  });

  bool get isPaid => status == 'paid';
  bool get hasFailed => status == 'failed';

  factory PayoutLine.fromMap(Map<String, dynamic> r) => PayoutLine(
        eventId: r['event_id'] as String,
        eventTitle: (r['event_title'] as String?) ?? '',
        eventEnd: _date(r['event_end']),
        grossCents: (r['gross_cents'] as num?)?.toInt() ?? 0,
        withheldCents: (r['refunded_cents'] as num?)?.toInt() ?? 0,
        stripeFeeCents: (r['stripe_fee_cents'] as num?)?.toInt() ?? 0,
        platformFeeCents: (r['platform_fee_cents'] as num?)?.toInt() ?? 0,
        netCents: (r['net_cents'] as num?)?.toInt() ?? 0,
        status: (r['status'] as String?) ?? 'pending',
        paidAt: _date(r['paid_at']),
        eligibleAt: _date(r['eligible_at']),
      );

  static DateTime? _date(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}

/// État d'inscription de l'organisateur connecté.
///
/// Passe par `connect-refresh` plutôt que par la RPC `my_payout_account` :
/// l'information doit venir de Stripe, pas du miroir en base. Quelqu'un qui
/// revient du formulaire veut voir « c'est bon » immédiatement, et le miroir
/// n'est à jour qu'après le rafraîchissement.
///
/// Si l'appel échoue (réseau, Stripe indisponible), on retombe sur la RPC : une
/// information un peu vieille vaut mieux qu'un écran d'erreur, d'autant que
/// toute décision réelle est revérifiée côté serveur.
///
/// `autoDispose` : c'est un état qui change en dehors de l'app (vérification
/// Stripe). Le garder en cache ferait afficher « inscription à terminer » à
/// quelqu'un dont le compte est actif depuis une heure.
final payoutAccountProvider =
    FutureProvider.autoDispose<PayoutAccount>((ref) async {
  final client = Supabase.instance.client;
  try {
    final res = await client.functions.invoke('connect-refresh');
    final data = res.data;
    if (data is Map) return PayoutAccount.fromMap(data);
  } catch (e) {
    debugPrint('connect-refresh indisponible, lecture du miroir : $e');
  }

  final rows = await client.rpc('my_payout_account');
  final list = rows is List ? rows : const [];
  if (list.isEmpty) return PayoutAccount.none;
  return PayoutAccount.fromMap((list.first as Map).cast<String, dynamic>());
});

/// Versements par événement, du plus récent au plus ancien.
final myPayoutsProvider =
    FutureProvider.autoDispose<List<PayoutLine>>((ref) async {
  final data = await Supabase.instance.client.rpc('my_payouts');
  return List<Map<String, dynamic>>.from(data as List)
      .map(PayoutLine.fromMap)
      .toList();
});

/// Résultat d'une demande de lien Stripe.
class ConnectLink {
  final String? url;
  final String? error;
  const ConnectLink({this.url, this.error});
  bool get ok => url != null && url!.isNotEmpty;
}

/// Demande un lien Stripe : formulaire d'inscription, ou tableau de bord.
///
/// Les liens sont à usage unique et expirent en quelques minutes — on les
/// demande au moment du clic, jamais à l'avance.
Future<ConnectLink> requestConnectLink({bool dashboard = false}) async {
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'connect-onboard',
      body: {'mode': dashboard ? 'dashboard' : 'onboarding'},
    );
    final data = res.data;
    if (data is Map && data['url'] is String) {
      return ConnectLink(url: data['url'] as String);
    }
    return ConnectLink(
        error: data is Map ? data['error'] as String? : null);
  } on FunctionException catch (e) {
    final details = e.details;
    return ConnectLink(
        error: details is Map ? details['error'] as String? : null);
  } catch (e) {
    debugPrint('connect-onboard: $e');
    return const ConnectLink();
  }
}

/// L'organisateur peut-il encaisser ? (compte de versement actif)
///
/// Sert seulement a l'affichage : dire « Billets bientot en vente » au lieu de
/// laisser l'acheteur buter sur une erreur au paiement. La vraie barriere est
/// cote serveur — `create-payment-intent` refuse toute vente payante tant que
/// le compte n'est pas actif. En cas de doute (reseau), on n'empeche donc
/// rien ici : le serveur tranchera.
final organizerPayableProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, organizerId) async {
  try {
    final res = await Supabase.instance.client
        .rpc('organizer_is_payable', params: {'p_organizer': organizerId});
    return res == true;
  } catch (e) {
    debugPrint('organizer_is_payable indisponible : $e');
    return true;
  }
});

/// Mes propres versements sont-ils prets ? Pour l'organisateur qui cree ou
/// publie un evenement payant. En cas de doute, non : mieux vaut un brouillon
/// de trop qu'un evenement publie qui ne peut rien vendre.
Future<bool> myPayoutsReady(WidgetRef ref) async {
  try {
    return (await ref.read(payoutAccountProvider.future)).isReady;
  } catch (e) {
    debugPrint('etat des versements indisponible : $e');
    return false;
  }
}
