import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';

/// Configurable business policies (safeguards).
class PolicyService {
  PolicyService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const allowNegativeStock = 'policy_allow_negative_stock';
  static const largeDiscountPercent = 'policy_large_discount_percent';
  static const blockOverdueCredit = 'policy_block_overdue_credit';
  static const largeRefundAmount = 'policy_large_refund_amount';

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

  /// Refunds at or above this amount (KES) show a stronger warning. Default 5000.
  Future<double> getLargeRefundAmount() async {
    final raw = await _get(largeRefundAmount);
    return double.tryParse(raw ?? '') ?? 5000;
  }

  Future<void> setLargeRefundAmount(double value) async {
    await _set(largeRefundAmount, value.toString());
  }

  Future<String?> _get(String key) async {
    final db = await _database.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    final db = await _database.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
