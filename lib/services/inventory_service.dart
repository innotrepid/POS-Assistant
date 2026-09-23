import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/product.dart';
import '../core/models/product_unit.dart';
import '../core/utils/money.dart';

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
    await db.transaction((txn) async {
      await txn.insert('products', product.toMap());
      // Default selling unit = base unit (conversion 1).
      await txn.insert('product_units', {
        'id': '${product.id}_default',
        'product_id': product.id,
        'unit_name': product.unit,
        'conversion_to_base': 1.0,
        'selling_price': product.sellingPrice,
        'is_default': 1,
        'barcode': product.barcode,
        'sort_order': 0,
        'created_at': now.toIso8601String(),
      });
    });

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

  Future<void> deactivateProduct(String id) async {
    final db = await _database.database;
    await db.update(
      'products',
      {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _writeAudit(
      action: 'product_deactivated',
      entityType: 'product',
      entityId: id,
    );
  }

  // ============================================================
  // PRODUCT UNITS (multi-UoM)
  // ============================================================

  /// All selling units for a product, default first then sort_order.
  Future<List<ProductUnit>> getUnits(String productId) async {
    final db = await _database.database;
    final maps = await db.query(
      'product_units',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'is_default DESC, sort_order ASC, unit_name ASC',
    );
    return maps.map(ProductUnit.fromMap).toList();
  }

  Future<ProductUnit?> getUnit(String unitId) async {
    final db = await _database.database;
    final maps = await db.query(
      'product_units',
      where: 'id = ?',
      whereArgs: [unitId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProductUnit.fromMap(maps.first);
  }

  Future<ProductUnit?> getDefaultUnit(String productId) async {
    final db = await _database.database;
    final maps = await db.query(
      'product_units',
      where: 'product_id = ? AND is_default = 1',
      whereArgs: [productId],
      limit: 1,
    );
    if (maps.isNotEmpty) return ProductUnit.fromMap(maps.first);

    final any = await db.query(
      'product_units',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'sort_order ASC',
      limit: 1,
    );
    if (any.isNotEmpty) return ProductUnit.fromMap(any.first);
    return null;
  }

  /// Ensures at least one unit row exists (base unit, conversion 1).
  /// Useful for products created before schema v9.
  Future<ProductUnit> ensureDefaultUnit(String productId) async {
    final existing = await getDefaultUnit(productId);
    if (existing != null) return existing;

    final product = await getProduct(productId);
    if (product == null) {
      throw StateError('Product not found: $productId');
    }

    return addUnit(
      productId: productId,
      unitName: product.unit,
      conversionToBase: 1.0,
      sellingPrice: product.sellingPrice,
      isDefault: true,
      barcode: product.barcode,
      unitId: '${productId}_default',
    );
  }

  Future<ProductUnit> addUnit({
    required String productId,
    required String unitName,
    required double conversionToBase,
    required double sellingPrice,
    bool isDefault = false,
    String? barcode,
    int sortOrder = 0,
    String? unitId,
  }) async {
    final name = unitName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Unit name is required.');
    }
    if (conversionToBase <= 0) {
      throw ArgumentError('conversionToBase must be greater than zero.');
    }
    if (sellingPrice < 0) {
      throw ArgumentError('Selling price cannot be negative.');
    }

    final product = await getProduct(productId);
    if (product == null) {
      throw StateError('Product not found: $productId');
    }

    final now = DateTime.now();
    final unit = ProductUnit(
      id: unitId ?? _uuid.v4(),
      productId: productId,
      unitName: name,
      conversionToBase: conversionToBase,
      sellingPrice: Money.round(sellingPrice),
      isDefault: isDefault,
      barcode: barcode?.trim(),
      sortOrder: sortOrder,
      createdAt: now,
    );

    final db = await _database.database;
    await db.transaction((txn) async {
      if (isDefault) {
        await txn.update(
          'product_units',
          {'is_default': 0},
          where: 'product_id = ?',
          whereArgs: [productId],
        );
      }
      await txn.insert('product_units', unit.toMap());

      // Sync catalogue list price only. products.unit is the *base stock*
      // unit and must not change when an alternate selling unit is defaulted
      // (e.g. kg with conversion 10) or stock labels become wrong.
      if (isDefault) {
        await txn.update(
          'products',
          {
            'selling_price': unit.sellingPrice,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [productId],
        );
      }
    });

    await _writeAudit(
      action: 'product_unit_added',
      entityType: 'product_unit',
      entityId: unit.id,
      newValue:
          'product=$productId, unit=$name, conv=$conversionToBase, price=${unit.sellingPrice}',
    );

    return unit;
  }

  Future<void> updateUnit(ProductUnit unit) async {
    if (unit.unitName.trim().isEmpty) {
      throw ArgumentError('Unit name is required.');
    }
    if (unit.conversionToBase <= 0) {
      throw ArgumentError('conversionToBase must be greater than zero.');
    }
    if (unit.sellingPrice < 0) {
      throw ArgumentError('Selling price cannot be negative.');
    }

    final updated = unit.copyWith(
      unitName: unit.unitName.trim(),
      sellingPrice: Money.round(unit.sellingPrice),
    );

    final db = await _database.database;
    await db.transaction((txn) async {
      if (updated.isDefault) {
        await txn.update(
          'product_units',
          {'is_default': 0},
          where: 'product_id = ? AND id != ?',
          whereArgs: [updated.productId, updated.id],
        );
      }

      await txn.update(
        'product_units',
        {
          'unit_name': updated.unitName,
          'conversion_to_base': updated.conversionToBase,
          'selling_price': updated.sellingPrice,
          'is_default': updated.isDefault ? 1 : 0,
          'barcode': updated.barcode,
          'sort_order': updated.sortOrder,
        },
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      if (updated.isDefault) {
        await txn.update(
          'products',
          {
            'selling_price': updated.sellingPrice,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [updated.productId],
        );
      }
    });

    await _writeAudit(
      action: 'product_unit_updated',
      entityType: 'product_unit',
      entityId: updated.id,
      newValue:
          'unit=${updated.unitName}, conv=${updated.conversionToBase}, price=${updated.sellingPrice}',
    );
  }

  /// Deletes a non-default unit. Cannot remove the last unit for a product.
  Future<void> deleteUnit(String unitId) async {
    final unit = await getUnit(unitId);
    if (unit == null) {
      throw StateError('Unit not found: $unitId');
    }

    final units = await getUnits(unit.productId);
    if (units.length <= 1) {
      throw StateError('Cannot delete the only unit for a product.');
    }
    if (unit.isDefault) {
      throw StateError(
        'Cannot delete the default unit. Set another unit as default first.',
      );
    }

    final db = await _database.database;
    await db.delete(
      'product_units',
      where: 'id = ?',
      whereArgs: [unitId],
    );

    await _writeAudit(
      action: 'product_unit_deleted',
      entityType: 'product_unit',
      entityId: unitId,
      newValue: 'product=${unit.productId}, unit=${unit.unitName}',
    );
  }

  Future<void> setDefaultUnit(String unitId) async {
    final unit = await getUnit(unitId);
    if (unit == null) {
      throw StateError('Unit not found: $unitId');
    }
    if (unit.isDefault) return;

    await updateUnit(unit.copyWith(isDefault: true));
  }

  /// Convert a quantity sold in [unit] to base stock quantity.
  double toBaseQuantity(ProductUnit unit, double soldQuantity) =>
      unit.toBaseQuantity(soldQuantity);

  /// Convert base stock quantity to quantity in [unit].
  double fromBaseQuantity(ProductUnit unit, double baseQuantity) =>
      unit.fromBaseQuantity(baseQuantity);

  /// Resolve unit by name for a product (case-insensitive).
  Future<ProductUnit?> findUnitByName(String productId, String unitName) async {
    final name = unitName.trim().toLowerCase();
    if (name.isEmpty) return null;
    final units = await getUnits(productId);
    for (final u in units) {
      if (u.unitName.toLowerCase() == name) return u;
    }
    return null;
  }

  // ============================================================
  // STOCK
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

  Future<List<Map<String, dynamic>>> getStockMovements(
    String productId, {
    int limit = 50,
  }) async {
    final db = await _database.database;
    return db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

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

  /// Manual adjustment (stock count correction). Reason is required for audit.
  Future<void> adjustStock({
    required String productId,
    required double newQuantity,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) {
      throw ArgumentError('A reason is required for stock adjustments.');
    }
    if (newQuantity < 0) {
      throw ArgumentError('Counted quantity cannot be negative.');
    }

    final current = await getStock(productId);
    final difference = Money.round(newQuantity - current);

    if (difference == 0) return;

    if (difference > 0) {
      await addStock(
        productId: productId,
        quantity: difference,
        movementType: 'adjustment',
        reason: why,
      );
    } else {
      await removeStock(
        productId: productId,
        quantity: -difference,
        movementType: 'adjustment',
        reason: why,
      );
    }

    await _writeAudit(
      action: 'stock_adjusted',
      entityType: 'product',
      entityId: productId,
      newValue: 'from=$current to=$newQuantity (diff=$difference)',
      reason: why,
    );
  }

  /// Apply a stocktake: set each product to its counted quantity.
  /// Returns how many products changed.
  Future<int> applyStocktake({
    required Map<String, double> countedByProductId,
    required String reason,
  }) async {
    final why = reason.trim().isEmpty
        ? 'Stocktake ${DateTime.now().toIso8601String().substring(0, 10)}'
        : reason.trim();

    var changed = 0;
    for (final entry in countedByProductId.entries) {
      final productId = entry.key;
      final counted = Money.round(entry.value);
      if (counted < 0) {
        throw ArgumentError('Counted quantity cannot be negative.');
      }
      final current = await getStock(productId);
      if (Money.round(current - counted) == 0) continue;
      await adjustStock(
        productId: productId,
        newQuantity: counted,
        reason: why,
      );
      changed++;
    }

    if (changed > 0) {
      await _writeAudit(
        action: 'stocktake_completed',
        entityType: 'stocktake',
        entityId: _uuid.v4(),
        newValue: 'products_changed=$changed',
        reason: why,
      );
    }
    return changed;
  }

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

    final double newAvg;

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

  Future<void> _writeAudit({
    required String action,
    required String entityType,
    String? entityId,
    String? oldValue,
    String? newValue,
    String? reason,
  }) async {
    try {
      final db = await _database.database;
      await db.insert('audit_logs', {
        'id': _uuid.v4(),
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Audit must never break the main path.
    }
  }
}
