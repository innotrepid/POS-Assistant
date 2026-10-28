import 'package:flutter_test/flutter_test.dart';
import 'package:mercate/services/assistant_service.dart';

void main() {
  group('AssistantService', () {
    test('explains how the app works', () async {
      final service = AssistantService();
      final reply = await service.reply('How does this app work?');
      expect(reply.toLowerCase(), contains('mercate'));
    });

    test('answers who owes me with empty debtors', () async {
      final service = AssistantService();
      // May talk about debtors / deni without crashing when DB is empty in unit context.
      final reply = await service.reply('Who owes me?');
      expect(reply, isNotEmpty);
    });
  });
}
