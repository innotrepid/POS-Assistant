import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_assistant/main.dart';

void main() {
  testWidgets('POS Assistant app smoke test', (WidgetTester tester) async {
    // We test the app widget directly (avoid calling the real main() that opens the database)
    await tester.pumpWidget(const POSAssistantApp());

    // First screen is Dashboard
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Module ready for implementation'), findsOneWidget);

    // Bottom navigation should be present
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
  });
}
