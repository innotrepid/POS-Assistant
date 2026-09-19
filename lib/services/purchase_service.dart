import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

class PurchaseLineInput {
  final String productId;
  final String productName;
  final double quantity;
  final double unitCost;

  const PurchaseLineInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });

  double get total => Money.round(quantity * unitCost);
}

/// Receive stock from a supplier in one transaction.
class PurchaseService {
  PurchaseService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> createPurchase({
    required String supplierId,
    required List<PurchaseLineInput> items,
    required double paidAmount,
    String? reference,
    String paymentType = 'cash',
  }) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('Supplier is required.');
    }
    if (items.isEmpty) {
      throw ArgumentError('A purchase must contain at least one item.');
    }
    if (paidAmount < 0) {
      throw ArgumentError('Paid amount cannot be negative.');
    }

    for (final item in items) {
      if (item.productId.trim().isEmpty) {
        throw ArgumentError('Every purchase item needs a product ID.');
      }
      if (item.quantity <= 0) {
        throw ArgumentError(
          'Quantity for ${item.productName} must be greater than zero.',
        );
      }
      if (item.unitCost < 0) {
        throw ArgumentError(
          'Cost for ${item.productName} cannot be negative.',
        );
      }
    }

    final subtotal = Money.round(
      items.fold<double>(0, (sum, i) => sum + i.total),
    );
    final paid = Money.round(paidAmount);
    if (paid > subtotal) {
      throw ArgumentError('Paid amount cannot exceed purchase total.');
    }
    final balance = Money.round(subtotal - paid);

    final purchaseId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.insert('purchases', {
        'id': purchaseId,
        'supplier_id': supplierId,
        'reference': reference?.trim(),
        'subtotal': subtotal,
        'paid_amount': paid,
        'balance': balance,
        'status': balance == 0 ? 'paid' : (paid > 0 ? 'partial' : 'unpaid'),
        'created_at': now,
      });

      for (final item in items) {
        final lineTotal = item.total;
        final unitCost = Money.round(item.unitCost);

        await txn.insert('purchase_items', {
          'id': _uuid.v4(),
          'purchase_id': purchaseId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_cost': unitCost,
          'total': lineTotal,
        });

        // Weighted average cost update
        await _updateWac(
          txn: txn,
          productId: item.productId,
          incomingQty: item.quantity,
          purchaseUnitCost: unitCost,
        );

        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'product_id': item.productId,
          'movement_type': 'purchase_received',
          'quantity': item.quantity,
          'unit_cost': unitCost,
          'reference_id': purchaseId,
          'reason': 'Purchase received',
          'created_at': now,
        });
      }

      if (paid > 0) {
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'supplier_id': supplierId,
          'payment_type': paymentType.trim().toLowerCase(),
          'amount': paid,
          'reference': reference?.trim(),
          'notes': 'Purchase payment',
          'created_at': now,
        });
      }

      if (balance > 0) {
        await txn.insert('creditor_transactions', {
          'id': _uuid.v4(),
          'supplier_id': supplierId,
          'purchase_id': purchaseId,
          'transaction_type': 'purchase',
          'amount': balance,
          'reference': reference?.trim(),
          'created_at': now,
        });
      }

      await txn.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': 'purchase_created',
        'entity_type': 'purchase',
        'entity_id': purchaseId,
        'new_value': 'total=$subtotal, paid=$paid, balance=$balance',
        'reason': 'Goods received',
        'created_at': now,
      });
    });

    return purchaseId;
  }

  Future<List<Map<String, dynamic>>> listPurchases({int limit = 50}) async {
    final db = await _database.database;
    return db.query(
      'purchases',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> _updateWac({
    required dynamic txn,
    required String productId,
    required double incomingQty,
    required double purchaseUnitCost,
  }) async {
    final stockResult = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(quantity), 0) AS stock
      FROM stock_movements
      WHERE product_id = ?
      ''',
      [productId],
    );
    final currentStock =
        (stockResult.first['stock'] as num?)?.toDouble() ?? 0;

    final productResult = await txn.query(
      'products',
      columns: ['cost_price'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    final currentAvg = productResult.isEmpty
        ? 0.0
        : (productResult.first['cost_price'] as num?)?.toDouble() ?? 0.0;

    final double newAvg;
    if (currentStock <= 0) {
      newAvg = purchaseUnitCost;
    } else {
      final totalValue =
          (currentStock * currentAvg) + (incomingQty * purchaseUnitCost);
      newAvg = totalValue / (currentStock + incomingQty);
    }

    await txn.update(
      'products',
      {
        'cost_price': Money.round(newAvg),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }
}
