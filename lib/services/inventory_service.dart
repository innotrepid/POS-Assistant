import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class InventoryService {
  InventoryService({
    AppDatabase? database,
    Uuid? uuid,
  })  : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

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

  Future<void> addStock({
    required String productId,
    required double quantity,
    double? unitCost,
    String? referenceId,
    String? reason,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock quantity must be greater than zero.');
    }

    final db = await _database.database;

    await db.insert('stock_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': 'purchase_received',
      'quantity': quantity,
      'unit_cost': unitCost,
      'reference_id': referenceId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeStock({
    required String productId,
    required double quantity,
    required String movementType,
    String? referenceId,
    String? reason,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock quantity must be greater than zero.');
    }

    final currentStock = await getStock(productId);

    if (currentStock < quantity) {
      throw StateError(
        'Insufficient stock. Available: $currentStock',
      );
    }

    final db = await _database.database;

    await db.insert('stock_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': movementType,
      'quantity': -quantity,
      'reference_id': referenceId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getMovements(
    String productId,
  ) async {
    final db = await _database.database;

    return db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
  }
}
