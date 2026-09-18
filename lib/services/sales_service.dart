import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class SalesService {
  SalesService({
    AppDatabase? database,
    Uuid? uuid,
  })  : _database = database ?? AppDatabase.instance,
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

    final saleId = _uuid.v4();

    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    final total = subtotal - discount;

    if (total < 0) {
      throw ArgumentError('Sale total cannot be negative.');
    }

    if (paidAmount < 0 || paidAmount > total) {
      throw ArgumentError('Invalid paid amount.');
    }

    final balance = total - paidAmount;

    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.insert('sales', {
        'id': saleId,
        'customer_id': customerId,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paid_amount': paidAmount,
        'balance': balance,
        'payment_status': balance == 0
            ? 'paid'
            : paidAmount > 0
                ? 'partially_paid'
                : 'unpaid',
        'sale_status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
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
          'reference_id': saleId,
          'reason': 'Sale completed',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (paidAmount > 0) {
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'customer_id': customerId,
          'payment_type': paymentType,
          'amount': paidAmount,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (balance > 0 && customerId != null) {
        await txn.insert('debtor_transactions', {
          'id': _uuid.v4(),
          'customer_id': customerId,
          'sale_id': saleId,
          'transaction_type': 'credit_sale',
          'amount': balance,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    return saleId;
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

  double get total =>
      (quantity * unitPrice) - discount;
}
