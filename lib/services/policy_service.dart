import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';

/// Configurable business policies (safeguards) — stored in the **profile** DB
/// so each shop type can have its own rules.
class PolicyService {
  PolicyService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const allowNegativeStock = 'policy_allow_negative_stock';
  static const largeDiscountPercent = 'policy_large_discount_percent';
  static const blockOverdueCredit = 'policy_block_overdue_credit';
  static const largeRefundAmount = 'policy_large_refund_amount';
  static const overdueDebtDays = 'policy_overdue_debt_days';
  static const requireUnitPick = 'policy_require_unit_pick';

  Future<Database> _db() async {
    final db = await _database.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    return db;
  }

  Future<bool> getAllowNegativeStock() async {
    return (await _get(allowNegativeStock)) == '1';
  }

  Future<void> setAllowNegativeStock(bool value) async {
    await _set(allowNegativeStock, value ? '1' : '0');
  }

  Future<double> getLargeDiscountPercent() async {
    final raw = await _get(largeDiscountPercent);
    return double.tryParse(raw ?? '') ?? 20;
  }

  Future<void> setLargeDiscountPercent(double value) async {
    await _set(largeDiscountPercent, value.toString());
  }

  Future<bool> getBlockOverdueCredit() async {
    return (await _get(blockOverdueCredit)) == '1';
  }

  Future<void> setBlockOverdueCredit(bool value) async {
    await _set(blockOverdueCredit, value ? '1' : '0');
  }

  Future<double> getLargeRefundAmount() async {
    final raw = await _get(largeRefundAmount);
    return double.tryParse(raw ?? '') ?? 5000;
  }

  Future<void> setLargeRefundAmount(double value) async {
    await _set(largeRefundAmount, value.toString());
  }

  /// Open credit older than this many days counts as overdue. Default 30.
  Future<int> getOverdueDebtDays() async {
    final raw = await _get(overdueDebtDays);
    return int.tryParse(raw ?? '') ?? 30;
  }

  Future<void> setOverdueDebtDays(int days) async {
    final d = days < 1 ? 1 : days;
    await _set(overdueDebtDays, d.toString());
  }

  /// When true, POS always shows the unit picker (even if only one unit).
  Future<bool> getRequireUnitPick() async {
    return (await _get(requireUnitPick)) == '1';
  }

  Future<void> setRequireUnitPick(bool value) async {
    await _set(requireUnitPick, value ? '1' : '0');
  }

  Future<String?> _get(String key) async {
    try {
      final db = await _db();
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _set(String key, String value) async {
    final db = await _db();
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
