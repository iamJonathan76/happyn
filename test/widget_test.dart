// Smoke test minimal. Le test compteur généré par défaut a été retiré
// (l'app n'a pas de compteur, et pomper l'app complète nécessite Supabase).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('HAPPYN'))),
    );
    expect(find.text('HAPPYN'), findsOneWidget);
  });
}
