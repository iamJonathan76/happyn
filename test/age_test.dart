import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/utils/age.dart';

/// La barrière d'âge est une obligation légale (Loi 25 : consentement parental
/// requis sous 14 ans au Québec), pas une préférence produit. Un calcul faux
/// d'un jour laisse entrer quelqu'un de trop jeune sans que rien ne le signale.
void main() {
  final now = DateTime.now();

  group('ageFromDob', () {
    test('date inconnue : renvoie null, pas zéro', () {
      // Important : null veut dire « on ne sait pas » (comptes anciens), et
      // doit se distinguer d'un âge réellement nul.
      expect(ageFromDob(null), isNull);
    });

    test('anniversaire aujourd hui : l année compte', () {
      final dob = DateTime(now.year - 20, now.month, now.day);
      expect(ageFromDob(dob), 20);
    });

    test('anniversaire demain : l année ne compte pas encore', () {
      final tomorrow = now.add(const Duration(days: 1));
      final dob = DateTime(now.year - 20, tomorrow.month, tomorrow.day);
      // Sauf si demain tombe l'an prochain — le cas est couvert par le test
      // précédent, on l'écarte ici pour rester déterministe.
      if (tomorrow.year == now.year) {
        expect(ageFromDob(dob), 19);
      }
    });

    test('anniversaire hier : l année compte', () {
      final yesterday = now.subtract(const Duration(days: 1));
      final dob = DateTime(now.year - 20, yesterday.month, yesterday.day);
      if (yesterday.year == now.year) {
        expect(ageFromDob(dob), 20);
      }
    });
  });

  group('seuils', () {
    test('les minimums légaux ne bougent pas par accident', () {
      // Si l'un de ces deux chiffres change, c'est une décision juridique,
      // pas un ajustement d'interface : le test doit forcer à s'en rendre
      // compte.
      expect(kMinAccountAge, 14);
      expect(kMinOrganizerAge, 18);
    });
  });
}
