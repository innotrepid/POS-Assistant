import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'expense_service.dart';

class DaySummary {
  final String businessDate;
  final double salesTotal;
  final double salesCash;
  final double salesMpesa;
  final double salesCard;
  final double salesOther;
  final double expensesTotal;
  final double expensesCash;
  final int saleCount;
  final bool isClosed;
  final Map<String, dynamic>? closing;

  const DaySummary({
    required this.businessDate,
    required this.salesTotal,
    required this.salesCash,
    required this.salesMpesa,
    required this.salesCard,
    required this.salesOther,
    required this.expensesTotal,
    required this.expensesCash,
    required this.saleCount,
    required this.isClosed,
    this.closing,
  });

  /// Cash expected in till: cash sales − cash expenses (+ opening set at close).
  double expectedCashFromOps(double openingCash) {
    return Money.round(openingCash + salesCash - expensesCash);
  }

  double get expectedMpesa => salesMpesa;
}

class DayClosingService {
  DayClosingService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<DaySummary> getSummary(DateTime day) async {
    final range = DayRange.of(day);
    final db = await _database.database;

    final salesRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS sales_total,
             COUNT(*) AS sale_count
      FROM sales
      WHERE sale_status = 'completed'
        AND created_at >= ? AND created_at < ?
      ''',
      [range.startIso, range.endIso],
    );

    final payRows = await db.rawQuery(
      '''
      SELECT payment_type, COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE created_at >= ? AND created_at < ?
        AND sale_id IS NOT NULL
      GROUP BY payment_type
      ''',
      [range.startIso, range.endIso],
    );

    double cash = 0, mpesa = 0, card = 0, other = 0;
    for (final row in payRows) {
      final type = (row['payment_type'] as String?)?.toLowerCase() ?? '';
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      switch (type) {
        case 'cash':
          cash = total;
          break;
        case 'mpesa':
          mpesa = total;
          break;
        case 'card':
          card = total;
          break;
        default:
          other += total;
      }
    }

    final expenseRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total,
             COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0) AS cash_total
      FROM expenses
      WHERE created_at >= ? AND created_at < ?
      ''',
      [range.startIso, range.endIso],
    );

    final closingRows = await db.query(
      'day_closings',
      where: 'business_date = ?',
      whereArgs: [range.businessDate],
      limit: 1,
    );

    return DaySummary(
      businessDate: range.businessDate,
      salesTotal: Money.round(
        (salesRows.first['sales_total'] as num?)?.toDouble() ?? 0,
      ),
      salesCash: Money.round(cash),
      salesMpesa: Money.round(mpesa),
      salesCard: Money.round(card),
      salesOther: Money.round(other),
      expensesTotal: Money.round(
        (expenseRows.first['total'] as num?)?.toDouble() ?? 0,
      ),
      expensesCash: Money.round(
        (expenseRows.first['cash_total'] as num?)?.toDouble() ?? 0,
      ),
      saleCount: (salesRows.first['sale_count'] as int?) ?? 0,
      isClosed: closingRows.isNotEmpty,
      closing: closingRows.isEmpty ? null : closingRows.first,
    );
  }

  Future<String> closeDay({
    required DateTime day,
    required double openingCash,
    required double countedCash,
    required double countedMpesa,
    String? notes,
  }) async {
    final summary = await getSummary(day);
    if (summary.isClosed) {
      throw StateError('Day ${summary.businessDate} is already closed.');
    }

    final opening = Money.round(openingCash);
    final countedC = Money.round(countedCash);
    final countedM = Money.round(countedMpesa);
    if (opening < 0 || countedC < 0 || countedM < 0) {
      throw ArgumentError('Amounts cannot be negative.');
    }

    final expectedCash = summary.expectedCashFromOps(opening);
    final expectedMpesa = summary.expectedMpesa;

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;

    await db.insert('day_closings', {
      'id': id,
      'business_date': summary.businessDate,
      'opening_cash': opening,
      'counted_cash': countedC,
      'counted_mpesa': countedM,
      'expected_cash': expectedCash,
      'expected_mpesa': expectedMpesa,
      'sales_total': summary.salesTotal,
      'expenses_total': summary.expensesTotal,
      'notes': notes?.trim(),
      'created_at': now,
    });

    await db.insert('audit_logs', {
      'id': _uuid.v4(),
      'action': 'day_closed',
      'entity_type': 'day_closing',
      'entity_id': id,
      'new_value':
          'date=${summary.businessDate}, counted_cash=$countedC, '
          'expected_cash=$expectedCash',
      'created_at': now,
    });

    return id;
  }

  Future<List<Map<String, dynamic>>> listClosings({int limit = 30}) async {
    final db = await _database.database;
    return db.query(
      'day_closings',
      orderBy: 'business_date DESC',
      limit: limit,
    );
  }
}
