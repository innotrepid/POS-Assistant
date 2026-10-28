import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/product.dart';
import '../core/utils/money.dart';
import 'expense_service.dart';

/// Common spoilage reasons for produce stalls (Kenya).
const List<String> kSpoilageReasons = [
  'Rotten / bad',
  'Overripe',
  'Damaged in transport',
  'Dried out / wilted',
  'Eaten / taken home',
  'Other',
];

class SpoilageDaySummary {
  final double quantityUnits;
  final double estimatedCost;
  final int eventCount;

  const SpoilageDaySummary({
    required this.quantityUnits,
    required this.estimatedCost,
    required this.eventCount,
  });

  static const empty = SpoilageDaySummary(
    quantityUnits: 0,
    estimatedCost: 0,
    eventCount: 0,
  );
}

class InventoryService {
  InventoryService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  // ============================================================
  // PRODUCT CRUD
  // ============================================================

  Future<Product> createProduct({
    required String name,
    String? alternativeName,
    String? sku,
    String? barcode,
    String? categoryId,
    String? brand,
    String unit = 'piece',
    required double sellingPrice,
    double? costPrice,
    double? wholesalePrice,
    double minimumStock = 0,
    double reorderQuantity = 0,
    String? supplierId,
    String? imagePath,
    String? notes,
    bool trackBatches = false,
    bool hasExpiry = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Product name is required.');
    }
    if (sellingPrice < 0) {
      throw ArgumentError('Selling price cannot be negative.');
    }

    final now = DateTime.now();
    final product = Product(
      id: _uuid.v4(),
      name: name.trim(),
      alternativeName: alternativeName?.trim(),
      sku: sku?.trim(),
      barcode: barcode?.trim(),
      categoryId: categoryId,
      brand: brand?.trim(),
      unit: unit,
      sellingPrice: Money.round(sellingPrice),
      costPrice: costPrice != null ? Money.round(costPrice) : null,
      wholesalePrice:
          wholesalePrice != null ? Money.round(wholesalePrice) : null,
      minimumStock: minimumStock,
      reorderQuantity: reorderQuantity,
      supplierId: supplierId,
      imagePath: imagePath,
      notes: notes?.trim(),
      active: true,
      trackBatches: trackBatches,
      hasExpiry: hasExpiry,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _database.database;
    await db.insert('products', product.toMap());

    await _writeAudit(
      action: 'product_created',
      entityType: 'product',
      entityId: product.id,
      newValue: 'name=${product.name}, selling_price=${product.sellingPrice}',
    );

    return product;
  }

  Future<Product?> getProduct(String id) async {
    final db = await _database.database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await _database.database;
    final maps = await db.query(
      'products',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await _database.database;
    final q = '%${query.trim()}%';
    final maps = await db.query(
      'products',
      where: 'active = 1 AND '
          '(name LIKE ? OR alternative_name LIKE ? OR barcode LIKE ? OR sku LIKE ?)',
      whereArgs: [q, q, q, q],
      orderBy: 'name ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<void> updateProduct(Product product) async {
    final db = await _database.database;
    final updated = product.copyWith(updatedAt: DateTime.now());
    await db.update(
      'products',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );

    await _writeAudit(
      action: 'product_updated',
      entityType: 'product',
      entityId: product.id,
      newValue: 'name=${updated.name}',
    );
  }

  Future<void> softDeleteProduct(String productId) async {
    final db = await _database.database;
    await db.update(
      'products',
      {
        'active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );

    await _writeAudit(
      action: 'product_deactivated',
      entityType: 'product',
      entityId: productId,
    );
  }

  // ============================================================
  // STOCK (always calculated live)
  // ============================================================

  Future<double> getStock(String productId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(quantity), 0) AS stock
      FROM stock_movements
      WHERE product_id = ?
      ''',
      [productId],
    );
    return (result.first['stock'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getMovements(String productId) async {
    final db = await _database.database;
    return db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
  }

  /// Opening stock or goods received.
  /// Also updates Weighted Average Cost when unitCost is provided.
  Future<void> addStock({
    required String productId,
    required double quantity,
    double? unitCost,
    String movementType = 'purchase_received',
    String? referenceId,
    String? reason,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero.');
    }

    final db = await _database.database;

    await db.transaction((txn) async {
      if (unitCost != null && unitCost >= 0) {
        await _updateWeightedAverageCost(
          txn: txn,
          productId: productId,
          incomingQuantity: quantity,
          purchaseUnitCost: unitCost,
        );
      }

      await txn.insert('stock_movements', {
        'id': _uuid.v4(),
        'product_id': productId,
        'movement_type': movementType,
        'quantity': quantity,
        'unit_cost': unitCost,
        'reference_id': referenceId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await _writeAudit(
      action: 'stock_added',
      entityType: 'product',
      entityId: productId,
      newValue: 'qty=$quantity, type=$movementType',
      reason: reason,
    );
  }

  /// Mama mboga / duka restock after market trip — no supplier required.
  Future<void> restockBoughtToday({
    required String productId,
    required double quantity,
    double? unitCost,
    String? note,
  }) async {
    final reason = (note == null || note.trim().isEmpty)
        ? 'Bought today'
        : 'Bought today: ${note.trim()}';
    await addStock(
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      movementType: 'market_restock',
      reason: reason,
    );
  }

  /// Remove stock (sale, damage, expiry, adjustment, etc.)
  Future<void> removeStock({
    required String productId,
    required double quantity,
    required String movementType,
    String? referenceId,
    String? reason,
    double? unitCost,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero.');
    }

    final currentStock = await getStock(productId);
    if (currentStock < quantity) {
      throw StateError(
        'Insufficient stock. Available: $currentStock, requested: $quantity',
      );
    }

    final db = await _database.database;

    await db.insert('stock_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': movementType,
      'quantity': -quantity,
      'unit_cost': unitCost,
      'reference_id': referenceId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _writeAudit(
           action: 'stock_removed',
      entityType: 'product',
      entityId: productId,
      newValue: 'qty=$quantity, type=$movementType',
      reason: reason,
    );
  }

  /// Record produce that went bad — reduces stock and logs reason.
  Future<void> recordSpoilage({
    required String productId,
    required double quantity,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) {
      throw ArgumentError('A spoilage reason is required.');
    }

    final product = await getProduct(productId);
    final unitCost = product?.costPrice;

    await removeStock(
      productId: productId,
      quantity: quantity,
      movementType: 'spoilage',
      reason: why,
      unitCost: unitCost,
    );
  }

  /// Spoilage for a calendar day: event count, total qty, estimated cost lost.
  Future<SpoilageDaySummary> getSpoilageSummary(DateTime day) async {
    final range = DayRange.of(day);
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS events,
        COALESCE(SUM(ABS(quantity)), 0) AS qty,
        COALESCE(SUM(ABS(quantity) * COALESCE(unit_cost, 0)), 0) AS cost
      FROM stock_movements
      WHERE movement_type = 'spoilage'
        AND created_at >= ? AND created_at < ?
      ''',
      [range.startIso, range.endIso],
    );
    if (rows.isEmpty) return SpoilageDaySummary.empty;
    return SpoilageDaySummary(
      quantityUnits:
          (rows.first['qty'] as num?)?.toDouble() ?? 0,
      estimatedCost: Money.round(
        (rows.first['cost'] as num?)?.toDouble() ?? 0,
      ),
      eventCount: (rows.first['events'] as int?) ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> listSpoilage({
    DateTime? day,
    int limit = 50,
  }) async {
    final db = await _database.database;
    if (day != null) {
      final range = DayRange.of(day);
      return db.rawQuery(
        '''
        SELECT m.*, p.name AS product_name, p.unit AS product_unit
        FROM stock_movements m
        LEFT JOIN products p ON p.id = m.product_id
        WHERE m.movement_type = 'spoilage'
          AND m.created_at >= ? AND m.created_at < ?
        ORDER BY m.created_at DESC
        LIMIT ?
        ''',
        [range.startIso, range.endIso, limit],
      );
    }
    return db.rawQuery(
      '''
      SELECT m.*, p.name AS product_name, p.unit AS product_unit
      FROM stock_movements m
      LEFT JOIN products p ON p.id = m.product_id
      WHERE m.movement_type = 'spoilage'
      ORDER BY m.created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  /// Manual adjustment (stock count correction)
  Future<void> adjustStock({
    required String productId,
    required double newQuantity,
    required String reason,
  }) async {
    final current = await getStock(productId);
    final difference = newQuantity - current;

    if (difference == 0) return;

    if (difference > 0) {
      await addStock(
        productId: productId,
        quantity: difference,
        movementType: 'adjustment',
        reason: reason,
      );
    } else {
      await removeStock(
        productId: productId,
        quantity: -difference,
        movementType: 'adjustment',
        reason: reason,
      );
    }
  }

  // ============================================================
  // WEIGHTED AVERAGE COST
  // ============================================================

  Future<void> _updateWeightedAverageCost({
    required dynamic txn,
    required String productId,
    required double incomingQuantity,
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

    double newAvg;

    if (currentStock <= 0) {
      newAvg = purchaseUnitCost;
    } else {
      final totalValue =
          (currentStock * currentAvg) + (incomingQuantity * purchaseUnitCost);
      final totalQty = currentStock + incomingQuantity;
      newAvg = totalValue / totalQty;
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

  // ============================================================
  // HELPERS
  // ============================================================

  Future<List<Product>> getLowStockProducts() async {
    final products = await getAllProducts(activeOnly: true);
    final lowStock = <Product>[];

    for (final product in products) {
      final stock = await getStock(product.id);
      if (stock <= product.minimumStock) {
        lowStock.add(product);
      }
    }
    return lowStock;
  }

  Future<void> _writeAudit({
    required String action,
    required String entityType,
    required String entityId,
    String? newValue,
    String? reason,
  }) async {
    final db = await _database.database;
    await db.insert('audit_logs', {
      'id': _uuid.v4(),
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'new_value': newValue,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
