import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'notification_service.dart';
import 'policy_service.dart';
import 'system_notification_service.dart';

/// Scans stock and debt; writes in-app notifications and Android/iOS tray alerts.
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
        if (isNew) {
          created++;
          await SystemNotificationService.instance.show(
            id: product.id.hashCode & 0x7fffffff,
            title: 'Out of stock',
            body: '${product.name} has no stock left.',
            category: 'inventory',
            priority: 'critical',
          );
        }
        await _notifications.markReadByDedupeKey(lowKey);
      } else if (min > 0 && stock <= min) {
        final isNew = await _notifications.pushIfNew(
          category: 'inventory',
          priority: 'warning',
          title: 'Low stock',
          body: '${product.name}: $stock left (minimum ${_fmt(min)}).',
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: lowKey,
        );
        if (isNew) {
          created++;
          await SystemNotificationService.instance.show(
            id: (product.id.hashCode + 1) & 0x7fffffff,
            title: 'Low stock',
            body: '${product.name}: $stock left (minimum ${_fmt(min)}).',
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
    final list = await _debtors.listOutstanding(limit: 200, overdueDays: overdueDays);

    for (final d in list) {
      if (d.balance <= 0) continue;
      final daysOpen = d.daysOpen;
      final isOverdue = overdueDays > 0 && daysOpen >= overdueDays;
      final key = isOverdue
          ? 'debt_overdue_${d.customerId}'
          : 'debt_outstanding_${d.customerId}';

      if (isOverdue) {
        await _notifications.markReadByDedupeKey('debt_outstanding_${d.customerId}');
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
        if (isNew) {
          created++;
          await SystemNotificationService.instance.show(
            id: d.customerId.hashCode & 0x7fffffff,
            title: 'Overdue debt',
            body:
                '${d.customerName}: ${Money.format(d.balance)} '
                'open for $daysOpen days (limit $overdueDays).',
            category: 'debt',
            priority: 'warning',
          );
        }
      } else {
        await _notifications.markReadByDedupeKey('debt_overdue_${d.customerId}');
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
        if (isNew) {
          created++;
          await SystemNotificationService.instance.show(
            id: (d.customerId.hashCode + 17) & 0x7fffffff,
            title: 'Customer owes you',
            body: '${d.customerName}: ${Money.format(d.balance)} outstanding.',
            category: 'debt',
            priority: d.balance >= 5000 ? 'warning' : 'info',
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
