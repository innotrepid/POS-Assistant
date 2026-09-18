import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class SalesService {
  SalesService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> createSale({
    String? customerId,
    required List<SaleLineInput> items,
    required double paidAmount,
    double discount = 0,
    String paymentType = 'cash',
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }

    if (discount < 0) {
      throw ArgumentError('Sale discount cannot be negative.');
    }

    if (paidAmount < 0) {
      throw ArgumentError('Paid amount cannot be negative.');
    }

    if (paymentType.trim().isEmpty) {
      throw ArgumentError('Payment type is required.');
    }

    for (final item in items) {
      if (item.productId.trim().isEmpty) {
        throw ArgumentError('Every sale item must have a product ID.');
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

      if (item.discount > item.quantity * item.unitPrice) {
        throw ArgumentError(
          'Discount for ${item.productName} cannot exceed the line value.',
        );
      }
    }

    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    if (discount > subtotal) {
      throw ArgumentError('Sale discount cannot exceed the subtotal.');
    }

    final total = subtotal - discount;

    if (paidAmount > total) {
      throw ArgumentError('Paid amount cannot exceed the sale total.');
    }

    final balance = total - paidAmount;

    // A credit balance must belong to a customer.
    if (balance > 0 && customerId == null) {
      throw ArgumentError(
        'A customer is required when a sale has an outstanding balance.',
      );
    }

    final saleId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final db = await _database.database;

    await db.transaction((txn) async {
      // Validate all stock before writing anything.
      // Because this happens inside the same transaction as the writes,
      // a failed stock check rolls back the entire sale.
      for (final item in items) {
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
        'discount': discount,
        'total': total,
        'paid_amount': paidAmount,
        'balance': balance,
        'payment_status': _paymentStatus(
          total: total,
          paidAmount: paidAmount,
          balance: balance,
        ),
        'sale_status': 'completed',
        'created_at': now,
      });

      for (final item in items) {
        await txn.insert('sale_items', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost': item.unitCost,
          'discount': item.discount,
          'total': item.total,
        });

        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'product_id': item.productId,
          'movement_type': 'sale',
          'quantity': -item.quantity,
          'unit_cost': item.unitCost,
          'reference_id': saleId,
          'reason': 'Sale completed',
          'created_at': now,
        });
      }

      if (paidAmount > 0) {
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'customer_id': customerId,
          'payment_type': paymentType,
          'amount': paidAmount,
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
        'new_value': 'total=$total, paid=$paidAmount, balance=$balance',
        'reason': 'Sale completed',
        'created_at': now,
      });
    });

    return saleId;
  }

  String _paymentStatus({
    required double total,
    required double paidAmount,
    required double balance,
  }) {
    if (balance == 0) {
      return 'paid';
    }

    if (paidAmount > 0) {
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
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double? unitCost;
  final double discount;

  const SaleLineInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
    this.discount = 0,
  });

  double get total {
    return (quantity * unitPrice) - discount;
  }
}
