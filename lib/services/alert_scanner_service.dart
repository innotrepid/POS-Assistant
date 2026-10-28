import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'notification_service.dart';
import 'policy_service.dart';
import 'system_notification_service.dart';

/// Scans stock and debt; writes in-app notifications and system tray alerts.
class AlertScannerService {
  AlertScannerService({
    InventoryService? inventory,
    DebtorService? debtors,
    NotificationService? notifications,
    PolicyService? policy,
    AppDatabase? database,
    SystemNotificationService? systemNotifications,
  })  : _inventory = inventory ?? InventoryService(),
        _debtors = debtors ?? DebtorService(),
        _notifications = notifications ?? NotificationService(),
        _policy = policy ?? PolicyService(),
        _database = database ?? AppDatabase.instance,
        _system = systemNotifications ?? SystemNotificationService.instance;

  final InventoryService _inventory;
  final DebtorService _debtors;
  final NotificationService _notifications;
  final PolicyService _policy;
  final AppDatabase _database;
  final SystemNotificationService _system;

  Future<int> scan() async {
    // Ensure channels + permission (no-op if already granted).
    await _system.init(requestPermission: true);

    var created = 0;
    created += await _scanStock();
    created += await _scanDebt();
    return created;
  }

  Future<void> _tray({
    required String dedupeKey,
    required String title,
    required String body,
    required String category,
    required String priority,
  }) async {
    // Stable int id from dedupe key so updates replace prior tray alerts.
    final id = dedupeKey.hashCode & 0x7fffffff;
    await _system.show(
      id: id,
      title: title,
      body: body,
      category: category,
      priority: priority,
    );
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
        final title = 'Out of stock';
        final body = '${product.name} has no stock left.';
        final isNew = await _notifications.pushIfNew(
          category: 'inventory',
          priority: 'critical',
          title: title,
          body: body,
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: outKey,
        );
        if (isNew) {
          created++;
          await _tray(
            dedupeKey: outKey,
            title: title,
            body: body,
            category: 'inventory',
            priority: 'critical',
          );
        }
        await _notifications.markReadByDedupeKey(lowKey);
      } else if (min > 0 && stock <= min) {
        final title = 'Low stock';
        final body =
            '${product.name}: $stock left (minimum ${_fmt(min)}).';
        final isNew = await _notifications.pushIfNew(
          category: 'inventory',
          priority: 'warning',
          title: title,
          body: body,
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: lowKey,
        );
        if (isNew) {
          created++;
          await _tray(
            dedupeKey: lowKey,
            title: title,
            body: body,
            category: 'inventory',
            priority: 'warning',
          );
        }
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
        final title = 'Overdue deni';
        final body =
            '${d.customerName}: ${Money.format(d.balance)} '
            'open for $daysOpen days (limit $overdueDays).';
        final isNew = await _notifications.pushIfNew(
          category: 'debt',
          priority: 'warning',
          title: title,
          body: body,
          deepLink: 'customers',
          entityType: 'customer',
          entityId: d.customerId,
          dedupeKey: key,
        );
        if (isNew) {
          created++;
          await _tray(
            dedupeKey: key,
            title: title,
            body: body,
            category: 'debt',
            priority: 'warning',
          );
        }
      } else {
        await _notifications.markReadByDedupeKey(
          'debt_overdue_${d.customerId}',
        );
        final title = 'Customer owes you';
        final body =
            '${d.customerName}: ${Money.format(d.balance)} outstanding.';
        final priority = d.balance >= 5000 ? 'warning' : 'info';
        final isNew = await _notifications.pushIfNew(
          category: 'debt',
          priority: priority,
          title: title,
          body: body,
          deepLink: 'customers',
          entityType: 'customer',
          entityId: d.customerId,
          dedupeKey: key,
        );
        if (isNew) {
          created++;
          await _tray(
            dedupeKey: key,
            title: title,
            body: body,
            category: 'debt',
            priority: priority,
          );
        }
      }
    }

    return created;
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
