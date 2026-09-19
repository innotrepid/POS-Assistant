import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

class CreditorSummary {
  final String supplierId;
  final String supplierName;
  final String? phone;
  final double balance;

  const CreditorSummary({
    required this.supplierId,
    required this.supplierName,
    this.phone,
    required this.balance,
  });
}

class CreditorService {
  CreditorService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<double> getBalance(String supplierId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS balance
      FROM creditor_transactions
      WHERE supplier_id = ?
      ''',
      [supplierId],
    );
    return Money.round((result.first['balance'] as num?)?.toDouble() ?? 0);
  }

  Future<List<CreditorSummary>> listOutstanding({int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        s.id AS supplier_id,
        s.name AS supplier_name,
        s.phone AS phone,
        COALESCE(SUM(c.amount), 0) AS balance
      FROM suppliers s
      INNER JOIN creditor_transactions c ON c.supplier_id = s.id
      GROUP BY s.id
      HAVING balance > 0.001
      ORDER BY balance DESC
      LIMIT ?
      ''',
      [limit],
    );

    return rows
        .map(
          (r) => CreditorSummary(
            supplierId: r['supplier_id'] as String,
            supplierName: r['supplier_name'] as String,
            phone: r['phone'] as String?,
            balance: Money.round((r['balance'] as num?)?.toDouble() ?? 0),
          ),
        )
        .toList();
  }

  Future<double> totalOutstanding() async {
    final list = await listOutstanding(limit: 10000);
    return Money.round(
      list.fold<double>(0, (sum, c) => sum + c.balance),
    );
  }

  Future<List<Map<String, dynamic>>> getStatement(
    String supplierId, {
    int limit = 200,
  }) async {
    final db = await _database.database;
    return db.query(
      'creditor_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<String> recordPayment({
    required String supplierId,
    required double amount,
    String paymentType = 'cash',
    String? reference,
    String? notes,
  }) async {
    final paid = Money.round(amount);
    if (paid <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('Supplier is required.');
    }

    final current = await getBalance(supplierId);
    if (paid > current) {
      throw ArgumentError(
        'Payment ${Money.format(paid)} exceeds outstanding '
        '${Money.format(current)}.',
      );
    }

    final paymentId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final type = paymentType.trim().toLowerCase();
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.insert('creditor_transactions', {
        'id': paymentId,
        'supplier_id': supplierId,
        'purchase_id': null,
        'transaction_type': 'payment',
        'amount': -paid,
        'reference': reference?.trim(),
        'notes': notes?.trim(),
        'created_at': now,
      });

      await txn.insert('payments', {
        'id': _uuid.v4(),
        'supplier_id': supplierId,
        'payment_type': type,
        'amount': paid,
        'reference': reference?.trim(),
        'notes': notes?.trim() ?? 'Supplier payment',
        'created_at': now,
      });

      var remaining = paid;
      final openPurchases = await txn.query(
        'purchases',
        where: 'supplier_id = ? AND balance > 0',
        whereArgs: [supplierId],
        orderBy: 'created_at ASC',
      );

      for (final p in openPurchases) {
        if (remaining <= 0) break;

        final id = p['id'] as String;
        final pBalance = Money.round((p['balance'] as num?)?.toDouble() ?? 0);
        final pPaid = Money.round((p['paid_amount'] as num?)?.toDouble() ?? 0);
        final pTotal = Money.round((p['subtotal'] as num?)?.toDouble() ?? 0);

        final apply = remaining < pBalance ? remaining : pBalance;
        final newPaid = Money.round(pPaid + apply);
        final newBalance = Money.round(pBalance - apply);
        remaining = Money.round(remaining - apply);

        final status = newBalance <= 0
            ? 'paid'
            : (newPaid > 0 ? 'partial' : 'unpaid');

        await txn.update(
          'purchases',
          {
            'paid_amount': newPaid > pTotal ? pTotal : newPaid,
            'balance': newBalance < 0 ? 0 : newBalance,
            'status': status,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'creditor_payment',
        'entity_type': 'supplier',
        'entity_id': supplierId,
        'new_value': 'amount=$paid, payment_type=$type',
        'reason': notes?.trim() ?? 'Supplier payment',
        'created_at': now,
      });
    });

    return paymentId;
  }
}
