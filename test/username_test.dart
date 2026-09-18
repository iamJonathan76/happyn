import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/providers/people_provider.dart';

/// Ces regles doublent la contrainte `username_format` en base. Si elles
/// divergent, l'app annoncera « disponible » un nom que la base refusera, ou
/// l'inverse — d'ou ces tests.
void main() {
  group('usernameLooksValid', () {
    test('accepte lettres, chiffres, point et tiret bas', () {
      expect(usernameLooksValid('jonathan'), isTrue);
      expect(usernameLooksValid('jon.k_76'), isTrue);
      expect(usernameLooksValid('abc'), isTrue);
      expect(usernameLooksValid('a' * 20), isTrue);
    });

    test('refuse trop court ou trop long', () {
      expect(usernameLooksValid('ab'), isFalse);
      expect(usernameLooksValid('a' * 21), isFalse);
    });

    test('refuse majuscules, espaces, accents et symboles', () {
      expect(usernameLooksValid('Jonathan'), isFalse);
      expect(usernameLooksValid('jon athan'), isFalse);
      expect(usernameLooksValid('jérémy'), isFalse);
      expect(usernameLooksValid('jon-k'), isFalse);
    });

    test('refuse les points qui servent a imiter un autre compte', () {
      expect(usernameLooksValid('.jonathan'), isFalse);
      expect(usernameLooksValid('jonathan.'), isFalse);
      expect(usernameLooksValid('jon..athan'), isFalse);
    });
  });

  group('normalizeUsername', () {
    test('ramene a la forme stockee', () {
      expect(normalizeUsername('  @Jonathan '), 'jonathan');
      expect(normalizeUsername('@@jon'), 'jon');
    });
  });

  group('suggestUsername', () {
    test('tire un identifiant lisible du nom', () {
      expect(suggestUsername('Jérémy Côté'), 'jeremycote');
      expect(suggestUsername("Zoë O'Neil"), 'zoeoneil');
    });

    test('tronque a 15 pour laisser la place a un suffixe', () {
      expect(suggestUsername('Maximilien Alexandre-Beauchamp').length, 15);
    });

    test('reste vide plutot que d\'inventer', () {
      expect(suggestUsername(null), '');
      expect(suggestUsername('   '), '');
    });
  });
}
