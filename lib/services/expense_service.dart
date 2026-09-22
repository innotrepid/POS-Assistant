import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

const List<String> kExpenseCategories = [
  'transport',
  'rent',
  'utilities',
  'salaries',
  'supplies',
  'stock purchase',
  'food',
  'misc',
];

class ExpenseService {
  ExpenseService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> recordExpense({
    required String category,
    required double amount,
    String? description,
    String paymentMethod = 'cash',
    DateTime? at,
  }) async {
    final cat = category.trim().toLowerCase();
    if (cat.isEmpty) {
      throw ArgumentError('Category is required.');
    }
    final value = Money.round(amount);
    if (value <= 0) {
      throw ArgumentError('Expense amount must be greater than zero.');
    }

    final id = _uuid.v4();
    final when = (at ?? DateTime.now()).toIso8601String();
    final db = await _database.database;

    await db.insert('expenses', {
      'id': id,
      'category': cat,
      'description': description?.trim(),
      'amount': value,
      'payment_method': paymentMethod.trim().toLowerCase(),
      'created_at': when,
    });

    await db.insert('audit_logs', {
      'id': _uuid.v4(),
      'action': 'expense_recorded',
      'entity_type': 'expense',
      'entity_id': id,
      'new_value': 'category=$cat, amount=$value',
      'created_at': when,
    });

    return id;
  }

  Future<void> voidExpense({
    required String expenseId,
    required String reason,
  }) async {
    if (expenseId.trim().isEmpty) {
      throw ArgumentError('Expense id is required.');
    }
    final why = reason.trim();
    if (why.isEmpty) {
      throw ArgumentError('A reason is required to void an expense.');
    }

    final db = await _database.database;
    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Expense not found.');
    }

    final row = rows.first;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'expense_voided',
        'entity_type': 'expense',
        'entity_id': expenseId,
        'old_value':
            'category=${row['category']}, amount=${row['amount']}',
        'reason': why,
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, dynamic>>> listExpenses({
    DateTime? day,
    int limit = 100,
  }) async {
    final db = await _database.database;
    if (day != null) {
      final range = DayRange.of(day);
      return db.query(
        'expenses',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [range.startIso, range.endIso],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }
    return db.query(
      'expenses',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<double> totalForDay(DateTime day) async {
    final db = await _database.database;
    final range = DayRange.of(day);
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE created_at >= ? AND created_at < ?
      ''',
      [range.startIso, range.endIso],
    );
    return Money.round((result.first['total'] as num?)?.toDouble() ?? 0);
  }
}

/// Local calendar day bounds as ISO strings for SQLite comparisons.
class DayRange {
  final DateTime start;
  final DateTime end;

  DayRange._(this.start, this.end);

  factory DayRange.of(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return DayRange._(start, end);
  }

  String get startIso => start.toIso8601String();
  String get endIso => end.toIso8601String();

  String get businessDate {
    final y = start.year.toString().padLeft(4, '0');
    final m = start.month.toString().padLeft(2, '0');
    final d = start.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
