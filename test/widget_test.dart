import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_assistant/main.dart';

void main() {
  testWidgets('POS Assistant app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const POSAssistantApp());
    await tester.pump();
    // Root gate may show loading then shell or lock
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
