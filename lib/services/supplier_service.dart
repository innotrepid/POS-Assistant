import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/supplier.dart';

class SupplierService {
  SupplierService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? location,
    String? notes,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Supplier name is required.');
    }

    final now = DateTime.now();
    final supplier = Supplier(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone?.trim(),
      email: email?.trim(),
      location: location?.trim(),
      notes: notes?.trim(),
      active: true,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _database.database;
    await db.insert('suppliers', supplier.toMap());
    return supplier;
  }

  Future<Supplier?> getSupplier(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  Future<List<Supplier>> getAllSuppliers({bool activeOnly = true}) async {
    final db = await _database.database;
    final rows = await db.query(
      'suppliers',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Supplier.fromMap).toList();
  }

  Future<List<Supplier>> searchSuppliers(String query) async {
    final db = await _database.database;
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'suppliers',
      where: 'active = 1 AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: [q, q],
      orderBy: 'name ASC',
    );
    return rows.map(Supplier.fromMap).toList();
  }
}
