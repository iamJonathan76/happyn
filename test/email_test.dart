import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/utils/email.dart';

/// Ces regles gardent l'ecran de changement d'adresse. L'enjeu n'est pas
/// cosmetique : une adresse mal tapee ne produit aucune erreur visible — le
/// lien de confirmation part vers une boite que personne ne relevera, et
/// l'utilisateur attend un courriel qui n'arrivera jamais. D'ou ces tests sur
/// ce qu'on accepte, ce qu'on refuse, et ce qu'on corrige sans rien demander.
void main() {
  group('normalizeEmail', () {
    test('coupe les espaces et met en minuscules', () {
      expect(normalizeEmail('  Jonathan@Gmail.COM '), 'jonathan@gmail.com');
      expect(normalizeEmail('A@B.CA'), 'a@b.ca');
    });

    test('laisse une adresse deja propre intacte', () {
      expect(normalizeEmail('jon@happynevents.com'), 'jon@happynevents.com');
    });

    test('ne rend pas valide ce qui ne l\'est pas', () {
      // Normaliser n'est pas reparer : « jon@ » reste incomplet.
      expect(normalizeEmail(' jon@ '), 'jon@');
      expect(emailLooksValid(normalizeEmail(' jon@ ')), isFalse);
    });
  });

  group('emailLooksValid', () {
    test('accepte les formes courantes', () {
      expect(emailLooksValid('jon@gmail.com'), isTrue);
      expect(emailLooksValid('jon.k+billets@gmail.com'), isTrue);
      expect(emailLooksValid('jon@mail.happynevents.com'), isTrue);
      expect(emailLooksValid('jon@ottawa.museum'), isTrue);
      expect(emailLooksValid('j@a.ca'), isTrue);
    });

    test('refuse ce qui n\'a pas de domaine utilisable', () {
      expect(emailLooksValid('jon'), isFalse);
      expect(emailLooksValid('jon@'), isFalse);
      expect(emailLooksValid('jon@localhost'), isFalse);
      expect(emailLooksValid('jon@gmail.c'), isFalse);
      expect(emailLooksValid('jon@gmail..com'), isFalse);
      expect(emailLooksValid('@gmail.com'), isFalse);
      expect(emailLooksValid(''), isFalse);
    });

    test('refuse les espaces et les arrobases en trop', () {
      expect(emailLooksValid('jon k@gmail.com'), isFalse);
      expect(emailLooksValid('jon@gmail.com '), isFalse);
      expect(emailLooksValid('jon@@gmail.com'), isFalse);
      expect(emailLooksValid('jon@a@b.com'), isFalse);
    });

    test('attend une valeur normalisee : les majuscules sont refusees', () {
      // Documente le contrat plutot qu'un oubli : l'ecran normalise avant
      // d'appeler. Si cette ligne tombe, c'est que quelqu'un a branche la
      // validation sur la saisie brute, et le champ refusera « Jon@… ».
      expect(emailLooksValid('Jon@gmail.com'), isFalse);
      expect(emailLooksValid(normalizeEmail('Jon@gmail.com')), isTrue);
    });
  });

  group('emailChangeProblem', () {
    String? problem(String current, String next, String confirm) =>
        emailChangeProblem(
          current: current,
          next: next,
          confirm: confirm,
        )?.name;

    test('rien a signaler quand le changement est valide', () {
      expect(
        emailChangeProblem(
          current: 'ancien@gmail.com',
          next: 'nouveau@gmail.com',
          confirm: 'nouveau@gmail.com',
        ),
        isNull,
      );
    });

    test('accepte malgre les majuscules et les espaces des deux cotes', () {
      // Le clavier mobile met une majuscule au premier caractere, et un
      // copier-coller traine un espace. Refuser ici donnerait « les deux
      // adresses ne correspondent pas » sur deux saisies identiques a l'oeil.
      expect(
        emailChangeProblem(
          current: 'ancien@gmail.com',
          next: ' Nouveau@Gmail.com',
          confirm: 'nouveau@gmail.com ',
        ),
        isNull,
      );
    });

    test('signale un champ vide', () {
      expect(problem('a@b.com', '', ''), 'empty');
      expect(problem('a@b.com', '   ', ''), 'empty');
    });

    test('signale une adresse qui n\'en est pas une', () {
      expect(problem('a@b.com', 'nouveau', 'nouveau'), 'malformed');
      expect(problem('a@b.com', 'nouveau@', 'nouveau@'), 'malformed');
    });

    test('signale l\'adresse qu\'on a deja, quelle que soit la casse', () {
      expect(problem('a@b.com', 'a@b.com', 'a@b.com'), 'unchanged');
      expect(problem('a@b.com', 'A@B.com', 'A@B.com'), 'unchanged');
    });

    test('signale une confirmation qui ne suit pas', () {
      expect(problem('a@b.com', 'c@d.com', 'c@e.com'), 'mismatch');
      expect(problem('a@b.com', 'c@d.com', ''), 'mismatch');
    });

    test('la forme est verifiee avant la comparaison', () {
      // Deux fois la meme faute de frappe reste une faute de frappe : dire
      // « ca ne correspond pas » enverrait l'utilisateur chercher une
      // difference entre deux champs identiques.
      expect(problem('a@b.com', 'nouveau', 'nouveau'), 'malformed');
    });
  });
}
