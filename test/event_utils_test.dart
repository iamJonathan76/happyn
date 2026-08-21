import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/events/event_utils.dart';

/// Ces règles décident ce qui apparaît dans la découverte. Une régression ici
/// ne casse rien visiblement : elle fait juste apparaître un événement privé
/// ou annulé dans le fil de tout le monde, en silence. D'où ces tests.
void main() {
  String iso(Duration offset) =>
      DateTime.now().add(offset).toIso8601String();

  Map<String, dynamic> event({
    String? status,
    String? visibility,
    String? start,
    String? end,
  }) =>
      {
        if (status != null) 'status': status,
        if (visibility != null) 'visibility': visibility,
        if (start != null) 'start_date': start,
        if (end != null) 'end_date': end,
      };

  group('isEventPast', () {
    test('se base sur la date de fin quand elle existe', () {
      // Commencé hier, se termine demain : en cours, donc pas passé.
      final ev = event(
        start: iso(const Duration(days: -1)),
        end: iso(const Duration(days: 1)),
      );
      expect(isEventPast(ev), isFalse);
    });

    test('retombe sur la date de début si la fin manque', () {
      expect(isEventPast(event(start: iso(const Duration(days: -1)))), isTrue);
      expect(isEventPast(event(start: iso(const Duration(days: 1)))), isFalse);
    });

    test('sans aucune date, ne se déclare pas passé', () {
      expect(isEventPast(event()), isFalse);
    });

    test('une date illisible ne fait pas planter', () {
      expect(isEventPast(event(start: 'pas-une-date')), isFalse);
    });
  });

  group('valeurs par défaut', () {
    test('sans statut, un événement est considéré publié', () {
      expect(eventStatus(event()), 'published');
    });

    test('sans visibilité, un événement est public', () {
      expect(isEventPrivate(event()), isFalse);
    });
  });

  group('isEventVisible — ce qui entre dans la découverte', () {
    final futur = iso(const Duration(days: 3));

    test('publié, à venir et public : visible', () {
      expect(
        isEventVisible(event(status: 'published', visibility: 'public', start: futur)),
        isTrue,
      );
    });

    test('privé : jamais visible, même publié et à venir', () {
      expect(
        isEventVisible(
            event(status: 'published', visibility: 'private', start: futur)),
        isFalse,
      );
    });

    test('brouillon : jamais visible', () {
      expect(isEventVisible(event(status: 'draft', start: futur)), isFalse);
    });

    test('annulé : jamais visible', () {
      expect(isEventVisible(event(status: 'cancelled', start: futur)), isFalse);
    });

    test('terminé : jamais visible', () {
      expect(
        isEventVisible(
            event(status: 'published', start: iso(const Duration(days: -2)))),
        isFalse,
      );
    });
  });
}
