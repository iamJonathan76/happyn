import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/providers/attendees_provider.dart';

/// Ces règles décident de ce que l'organisateur lit à sa porte. Se tromper ici
/// ne fait rien planter : ça affiche « arrivé » devant quelqu'un qui n'est pas
/// entré, ou l'inverse — et c'est sur cet affichage qu'on laisse entrer.
void main() {
  EventAttendee attendee({
    String? fullName = 'Marie',
    String? avatarUrl,
    int tickets = 1,
    int scanned = 0,
  }) =>
      EventAttendee(
        id: 'u1',
        fullName: fullName,
        avatarUrl: avatarUrl,
        ticketCount: tickets,
        scannedCount: scanned,
      );

  group('état d\'arrivée', () {
    test('personne n\'est entré : ni complet, ni partiel', () {
      final a = attendee(tickets: 3, scanned: 0);
      expect(a.allScanned, isFalse);
      expect(a.partlyScanned, isFalse);
    });

    test('une partie du groupe est entrée : partiel, pas complet', () {
      final a = attendee(tickets: 3, scanned: 1);
      expect(a.allScanned, isFalse);
      expect(a.partlyScanned, isTrue);
    });

    test('tout le groupe est entré : complet, pas partiel', () {
      final a = attendee(tickets: 3, scanned: 3);
      expect(a.allScanned, isTrue);
      expect(a.partlyScanned, isFalse);
    });

    test('billet unique scanné : complet', () {
      final a = attendee(tickets: 1, scanned: 1);
      expect(a.allScanned, isTrue);
      expect(a.partlyScanned, isFalse);
    });

    // Ne devrait pas arriver, mais un décompte incohérent ne doit pas afficher
    // « en partie arrivé » pour quelqu'un dont tout le monde est entré.
    test('plus de scans que de billets reste complet', () {
      final a = attendee(tickets: 2, scanned: 3);
      expect(a.allScanned, isTrue);
      expect(a.partlyScanned, isFalse);
    });

    test('aucun billet ne se déclare pas complet', () {
      final a = attendee(tickets: 0, scanned: 0);
      expect(a.allScanned, isFalse);
      expect(a.partlyScanned, isFalse);
    });
  });

  group('lecture de la ligne renvoyée par la RPC', () {
    test('les décomptes arrivent en bigint, donc en num', () {
      final a = EventAttendee.fromRow({
        'id': 'u9',
        'full_name': 'Alex',
        'avatar_url': 'https://example.test/a.png',
        'ticket_count': 2,
        'scanned_count': 1,
      });
      expect(a.id, 'u9');
      expect(a.fullName, 'Alex');
      expect(a.ticketCount, 2);
      expect(a.scannedCount, 1);
      expect(a.partlyScanned, isTrue);
    });

    test('profil manquant : pas de nom, mais la personne reste dans la liste',
        () {
      final a = EventAttendee.fromRow({
        'id': 'u9',
        'full_name': null,
        'avatar_url': null,
        'ticket_count': 1,
        'scanned_count': 0,
      });
      expect(a.fullName, isNull);
      expect(a.ticketCount, 1);
    });

    test('un nom entouré d\'espaces est nettoyé', () {
      final a = EventAttendee.fromRow({
        'id': 'u9',
        'full_name': '  Marie  ',
        'ticket_count': 1,
        'scanned_count': 0,
      });
      expect(a.fullName, 'Marie');
    });

    test('décomptes absents : zéro plutôt qu\'une exception', () {
      final a = EventAttendee.fromRow({'id': 'u9'});
      expect(a.ticketCount, 0);
      expect(a.scannedCount, 0);
      expect(a.allScanned, isFalse);
    });
  });
}
