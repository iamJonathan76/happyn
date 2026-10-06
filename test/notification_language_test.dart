import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happyn/core/providers/locale_provider.dart';

// La base n'accepte que « en » et « fr » (contrainte sur profiles.language) :
// toute autre valeur ferait échouer l'écriture, et la personne recevrait ses
// notifications en anglais sans que rien ne le signale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un choix explicite est recopié tel quel', () {
    expect(notificationLanguageFor(const Locale('fr')), 'fr');
    expect(notificationLanguageFor(const Locale('en')), 'en');
    expect(notificationLanguageFor(const Locale('fr', 'CA')), 'fr');
  });

  test('une langue que l\'app ne connaît pas retombe sur l\'anglais', () {
    expect(notificationLanguageFor(const Locale('de')), 'en');
  });

  test('« langue du système » suit la première langue connue du téléphone', () {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    addTearDown(dispatcher.clearLocalesTestValue);

    dispatcher.localesTestValue = const [Locale('de'), Locale('fr', 'CA')];
    expect(notificationLanguageFor(null), 'fr');

    dispatcher.localesTestValue = const [Locale('es')];
    expect(notificationLanguageFor(null), 'en');
  });
}
