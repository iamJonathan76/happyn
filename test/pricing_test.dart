import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/payments/pricing.dart';

/// Ces calculs décident de ce qu'un organisateur touche vraiment. S'ils
/// dérivaient de `event_ledger` en base, l'app promettrait un montant que le
/// versement ne tiendrait pas — et ça, c'est un litige, pas un bug d'affichage.
void main() {
  const bps = 500; // 5 %, la commission actuelle

  group('displayFromNet', () {
    // 20,30 / 0,921 = 22,0412 — arrondi au cent SUPERIEUR, jamais inferieur.
    test('20 \$ demandés donnent 22,05 \$ affichés', () {
      expect(Pricing.displayFromNet(20, platformFeeBps: bps), 22.05);
    });

    test('un billet gratuit reste gratuit', () {
      expect(Pricing.displayFromNet(0, platformFeeBps: bps), 0);
      expect(Pricing.displayFromNet(-5, platformFeeBps: bps), 0);
    });

    test("l'organisateur touche au moins ce qu'il a demandé", () {
      for (final net in [1.0, 4.99, 12.5, 20.0, 37.77, 199.0]) {
        final display = Pricing.displayFromNet(net, platformFeeBps: bps);
        final back = Pricing.netFromDisplay(display, platformFeeBps: bps);
        expect(back, greaterThanOrEqualTo(net),
            reason: 'net demandé $net, obtenu $back');
        // Et jamais beaucoup plus : l'arrondi au cent supérieur, pas davantage.
        expect(back - net, lessThan(0.02));
      }
    });
  });

  group('netFromDisplay', () {
    test('reproduit le calcul de la base : brut − Stripe − commission', () {
      // 22,04 − (22,04 × 2,9 % + 0,30) − (22,04 × 5 %)
      //   = 22,04 − 0,94 − 1,10 = 20,00
      expect(Pricing.netFromDisplay(22.04, platformFeeBps: bps), 20.0);
    });

    test('les trois parts se rejoignent au centime près', () {
      const display = 33.26;
      final net = Pricing.netFromDisplay(display, platformFeeBps: bps);
      final stripe = Pricing.stripeFee(display);
      final platform = Pricing.platformFee(display, platformFeeBps: bps);
      expect((net + stripe + platform - display).abs(), lessThan(0.02));
    });

    test('un prix trop petit ne couvre pas les frais fixes', () {
      expect(Pricing.netFromDisplay(0.25, platformFeeBps: bps), lessThan(0));
    });
  });

  group('minimumViableDisplay', () {
    test('sous ce prix, il ne reste rien', () {
      final floor = Pricing.minimumViableDisplay(platformFeeBps: bps);
      expect(Pricing.netFromDisplay(floor, platformFeeBps: bps),
          greaterThanOrEqualTo(0));
      expect(Pricing.netFromDisplay(floor - 0.01, platformFeeBps: bps),
          lessThan(0));
    });
  });

  group('roundUpTo', () {
    test('arrondit vers le haut, jamais vers le bas', () {
      expect(Pricing.roundUpTo(22.04, 0.25), 22.25);
      expect(Pricing.roundUpTo(22.04, 1.0), 23.0);
      expect(Pricing.roundUpTo(22.00, 0.25), 22.0); // déjà rond : inchangé
    });
  });

  group('money', () {
    test('français canadien : symbole après, virgule décimale', () {
      expect(Pricing.money(22.04, 'fr'), '22,04 \$');
      expect(Pricing.money(1240, 'fr'), '1 240,00 \$');
    });

    test('anglais : symbole avant', () {
      expect(Pricing.money(22.04, 'en'), r'$22.04');
      expect(Pricing.money(1240, 'en'), r'$1,240.00');
    });
  });

  group('commission absurde', () {
    test("ne renvoie pas l'infini", () {
      expect(Pricing.displayFromNet(20, platformFeeBps: 9800), 0);
      expect(Pricing.minimumViableDisplay(platformFeeBps: 9800), 0);
    });
  });
}
