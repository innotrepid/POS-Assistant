import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp smoke test', (WidgetTester tester) async {
    // Do not pump MercateApp here: it opens SQLite + local notifications
    // plugins that are not available under plain flutter test on Linux CI.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Mercate'),
        ),
      ),
    );
    expect(find.text('Mercate'), findsOneWidget);
  });
}
