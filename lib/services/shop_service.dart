import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/database/shop_registry.dart';
import '../core/models/shop.dart';

/// Manages multi-shop isolation: registry + per-shop data files.
class ShopService {
  ShopService({
    ShopRegistry? registry,
    AppDatabase? database,
    Uuid? uuid,
  })  : _registry = registry ?? ShopRegistry.instance,
        _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final ShopRegistry _registry;
  final AppDatabase _database;
  final Uuid _uuid;

  /// Ensure a shop is active and its DB is open.
  ///
  /// - Migrates legacy single-file DBs into the first shop once.
  /// - Creates a default "My shop" if the registry is empty.
  Future<Shop> ensureActiveShop() async {
    await _migrateLegacySingleFileIfNeeded();

    final shops = await _registry.listShops();
    if (shops.isEmpty) {
      return createShop(name: 'My shop');
    }

    final activeId = await _registry.getActiveShopId();
    Shop? active;
    if (activeId != null) {
      active = await _registry.getShop(activeId);
    }
    active ??= shops.first;

    await switchToShop(active.id);
    return active;
  }

  Future<List<Shop>> listShops() => _registry.listShops();

  Future<Shop?> getActiveShop() async {
    final id = await _registry.getActiveShopId();
    if (id == null) return null;
    return _registry.getShop(id);
  }

  Future<Shop> createShop({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Shop name is required.');
    }

    final shop = Shop(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: DateTime.now(),
      lastOpenedAt: DateTime.now(),
    );

    await _registry.upsertShop(shop);
    await switchToShop(shop.id);

    // Seed shop name into the shop's own settings for dashboard display.
    try {
      final db = await _database.database;
      await db.insert(
        'settings',
        {'key': 'business_name', 'value': trimmed},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}

    return shop;
  }

  Future<void> renameShop(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Shop name is required.');
    }
    await _registry.renameShop(id, trimmed);

    // Keep in-shop business_name in sync when renaming the active shop.
    if (_database.shopId == id) {
      try {
        final db = await _database.database;
        await db.insert(
          'settings',
          {'key': 'business_name', 'value': trimmed},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
  }

  /// Switch active shop and reopen its database file.
  Future<void> switchToShop(String shopId) async {
    final shop = await _registry.getShop(shopId);
    if (shop == null) {
      throw StateError('Shop not found.');
    }

    await _database.openForShop(shopId);
    await _registry.setActiveShopId(shopId);
    await _registry.touchOpened(shopId);
  }

  /// Delete a shop and its data file. Cannot delete the last shop.
  Future<void> deleteShop(String shopId) async {
    final shops = await _registry.listShops();
    if (shops.length <= 1) {
      throw StateError('Cannot delete the only shop.');
    }

    final target = await _registry.getShop(shopId);
    if (target == null) {
      throw StateError('Shop not found.');
    }

    final wasActive = _database.shopId == shopId ||
        (await _registry.getActiveShopId()) == shopId;

    if (_database.shopId == shopId) {
      await _database.close();
    }

    // Remove data file.
    try {
      final dir = await getDatabasesPath();
      final file = File(join(dir, target.dbFileName));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    await _registry.deleteShop(shopId);

    if (wasActive) {
      final remaining = await _registry.listShops();
      if (remaining.isNotEmpty) {
        await switchToShop(remaining.first.id);
      }
    }
  }

  /// One-time: adopt legacy `mercate.db` / `pos_assistant.db` as the first shop.
  Future<void> _migrateLegacySingleFileIfNeeded() async {
    final existing = await _registry.listShops();
    if (existing.isNotEmpty) return;

    final dir = await getDatabasesPath();
    final candidates = [
      join(dir, 'mercate.db'),
      join(dir, 'pos_assistant.db'),
    ];

    File? legacy;
    for (final path in candidates) {
      final f = File(path);
      if (await f.exists()) {
        legacy = f;
        break;
      }
    }
    if (legacy == null) return;

    final shop = Shop(
      id: _uuid.v4(),
      name: 'My shop',
      createdAt: DateTime.now(),
      lastOpenedAt: DateTime.now(),
    );

    final dest = File(join(dir, shop.dbFileName));
    try {
      if (!await dest.exists()) {
        await legacy.rename(dest.path);
      }
    } catch (_) {
      // If rename fails, leave legacy in place; createShop path still works.
      return;
    }

    await _registry.upsertShop(shop);
    await _registry.setActiveShopId(shop.id);
  }
}
