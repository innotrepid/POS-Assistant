import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_assistant/main.dart';

void main() {
  testWidgets('POS Assistant app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const POSAssistantApp());
    expect(find.text('POS Assistant'), findsWidgets);
    expect(find.byIcon(Icons.point_of_sale), findsOneWidget);
  });
}
