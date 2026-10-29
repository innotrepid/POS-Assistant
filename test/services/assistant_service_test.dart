import 'package:flutter_test/flutter_test.dart';
import 'package:mercate/services/assistant_service.dart';

void main() {
  group('AssistantService', () {
    test('explains how the app works', () async {
      final service = AssistantService();
      final reply = await service.ask('How does this app work?');
      expect(reply.text.toLowerCase(), contains('mercate'));
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
