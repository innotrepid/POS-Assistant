import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/shop.dart';

/// Lightweight registry of shops and the currently active shop id.
///
/// Lives in [mercate_registry.db], separate from each shop's data file.
class ShopRegistry {
  ShopRegistry._();

  static final ShopRegistry instance = ShopRegistry._();

  Database? _db;

  static const String registryFileName = 'mercate_registry.db';
  static const int schemaVersion = 1;
  static const String _kActiveShopId = 'active_shop_id';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, registryFileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shops (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_opened_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  Future<List<Shop>> listShops() async {
    final db = await database;
    final rows = await db.query('shops', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Shop.fromMap).toList();
  }

  Future<Shop?> getShop(String id) async {
    final db = await database;
    final rows = await db.query(
      'shops',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shop.fromMap(rows.first);
  }

  Future<void> upsertShop(Shop shop) async {
    final db = await database;
    await db.insert(
      'shops',
      shop.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> renameShop(String id, String name) async {
    final db = await database;
    await db.update(
      'shops',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> touchOpened(String id) async {
    final db = await database;
    await db.update(
      'shops',
      {'last_opened_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteShop(String id) async {
    final db = await database;
    await db.delete('shops', where: 'id = ?', whereArgs: [id]);
    final active = await getActiveShopId();
    if (active == id) {
      await setActiveShopId(null);
    }
  }

  Future<String?> getActiveShopId() async {
    final db = await database;
    final rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [_kActiveShopId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['value'] as String?;
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setActiveShopId(String? id) async {
    final db = await database;
    if (id == null || id.isEmpty) {
      await db.delete('meta', where: 'key = ?', whereArgs: [_kActiveShopId]);
      return;
    }
    await db.insert(
      'meta',
      {'key': _kActiveShopId, 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
