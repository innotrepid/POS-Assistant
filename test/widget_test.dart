import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_assistant/main.dart';

void main() {
  testWidgets('POS Assistant app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const POSAssistantApp());
    await tester.pump();

    // Bottom navigation should be present
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);

    // First screen is Dashboard placeholder
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
