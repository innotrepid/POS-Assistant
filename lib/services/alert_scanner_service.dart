import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'notification_service.dart';
import 'policy_service.dart';

/// Scans stock and debt; writes in-app notifications only (no system tray).
class AlertScannerService {
  AlertScannerService({
    InventoryService? inventory,
    DebtorService? debtors,
    NotificationService? notifications,
    PolicyService? policy,
    AppDatabase? database,
  })  : _inventory = inventory ?? InventoryService(),
        _debtors = debtors ?? DebtorService(),
        _notifications = notifications ?? NotificationService(),
        _policy = policy ?? PolicyService(),
        _database = database ?? AppDatabase.instance;

  final InventoryService _inventory;
  final DebtorService _debtors;
  final NotificationService _notifications;
  final PolicyService _policy;
  final AppDatabase _database;

  Future<int> scan() async {
    var created = 0;
    created += await _scanStock();
    created += await _scanDebt();
    return created;
  }

  Future<int> _scanStock() async {
    var created = 0;
    final products = await _inventory.getAllProducts(activeOnly: true);

    for (final product in products) {
      final stock = await _inventory.getStock(product.id);
      final min = product.minimumStock;

      final outKey = 'stock_out_${product.id}';
      final lowKey = 'stock_low_${product.id}';

      if (stock <= 0) {
        final isNew = await _notifications.pushIfNew(
          category: 'inventory',
          priority: 'critical',
          title: 'Out of stock',
          body: '${product.name} has no stock left.',
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: outKey,
        );
        if (isNew) created++;
        await _notifications.markReadByDedupeKey(lowKey);
      } else if (min > 0 && stock <= min) {
        final isNew = await _notifications.pushIfNew(
          category: 'inventory',
          priority: 'warning',
          title: 'Low stock',
          body:
              '${product.name}: $stock left (minimum ${_fmt(min)}).',
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: lowKey,
        );
        if (isNew) created++;
        await _notifications.markReadByDedupeKey(outKey);
      } else {
        await _notifications.markReadByDedupeKey(outKey);
        await _notifications.markReadByDedupeKey(lowKey);
      }
    }

    return created;
  }

  Future<int> _scanDebt() async {
    var created = 0;
    final overdueDays = await _policy.getOverdueDebtDays();
    final list = await _debtors.listOutstanding(limit: 50);
    final db = await _database.database;

    for (final d in list) {
      if (d.balance <= 0.001) continue;

      final open = await db.query(
        'sales',
        where:
            "customer_id = ? AND balance > 0 AND sale_status = 'completed'",
        whereArgs: [d.customerId],
        orderBy: 'created_at ASC',
        limit: 1,
      );

      var daysOpen = 0;
      if (open.isNotEmpty) {
        final createdAt =
            DateTime.tryParse(open.first['created_at'] as String? ?? '');
        if (createdAt != null) {
          daysOpen = DateTime.now().difference(createdAt).inDays;
        }
      }

      final isOverdue = daysOpen >= overdueDays;
      final key = isOverdue
          ? 'debt_overdue_${d.customerId}'
          : 'debt_outstanding_${d.customerId}';

      if (isOverdue) {
        await _notifications.markReadByDedupeKey(
          'debt_outstanding_${d.customerId}',
        );
        final isNew = await _notifications.pushIfNew(
          category: 'debt',
          priority: 'warning',
          title: 'Overdue debt',
          body:
              '${d.customerName}: ${Money.format(d.balance)} '
              'open for $daysOpen days (limit $overdueDays).',
          deepLink: 'customers',
          entityType: 'customer',
          entityId: d.customerId,
          dedupeKey: key,
        );
        if (isNew) created++;
      } else {
        await _notifications.markReadByDedupeKey(
          'debt_overdue_${d.customerId}',
        );
        final isNew = await _notifications.pushIfNew(
          category: 'debt',
          priority: d.balance >= 5000 ? 'warning' : 'info',
          title: 'Customer owes you',
          body: '${d.customerName}: ${Money.format(d.balance)} outstanding.',
          deepLink: 'customers',
          entityType: 'customer',
          entityId: d.customerId,
          dedupeKey: key,
        );
        if (isNew) created++;
      }
    }

    return created;
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
