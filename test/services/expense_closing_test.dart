import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/services/day_closing_service.dart';
import 'package:mercate/services/expense_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Expense + day closing', () {
    late AppDatabase db;
    late ExpenseService expenses;
    late DayClosingService dayClose;

    setUp(() async {
      db = AppDatabase.memory();
      await db.database;
      expenses = ExpenseService(database: db);
      dayClose = DayClosingService(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('records expense and totals for day', () async {
      final now = DateTime.now();
      await expenses.recordExpense(
        category: 'Transport',
        amount: 50,
        paymentMethod: 'cash',
        description: 'matatu',
        at: now,
      );
      final summary = await dayClose.getSummary(now);
      expect(summary.expensesTotal, 50);
      expect(summary.expensesCash, 50);
    });

    test('close day stores variance fields', () async {
      final now = DateTime.now();
      await expenses.recordExpense(
        category: 'Other',
        amount: 20,
        paymentMethod: 'cash',
        at: now,
      );
      await dayClose.closeDay(
        day: now,
        openingCash: 100,
        countedCash: 80,
        countedMpesa: 0,
      );
      final summary = await dayClose.getSummary(now);
      expect(summary.isClosed, isTrue);
    });
  });
}
