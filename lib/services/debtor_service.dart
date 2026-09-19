import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

/// Outstanding debtor summary for one customer.
class DebtorSummary {
  final String customerId;
  final String customerName;
  final String? phone;
  final double balance;

  const DebtorSummary({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.balance,
  });
}

class DebtorService {
  DebtorService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  /// Live balance from debtor_transactions ledger.
  /// credit_sale / adjustment increase; repayment decreases.
  Future<double> getBalance(String customerId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS balance
      FROM debtor_transactions
      WHERE customer_id = ?
      ''',
      [customerId],
    );
    return Money.round((result.first['balance'] as num?)?.toDouble() ?? 0);
  }

  /// Customers with balance > 0, largest first.
  Future<List<DebtorSummary>> listOutstanding({int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        c.id AS customer_id,
        c.name AS customer_name,
        c.phone AS phone,
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

    return rows
        .map(
          (r) => DebtorSummary(
            customerId: r['customer_id'] as String,
            customerName: r['customer_name'] as String,
            phone: r['phone'] as String?,
            balance: Money.round((r['balance'] as num?)?.toDouble() ?? 0),
          ),
        )
        .toList();
  }

  Future<double> totalOutstanding() async {
    final list = await listOutstanding(limit: 10000);
    return Money.round(
      list.fold<double>(0, (sum, d) => sum + d.balance),
    );
  }

  Future<List<Map<String, dynamic>>> getStatement(
    String customerId, {
    int limit = 200,
  }) async {
    final db = await _database.database;
    return db.query(
      'debtor_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Open credit sales for a customer (balance > 0), oldest first.
  Future<List<Map<String, dynamic>>> getOpenSales(String customerId) async {
    final db = await _database.database;
    return db.query(
      'sales',
      where: "customer_id = ? AND balance > 0 AND sale_status = 'completed'",
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
    );
  }

  /// Record a customer repayment.
  ///
  /// - Writes debtor_transactions (negative amount)
  /// - Writes payments row
  /// - FIFO: reduces open sales paid_amount / balance / payment_status
  /// - Audit log
  Future<String> recordRepayment({
    required String customerId,
    required double amount,
    String paymentType = 'cash',
    String? reference,
    String? notes,
  }) async {
    final paid = Money.round(amount);
    if (paid <= 0) {
      throw ArgumentError('Repayment amount must be greater than zero.');
    }
    if (customerId.trim().isEmpty) {
      throw ArgumentError('Customer is required.');
    }

    final type = paymentType.trim().toLowerCase();
    if (type.isEmpty) {
      throw ArgumentError('Payment type is required.');
    }

    final current = await getBalance(customerId);
    if (paid > current) {
      throw ArgumentError(
        'Repayment ${Money.format(paid)} exceeds outstanding '
        '${Money.format(current)}.',
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

      // FIFO against open sales
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
        final saleBalance = Money.round(
          (sale['balance'] as num?)?.toDouble() ?? 0,
        );
        final salePaid = Money.round(
          (sale['paid_amount'] as num?)?.toDouble() ?? 0,
        );
        final saleTotal = Money.round(
          (sale['total'] as num?)?.toDouble() ?? 0,
        );

        final apply = remaining < saleBalance ? remaining : saleBalance;
        final newPaid = Money.round(salePaid + apply);
        final newBalance = Money.round(saleBalance - apply);
        remaining = Money.round(remaining - apply);

        String status;
        if (newBalance <= 0) {
          status = 'paid';
        } else if (newPaid > 0) {
          status = 'partially_paid';
        } else {
          status = 'unpaid';
        }

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
