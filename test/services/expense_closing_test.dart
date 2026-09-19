import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_assistant/core/database/app_database.dart';
import 'package:pos_assistant/services/day_closing_service.dart';
import 'package:pos_assistant/services/expense_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Expense + day closing', () {
    late AppDatabase appDb;
    late ExpenseService expenses;
    late DayClosingService closing;

    setUp(() async {
      appDb = AppDatabase.memory();
      expenses = ExpenseService(database: appDb);
      closing = DayClosingService(database: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('records expense and totals for day', () async {
      final now = DateTime.now();
      await expenses.recordExpense(
        category: 'transport',
        amount: 200,
        paymentMethod: 'cash',
        at: now,
      );
      await expenses.recordExpense(
        category: 'misc',
        amount: 50,
        paymentMethod: 'mpesa',
        at: now,
      );

      expect(await expenses.totalForDay(now), 250);

      final summary = await closing.getSummary(now);
      expect(summary.expensesTotal, 250);
      expect(summary.expensesCash, 200);
      expect(summary.isClosed, isFalse);
    });

    test('close day stores variance fields', () async {
      final now = DateTime.now();
      await expenses.recordExpense(
        category: 'food',
        amount: 100,
        paymentMethod: 'cash',
        at: now,
      );

      await closing.closeDay(
        day: now,
        openingCash: 500,
        countedCash: 400,
        countedMpesa: 0,
        notes: 'test close',
      );

      final summary = await closing.getSummary(now);
      expect(summary.isClosed, isTrue);
      expect(summary.closing!['opening_cash'], 500);
      expect(summary.closing!['expected_cash'], 400);
      expect(summary.closing!['counted_cash'], 400);

      expect(
        () => closing.closeDay(
          day: now,
          openingCash: 0,
          countedCash: 0,
          countedMpesa: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
