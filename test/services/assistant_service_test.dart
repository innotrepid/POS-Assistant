import 'package:flutter_test/flutter_test.dart';
import 'package:mercate/services/assistant_service.dart';
import 'package:mercate/services/locale_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Deterministic English labels for CI.
    try {
      await localeController.setLanguageCode('en');
    } catch (_) {}
  });

  group('AssistantService', () {
    test('explains how the app works', () async {
      final service = AssistantService();
      final reply = await service.ask('How does this app work?');
      final t = reply.text.toLowerCase();
      expect(t, isNotEmpty);
      expect(
        t.contains('mercate') ||
            t.contains('offline') ||
            t.contains('confirm') ||
            t.contains('msaidizi'),
        isTrue,
        reason: 'Unexpected help text: ${reply.text}',
      );
    });

    test('answers who owes me without crashing', () async {
      final service = AssistantService();
      final reply = await service.ask('Who owes me?');
      expect(reply.text, isNotEmpty);
    });

    test('empty query returns guidance', () async {
      final service = AssistantService();
      final reply = await service.ask('');
      expect(reply.text, isNotEmpty);
    });
  });
}
