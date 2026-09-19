import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercate/main.dart';

void main() {
  testWidgets('Mercate app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MercateApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
