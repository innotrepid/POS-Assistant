import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

class DebtorSummary {
  final String customerId;
  final String customerName;
  final String? phone;
  final double balance;
  final int daysOpen;
  final bool isOverdue;

  const DebtorSummary({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.balance,
    this.daysOpen = 0,
    this.isOverdue = false,
  });
}

class DebtorService {
  DebtorService({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<double> getBalance(String customerId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS balance FROM debtor_transactions WHERE customer_id = ?',
      [customerId],
    );
    return Money.round((result.first['balance'] as num?)?.toDouble() ?? 0);
  }

  Future<List<DebtorSummary>> listOutstanding({
    int limit = 100,
    int? overdueDays,
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.id AS customer_id, c.name AS customer_name, c.phone AS phone,
             COALESCE(SUM(d.amount), 0) AS balance
      FROM customers c
      INNER JOIN debtor_transactions d ON d.customer_id = c.id
      GROUP BY c.id
      HAVING balance > 0.001
      ORDER BY balance DESC
      LIMIT ?
      ''',
      [limit],
    );
    final threshold = overdueDays;
    final list = <DebtorSummary>[];
    for (final r in rows) {
      final customerId = r['customer_id'] as String;
      final days = await _daysOpenFor(customerId);
      final overdue = threshold != null && threshold > 0 && days >= threshold;
      list.add(DebtorSummary(
        customerId: customerId,
        customerName: r['customer_name'] as String,
        phone: r['phone'] as String?,
        balance: Money.round((r['balance'] as num?)?.toDouble() ?? 0),
        daysOpen: days,
        isOverdue: overdue,
      ));
    }
    if (threshold != null) {
      list.sort((a, b) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        final byDays = b.daysOpen.compareTo(a.daysOpen);
        if (byDays != 0) return byDays;
        return b.balance.compareTo(a.balance);
      });
    }
    return list;
  }

  Future<List<DebtorSummary>> listOverdue({
    required int overdueDays,
    int limit = 100,
  }) async {
    final all = await listOutstanding(limit: limit * 2, overdueDays: overdueDays);
    return all.where((d) => d.isOverdue).take(limit).toList();
  }

  Future<int> _daysOpenFor(String customerId) async {
    final db = await _database.database;
    final open = await db.query(
      'sales',
      where: "customer_id = ? AND balance > 0 AND sale_status = 'completed'",
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (open.isEmpty) return 0;
    final createdAt = DateTime.tryParse(open.first['created_at'] as String? ?? '');
    if (createdAt == null) return 0;
    return DateTime.now().difference(createdAt).inDays;
  }

  Future<double> totalOutstanding() async {
    final list = await listOutstanding(limit: 10000);
    return Money.round(list.fold<double>(0, (sum, d) => sum + d.balance));
  }

  Future<List<Map<String, dynamic>>> getStatement(String customerId, {int limit = 200}) async {
    final db = await _database.database;
    return db.query(
      'debtor_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getOpenSales(String customerId) async {
    final db = await _database.database;
    return db.query(
      'sales',
      where: "customer_id = ? AND balance > 0 AND sale_status = 'completed'",
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
    );
  }

  static String collectionSmsBody({
    required String customerName,
    required double balance,
    required String shopName,
    int? daysOpen,
  }) {
    final days = daysOpen != null && daysOpen > 0
        ? ' (open $daysOpen day${daysOpen == 1 ? '' : 's'})'
        : '';
    return 'Habari $customerName, this is $shopName. '
        'Your outstanding balance is ${Money.format(balance)}$days. '
        'Please settle when you can. Asante.';
  }

  Future<String> recordRepayment({
    required String customerId,
    required double amount,
    String paymentType = 'cash',
    String? reference,
    String? notes,
  }) async {
    final paid = Money.round(amount);
    if (paid <= 0) throw ArgumentError('Repayment amount must be greater than zero.');
    if (customerId.trim().isEmpty) throw ArgumentError('Customer is required.');
    final type = paymentType.trim().toLowerCase();
    if (type.isEmpty) throw ArgumentError('Payment type is required.');
    final current = await getBalance(customerId);
    if (paid > current) {
      throw ArgumentError(
        'Repayment ${Money.format(paid)} exceeds outstanding ${Money.format(current)}.',
      );
    }
    final repaymentId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('debtor_transactions', {
        'id': repaymentId,
        'customer_id': customerId,
        'sale_id': null,
        'transaction_type': 'repayment',
        'amount': -paid,
        'reference': reference?.trim(),
        'notes': notes?.trim(),
        'created_at': now,
      });
      await txn.insert('payments', {
        'id': _uuid.v4(),
        'sale_id': null,
        'customer_id': customerId,
        'payment_type': type,
        'amount': paid,
        'reference': reference?.trim(),
        'notes': notes?.trim() ?? 'Debtor repayment',
        'created_at': now,
      });
      var remaining = paid;
      final openSales = await txn.query(
        'sales',
        where: "customer_id = ? AND balance > 0 AND sale_status = 'completed'",
        whereArgs: [customerId],
        orderBy: 'created_at ASC',
      );
      for (final sale in openSales) {
        if (remaining <= 0) break;
        final saleId = sale['id'] as String;
        final saleBalance = Money.round((sale['balance'] as num?)?.toDouble() ?? 0);
        final salePaid = Money.round((sale['paid_amount'] as num?)?.toDouble() ?? 0);
        final saleTotal = Money.round((sale['total'] as num?)?.toDouble() ?? 0);
        final apply = remaining < saleBalance ? remaining : saleBalance;
        final newPaid = Money.round(salePaid + apply);
        final newBalance = Money.round(saleBalance - apply);
        remaining = Money.round(remaining - apply);
        final status = newBalance <= 0
            ? 'paid'
            : (newPaid > 0 ? 'partially_paid' : 'unpaid');
        await txn.update(
          'sales',
          {
            'paid_amount': newPaid > saleTotal ? saleTotal : newPaid,
            'balance': newBalance < 0 ? 0 : newBalance,
            'payment_status': status,
          },
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }
      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'debtor_repayment',
        'entity_type': 'customer',
        'entity_id': customerId,
        'new_value': 'amount=$paid, payment_type=$type',
        'reason': notes?.trim() ?? 'Customer repayment',
        'created_at': now,
      });
    });
    return repaymentId;
  }
}
