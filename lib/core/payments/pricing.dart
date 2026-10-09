import 'dart:math' as math;

/// Le prix affiché à l'acheteur, et ce qu'il en reste à l'organisateur.
///
/// Deux nombres pour un seul billet : ce que l'acheteur paie, et ce que
/// l'organisateur touche. L'écart n'est pas un détail comptable — c'est
/// environ 10 % du prix. Le montrer AVANT la publication évite la seule
/// mauvaise surprise qui compte vraiment : « j'ai vendu à 20 $ et j'ai
/// reçu 18 ».
///
/// Ces fonctions ne décident de rien : elles reproduisent ce que la base
/// calculera vraiment (`event_ledger`), soit
/// `net = brut − frais Stripe − commission`. La commission s'applique au
/// brut, comme en SQL.
///
/// ⚠️ Le résultat est une ESTIMATION, et l'interface doit le dire. Les frais
/// réels dépendent de la carte utilisée : une carte étrangère coûte plus cher
/// (~3,5 % au lieu de 2,9 %). Le chiffre exact n'existe qu'après la vente, et
/// c'est celui de l'écran Versements.
class Pricing {
  /// Tarif Stripe au Canada pour une carte canadienne.
  /// https://stripe.com/en-ca/pricing
  static const double stripePercent = 0.029;
  static const double stripeFixed = 0.30;

  /// Repli si la base n'a pas pu être interrogée. La source de vérité est
  /// `public.platform_fee_bps()` : ce nombre n'est qu'un dernier recours,
  /// jamais une seconde définition.
  static const int defaultPlatformFeeBps = 500;

  /// Prix à afficher pour que l'organisateur touche [net].
  ///
  /// On résout `net = P − (P × 2,9 % + 0,30) − P × commission` :
  ///
  ///     P = (net + 0,30) / (1 − 0,029 − commission)
  ///
  /// Arrondi au cent SUPÉRIEUR : l'organisateur doit toucher au moins ce
  /// qu'il a demandé, jamais un cent de moins.
  static double displayFromNet(double net, {required int platformFeeBps}) {
    if (net <= 0) return 0;
    final rate = 1 - stripePercent - platformFeeBps / 10000;
    // Une commission absurde (≥ 97 %) rendrait l'équation insoluble : on ne
    // renvoie pas l'infini, on renvoie 0 et l'écran n'affiche rien.
    if (rate <= 0) return 0;
    return _ceilCents((net + stripeFixed) / rate);
  }

  /// Ce que l'organisateur touchera si l'acheteur paie [display].
  /// Peut être négatif sur un prix minuscule : 0,25 $ ne couvre même pas les
  /// 0,30 $ fixes de Stripe. L'interface doit alors refuser le prix plutôt
  /// que d'afficher un négatif.
  static double netFromDisplay(double display, {required int platformFeeBps}) {
    if (display <= 0) return 0;
    final kept = display * (1 - stripePercent - platformFeeBps / 10000);
    return _roundCents(kept - stripeFixed);
  }

  /// La part de Stripe sur un prix affiché.
  static double stripeFee(double display) =>
      display <= 0 ? 0 : _roundCents(display * stripePercent + stripeFixed);

  /// La part de HAPPYN sur un prix affiché.
  static double platformFee(double display, {required int platformFeeBps}) =>
      display <= 0 ? 0 : _roundCents(display * platformFeeBps / 10000);

  /// Le prix plancher en dessous duquel l'organisateur toucherait zéro ou
  /// moins. Sert à refuser un prix, pas à en imposer un.
  static double minimumViableDisplay({required int platformFeeBps}) {
    final rate = 1 - stripePercent - platformFeeBps / 10000;
    if (rate <= 0) return 0;
    return _ceilCents(stripeFixed / rate);
  }

  /// Arrondi « joli » vers le HAUT, au pas demandé (0,25 $, 0,50 $, 1 $…).
  /// Vers le haut seulement : arrondir vers le bas ferait toucher à
  /// l'organisateur moins que ce qu'il avait demandé.
  static double roundUpTo(double value, double step) {
    if (value <= 0 || step <= 0) return value;
    return _roundCents((value / step).ceil() * step);
  }

  static double _ceilCents(double v) => (v * 100).ceil() / 100;
  static double _roundCents(double v) => (v * 100).round() / 100;

  /// Formatage monétaire minimal, dans la langue affichée.
  /// En français canadien le symbole suit le montant, séparé par une espace
  /// insécable : « 22,04 $ », jamais « $22.04 ».
  static String money(double amount, String languageCode) {
    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    if (languageCode == 'fr') {
      final parts = fixed.split('.');
      final units = _groupThousands(parts[0], ' ');
      return '${negative ? '−' : ''}$units,${parts[1]} \$';
    }
    final parts = fixed.split('.');
    final units = _groupThousands(parts[0], ',');
    return '${negative ? '−' : ''}\$$units.${parts[1]}';
  }

  static String _groupThousands(String digits, String separator) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Pas d'arrondi proposés à l'organisateur, du plus fin au plus grossier.
  static const List<double> roundingSteps = [0.25, 0.50, 1.0, 5.0];

  /// Le pas le plus proche au-dessus d'un montant, pour proposer un défaut
  /// sensé : 0,25 $ sur un petit prix, 1 $ au-delà de 20 $.
  static double suggestedStep(double display) =>
      display >= 20 ? 1.0 : (display >= 5 ? 0.50 : 0.25);

  /// Écart en pourcentage entre deux montants — sert à dire « +0,2 % » quand
  /// l'organisateur arrondit.
  static double percentGap(double from, double to) =>
      from <= 0 ? 0 : (to - from) / from * 100;

  static double clampPositive(double v) => math.max(0, v);

  /// Frais de service non remboursables quand l'acheteur annule, en cents.
  ///
  /// Reproduit `public.cancellation_fee_cents()` avec les chiffres qu'elle
  /// expose (`cancellation_fee_terms()`), pour annoncer le montant AVANT
  /// l'achat. Le remboursement, lui, est calculé par la base : si les deux
  /// divergeaient, l'app promettrait un montant que Stripe ne rendrait pas.
  /// Même arrondi qu'en SQL (au plus proche, la moitié vers le haut), plafonné
  /// au prix.
  static int cancellationFeeCents(int priceCents, CancellationFeeTerms t) {
    if (priceCents <= 0) return 0;
    final fee = (priceCents * t.bps / 10000).round() + t.fixedCents;
    return math.min(priceCents, fee);
  }
}

/// Les deux chiffres des frais d'annulation, lus en base.
class CancellationFeeTerms {
  final int bps;
  final int fixedCents;
  const CancellationFeeTerms(this.bps, this.fixedCents);

  /// Repli hors ligne. La source de vérité reste la base.
  static const fallback = CancellationFeeTerms(290, 30);
}
