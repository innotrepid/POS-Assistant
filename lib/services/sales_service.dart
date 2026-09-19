import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'policy_service.dart';

const Set<String> kAllowedPaymentTypes = {
  'cash',
  'mpesa',
  'card',
  'bank',
  'credit',
  'split',
};

class PaymentInput {
  final String paymentType;
  final double amount;
  final String? reference;

  const PaymentInput({
    required this.paymentType,
    required this.amount,
    this.reference,
  });
}

class SaleCreateResult {
  final String saleId;
  final double changeGiven;
  final List<String> warningsAcknowledged;

  const SaleCreateResult({
    required this.saleId,
    this.changeGiven = 0,
    this.warningsAcknowledged = const [],
  });
}

class SaleVoidResult {
  final String saleId;
  final double refundedAmount;
  final bool stockRestored;

  const SaleVoidResult({
    required this.saleId,
    required this.refundedAmount,
    required this.stockRestored,
  });
}

class SalesService {
  SalesService({
    AppDatabase? database,
    Uuid? uuid,
    PolicyService? policy,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid(),
       _policy = policy ?? PolicyService();

  final AppDatabase _database;
  final Uuid _uuid;
  final PolicyService _policy;

  Future<List<String>> preflightWarnings({
    required List<SaleLineInput> items,
    required double discount,
    required bool isCreditSale,
    String? customerId,
    double? customerExistingBalance,
    double? customerCreditLimit,
  }) async {
    final warnings = <String>[];
    final subtotal = Money.round(
      items.fold<double>(0, (s, i) => s + i.total),
    );
    final saleDiscount = Money.round(discount);
    final total = Money.round(subtotal - saleDiscount);

    if (saleDiscount > 0) {
      final pct = subtotal > 0 ? (saleDiscount / subtotal) * 100 : 0;
      warnings.add(
        'Discount applied: ${Money.format(saleDiscount)} '
        '(${pct.toStringAsFixed(1)}% of ${Money.format(subtotal)}). '
        'Final total ${Money.format(total)}.',
      );
      final largePct = await _policy.getLargeDiscountPercent();
      if (pct >= largePct) {
        warnings.add(
          'LARGE DISCOUNT: ${pct.toStringAsFixed(1)}% '
          '(threshold ${largePct.toStringAsFixed(0)}%).',
        );
      }
      if (total == 0) {
        warnings.add('Discount reduces the sale total to zero.');
      }
    }

    for (final item in items) {
      if (item.unitCost != null &&
          item.unitPrice < item.unitCost! &&
          !item.isQuickSale) {
        warnings.add(
          'BELOW COST: ${item.productName} sells at '
          '${Money.format(item.unitPrice)} below cost '
          '${Money.format(item.unitCost!)}.',
        );
      }
      if (!item.isQuickSale && item.unitCost == null) {
        warnings.add('Cost unknown for ${item.productName}.');
      }
    }

    if (isCreditSale) {
      warnings.add(
        'This sale creates DEBT. Outstanding on this sale will be '
        'the unpaid balance after any amount paid now.',
      );
      if (customerExistingBalance != null && customerExistingBalance > 0) {
        warnings.add(
          'Customer already owes ${Money.format(customerExistingBalance)}.',
        );
      }
      if (customerCreditLimit != null &&
          customerExistingBalance != null &&
          customerExistingBalance + total > customerCreditLimit) {
        warnings.add(
          'Credit limit ${Money.format(customerCreditLimit)} may be exceeded.',
        );
      }
    }

    return warnings;
  }

  Future<bool> isDuplicateReference(String reference) async {
    final ref = reference.trim();
    if (ref.isEmpty) return false;
    final db = await _database.database;
    final rows = await db.query(
      'payments',
      where: 'reference = ?',
      whereArgs: [ref],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<SaleCreateResult> createSale({
    String? customerId,
    required List<SaleLineInput> items,
    double discount = 0,
    required List<PaymentInput> payments,
    bool isCreditSale = false,
    double? amountTendered,
    List<String> warningsAcknowledged = const [],
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }

    if (discount < 0) {
      throw ArgumentError('Sale discount cannot be negative.');
    }

    for (final item in items) {
      if (!item.isQuickSale &&
          (item.productId == null || item.productId!.trim().isEmpty)) {
        throw ArgumentError('Catalogue items must have a product ID.');
      }
      if (item.productName.trim().isEmpty) {
        throw ArgumentError('Every sale item must have a product name.');
      }
      if (item.quantity <= 0) {
        throw ArgumentError(
          'Quantity for ${item.productName} must be greater than zero.',
        );
      }
      if (item.unitPrice < 0) {
        throw ArgumentError(
          'Selling price for ${item.productName} cannot be negative.',
        );
      }
      if (item.discount < 0) {
        throw ArgumentError(
          'Discount for ${item.productName} cannot be negative.',
        );
      }
      final lineGross = Money.round(item.quantity * item.unitPrice);
      if (item.discount > lineGross) {
        throw ArgumentError(
          'Discount for ${item.productName} cannot exceed the line value.',
        );
      }
    }

    final subtotal = Money.round(
      items.fold<double>(0, (sum, item) => sum + item.total),
    );
    final saleDiscount = Money.round(discount);
    if (saleDiscount > subtotal) {
      throw ArgumentError('Sale discount cannot exceed the subtotal.');
    }
    final total = Money.round(subtotal - saleDiscount);

    var paidFromPayments = 0.0;
    for (final p in payments) {
      final type = p.paymentType.trim().toLowerCase();
      if (type != 'cash' &&
          type != 'mpesa' &&
          type != 'card' &&
          type != 'bank') {
        throw ArgumentError('Unsupported payment type "$type".');
      }
      if (p.amount < 0) {
        throw ArgumentError('Payment amount cannot be negative.');
      }
      if (p.amount == 0) continue;

      if ((type == 'mpesa' || type == 'bank') &&
          (p.reference == null || p.reference!.trim().isEmpty)) {
        throw ArgumentError(
          '${type.toUpperCase()} payment requires a transaction/reference number.',
        );
      }
      paidFromPayments = Money.round(paidFromPayments + p.amount);
    }

    var changeGiven = 0.0;
    var paid = paidFromPayments;
    if (amountTendered != null) {
      final tendered = Money.round(amountTendered);
      if (tendered < 0) {
        throw ArgumentError('Amount tendered cannot be negative.');
      }
      final cashOnly = payments.length == 1 &&
          payments.first.paymentType.toLowerCase() == 'cash';
      if (cashOnly && tendered > total) {
        paid = total;
        changeGiven = Money.round(tendered - total);
      } else if (cashOnly) {
        paid = Money.round(payments.first.amount);
      }
    }

    if (paid > total) {
      final allCash = payments.every(
        (p) => p.paymentType.toLowerCase() == 'cash',
      );
      if (allCash) {
        changeGiven = Money.round(paid - total);
        paid = total;
      } else {
        throw ArgumentError('Paid amount cannot exceed the sale total.');
      }
    }

    final balance = Money.round(total - paid);

    if (balance > 0 && !isCreditSale) {
      throw ArgumentError(
        'Sale has an unpaid balance of ${Money.format(balance)}. '
        'Choose Credit explicitly, or pay the full amount.',
      );
    }

    if (balance > 0 && (customerId == null || customerId.trim().isEmpty)) {
      throw ArgumentError(
        'A customer is required when a sale has an outstanding balance.',
      );
    }

    final allowNegative = await _policy.getAllowNegativeStock();
    final saleId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;

    await db.transaction((txn) async {
      for (final item in items) {
        if (item.isQuickSale) continue;

        final result = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(quantity), 0) AS stock
          FROM stock_movements
          WHERE product_id = ?
          ''',
          [item.productId],
        );
        final currentStock =
            (result.first['stock'] as num?)?.toDouble() ?? 0;

        if (currentStock < item.quantity && !allowNegative) {
          throw StateError(
            'Insufficient stock for ${item.productName}. '
            'Available: ${_formatNumber(currentStock)}, '
            'requested: ${_formatNumber(item.quantity)}. '
            '(Enable negative stock in policies to override.)',
          );
        }
      }

      await txn.insert('sales', {
        'id': saleId,
        'customer_id': customerId,
        'subtotal': subtotal,
        'discount': saleDiscount,
        'total': total,
        'paid_amount': paid,
        'balance': balance,
        'payment_status': _paymentStatus(paid: paid, balance: balance),
        'sale_status': 'completed',
        'created_at': now,
      });

      for (final item in items) {
        final lineTotal = Money.round(item.total);
        final lineDiscount = Money.round(item.discount);
        final unitPrice = Money.round(item.unitPrice);
        final unitCost =
            item.unitCost != null ? Money.round(item.unitCost!) : null;

        await txn.insert('sale_items', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'product_id': item.isQuickSale ? null : item.productId,
          'product_name': item.isQuickSale
              ? '${item.productName} (quick sale)'
              : item.productName,
          'quantity': item.quantity,
          'unit_price': unitPrice,
          'unit_cost': unitCost,
          'discount': lineDiscount,
          'total': lineTotal,
        });

        if (!item.isQuickSale) {
          await txn.insert('stock_movements', {
            'id': _uuid.v4(),
            'product_id': item.productId,
            'movement_type': 'sale',
            'quantity': -item.quantity,
            'unit_cost': unitCost,
            'reference_id': saleId,
            'reason': 'Sale completed',
            'created_at': now,
          });
        }
      }

      for (final p in payments) {
        final amt = Money.round(p.amount);
        if (amt <= 0) continue;
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'customer_id': customerId,
          'payment_type': p.paymentType.trim().toLowerCase(),
          'amount': amt > total ? total : amt,
          'reference': p.reference?.trim(),
          'created_at': now,
        });
      }

      if (balance > 0) {
        await txn.insert('debtor_transactions', {
          'id': _uuid.v4(),
          'customer_id': customerId,
          'sale_id': saleId,
          'transaction_type': 'credit_sale',
          'amount': balance,
          'created_at': now,
        });
      }

      final ack = warningsAcknowledged.isEmpty
          ? ''
          : ' warnings=${warningsAcknowledged.join(' | ')}';

      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'sale_created',
        'entity_type': 'sale',
        'entity_id': saleId,
        'new_value':
            'total=$total, paid=$paid, balance=$balance, '
            'change=$changeGiven, credit=$isCreditSale$ack',
        'reason': 'Sale completed',
        'created_at': now,
      });

      if (warningsAcknowledged.isNotEmpty) {
        await txn.insert('audit_logs', {
          'id': _uuid.v4(),
          'action': 'sale_warnings_acknowledged',
          'entity_type': 'sale',
          'entity_id': saleId,
          'new_value': warningsAcknowledged.join(' || '),
          'reason': 'Operator confirmed risk warnings',
          'created_at': now,
        });
      }
    });

    return SaleCreateResult(
      saleId: saleId,
      changeGiven: changeGiven,
      warningsAcknowledged: warningsAcknowledged,
    );
  }

  /// Full void/refund of a completed sale.
  ///
  /// - Idempotent: already voided/refunded → StateError
  /// - Restores stock for catalogue lines once
  /// - Reverses remaining sale debt on the debtor ledger
  /// - Writes a refund payment (negative amount) using preferred method
  /// - Does not rewrite historical line prices
  Future<SaleVoidResult> voidSale({
    required String saleId,
    required String reason,
    String? refundPaymentType,
    String? refundReference,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) {
      throw ArgumentError('A reason is required to void a sale.');
    }

    final db = await _database.database;
    final saleRows = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (saleRows.isEmpty) {
      throw StateError('Sale not found.');
    }

    final sale = saleRows.first;
    final status = sale['sale_status'] as String? ?? '';
    if (status == 'voided' || status == 'refunded') {
      throw StateError('Sale is already $status. Stock was not restored again.');
    }
    if (status != 'completed') {
      throw StateError('Only completed sales can be voided (status: $status).');
    }

    // Guard: stock already restored for this sale?
    final priorRefund = await db.query(
      'stock_movements',
      where: "reference_id = ? AND movement_type = 'sale_refund'",
      whereArgs: [saleId],
      limit: 1,
    );
    if (priorRefund.isNotEmpty) {
      throw StateError(
        'Stock was already restored for this sale. Void aborted.',
      );
    }

    final total = Money.round((sale['total'] as num?)?.toDouble() ?? 0);
    final paid = Money.round((sale['paid_amount'] as num?)?.toDouble() ?? 0);
    final balance = Money.round((sale['balance'] as num?)?.toDouble() ?? 0);
    final customerId = sale['customer_id'] as String?;

    final items = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );

    final payments = await db.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'created_at ASC',
    );

    var preferredType = refundPaymentType?.trim().toLowerCase();
    if (preferredType == null || preferredType.isEmpty) {
      if (payments.isNotEmpty) {
        preferredType = payments.first['payment_type'] as String? ?? 'cash';
      } else {
        preferredType = 'cash';
      }
    }

    final now = DateTime.now().toIso8601String();
    var stockRestored = false;

    await db.transaction((txn) async {
      // Restore stock for catalogue items
      for (final item in items) {
        final productId = item['product_id'] as String?;
        if (productId == null || productId.isEmpty) continue;

        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (qty <= 0) continue;

        final unitCost = (item['unit_cost'] as num?)?.toDouble();

        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'product_id': productId,
          'movement_type': 'sale_refund',
          'quantity': qty,
          'unit_cost': unitCost,
          'reference_id': saleId,
          'reason': 'Void/refund: $why',
          'created_at': now,
        });
        stockRestored = true;
      }

      // Reverse remaining debt on this sale
      if (balance > 0 && customerId != null) {
        await txn.insert('debtor_transactions', {
          'id': _uuid.v4(),
          'customer_id': customerId,
          'sale_id': saleId,
          'transaction_type': 'sale_void_reversal',
          'amount': -balance,
          'notes': 'Void: $why',
          'created_at': now,
        });
      }

      // Refund of amount previously paid (money back to customer)
      if (paid > 0) {
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'customer_id': customerId,
          'payment_type': 'refund_$preferredType',
          'amount': -paid,
          'reference': refundReference?.trim(),
          'notes': 'Void refund: $why',
          'created_at': now,
        });
      }

      await txn.update(
        'sales',
        {
          'sale_status': 'voided',
          'payment_status': 'refunded',
          'paid_amount': 0,
          'balance': 0,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'sale_voided',
        'entity_type': 'sale',
        'entity_id': saleId,
        'previous_value':
            'total=$total, paid=$paid, balance=$balance, status=completed',
        'new_value':
            'status=voided, refunded=$paid, debt_reversed=$balance, '
            'method=$preferredType',
        'reason': why,
        'created_at': now,
      });
    });

    return SaleVoidResult(
      saleId: saleId,
      refundedAmount: paid,
      stockRestored: stockRestored,
    );
  }

  /// True when refunded amount meets/exceeds configured large-refund threshold.
  Future<bool> isLargeRefund(double amount) async {
    final threshold = await _policy.getLargeRefundAmount();
    return Money.round(amount) >= threshold;
  }

  Future<Map<String, dynamic>?> getSale(String saleId) async {
    final db = await _database.database;
    final rows = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final db = await _database.database;
    return db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
  }

  Future<List<Map<String, dynamic>>> getSalePayments(String saleId) async {
    final db = await _database.database;
    return db.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listSales({
    int limit = 50,
    String? customerId,
  }) async {
    final db = await _database.database;
    if (customerId != null) {
      return db.query(
        'sales',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }
    return db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchPaymentsByReference(
    String reference,
  ) async {
    final db = await _database.database;
    return db.query(
      'payments',
      where: 'reference LIKE ?',
      whereArgs: ['%${reference.trim()}%'],
      orderBy: 'created_at DESC',
      limit: 50,
    );
  }

  String _paymentStatus({
    required double paid,
    required double balance,
  }) {
    if (balance == 0) return 'paid';
    if (paid > 0) return 'partially_paid';
    return 'unpaid';
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class SaleLineInput {
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double? unitCost;
  final double discount;
  final bool isQuickSale;

  const SaleLineInput({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
    this.discount = 0,
    this.isQuickSale = false,
  });

  double get total => Money.round((quantity * unitPrice) - discount);
}
