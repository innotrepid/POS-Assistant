import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_assistant/core/database/app_database.dart';
import 'package:pos_assistant/services/assistant_service.dart';
import 'package:pos_assistant/services/report_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AssistantService', () {
    late AppDatabase appDb;
    late AssistantService assistant;

    setUp(() async {
      appDb = AppDatabase.memory();
      // Ensure schema is created
      await appDb.database;
      assistant = AssistantService(
        reports: ReportService(database: appDb),
      );
    });

    tearDown(() async {
      await appDb.close();
    });

    test('explains how the app works', () async {
      final answer = await assistant.ask('How does this app work?');
      expect(answer.toLowerCase(), contains('pos'));
      expect(answer.toLowerCase(), contains('stock'));
    });

    test('answers who owes me with empty debtors', () async {
      final answer = await assistant.ask('Who owes me?');
      expect(answer.toLowerCase(), contains('no one'));
    });
  });
}
