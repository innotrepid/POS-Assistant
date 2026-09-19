import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

/// Allowed payment types for foundation POS.
const Set<String> kAllowedPaymentTypes = {
  'cash',
  'mpesa',
  'card',
  'credit',
  'split',
};

class SalesService {
  SalesService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  /// Creates a completed sale inside a single DB transaction.
  ///
  /// Catalogue items (with [SaleLineInput.productId]) deduct stock.
  /// Quick-sale items (no product id) do **not** touch inventory.
  Future<String> createSale({
    String? customerId,
    required List<SaleLineInput> items,
    required double paidAmount,
    double discount = 0,
    String paymentType = 'cash',
    String? paymentReference,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }

    final normalizedPaymentType = paymentType.trim().toLowerCase();
    if (normalizedPaymentType.isEmpty) {
      throw ArgumentError('Payment type is required.');
    }
    if (!kAllowedPaymentTypes.contains(normalizedPaymentType)) {
      throw ArgumentError(
        'Unsupported payment type "$paymentType". '
        'Allowed: ${kAllowedPaymentTypes.join(', ')}.',
      );
    }

    if (discount < 0) {
      throw ArgumentError('Sale discount cannot be negative.');
    }

    if (paidAmount < 0) {
      throw ArgumentError('Paid amount cannot be negative.');
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
    final paid = Money.round(paidAmount);

    if (paid > total) {
      throw ArgumentError('Paid amount cannot exceed the sale total.');
    }

    final balance = Money.round(total - paid);

    if (balance > 0 && (customerId == null || customerId.trim().isEmpty)) {
      throw ArgumentError(
        'A customer is required when a sale has an outstanding balance.',
      );
    }

    final saleId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final db = await _database.database;

    await db.transaction((txn) async {
      // Stock checks only for catalogue products.
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

        final currentStock = (result.first['stock'] as num?)?.toDouble() ?? 0;

        if (currentStock < item.quantity) {
          throw StateError(
            'Insufficient stock for ${item.productName}. '
            'Available: ${_formatNumber(currentStock)}, '
            'requested: ${_formatNumber(item.quantity)}.',
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

      if (paid > 0) {
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'customer_id': customerId,
          'payment_type': normalizedPaymentType,
          'amount': paid,
          'reference': paymentReference?.trim(),
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

      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'sale_created',
        'entity_type': 'sale',
        'entity_id': saleId,
        'new_value':
            'total=$total, paid=$paid, balance=$balance, '
            'payment_type=$normalizedPaymentType',
        'reason': 'Sale completed',
        'created_at': now,
      });
    });

    return saleId;
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

  String _paymentStatus({
    required double paid,
    required double balance,
  }) {
    if (balance == 0) {
      return 'paid';
    }
    if (paid > 0) {
      return 'partially_paid';
    }
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
  /// Null for quick-sale (non-catalogue) lines — no stock impact.
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

  double get total {
    return Money.round((quantity * unitPrice) - discount);
  }
}
