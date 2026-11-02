import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'collection_service.dart';
import 'day_closing_service.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'notification_service.dart';
import 'policy_service.dart';
import 'system_notification_service.dart';

/// Scans stock, debt, promises, and open days; in-app + system tray alerts.
class AlertScannerService {
  AlertScannerService({
    InventoryService? inventory,
    DebtorService? debtors,
    NotificationService? notifications,
    PolicyService? policy,
    AppDatabase? database,
    CollectionService? collection,
    DayClosingService? dayClose,
  })  : _inventory = inventory ?? InventoryService(),
        _debtors = debtors ?? DebtorService(),
        _notifications = notifications ?? NotificationService(),
        _policy = policy ?? PolicyService(),
        _database = database ?? AppDatabase.instance,
        _collection = collection ?? CollectionService(),
        _dayClose = dayClose ?? DayClosingService();

  final InventoryService _inventory;
  final DebtorService _debtors;
  final NotificationService _notifications;
  final PolicyService _policy;
  final AppDatabase _database;
  final CollectionService _collection;
  final DayClosingService _dayClose;

  Future<int> scan() async {
    await SystemNotificationService.instance.init(requestPermission: true);

    var created = 0;
    created += await _scanStock();
    created += await _scanDebt();
    created += await _scanPromisesToday();
    created += await _scanUnclosedDays();
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
    final list =
        await _debtors.listOutstanding(limit: 200, overdueDays: overdueDays);

    for (final d in list) {
      if (d.balance <= 0) continue;
      final daysOpen = d.daysOpen;
      final isOverdue = overdueDays > 0 && daysOpen >= overdueDays;
      final key = isOverdue
          ? 'debt_overdue_${d.customerId}'
          : 'debt_outstanding_${d.customerId}';

      if (isOverdue) {
        await _notifications
            .markReadByDedupeKey('debt_outstanding_${d.customerId}');
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
        await _notifications
            .markReadByDedupeKey('debt_overdue_${d.customerId}');
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

  Future<int> _scanPromisesToday() async {
    var created = 0;
    try {
      final due = await _collection.listPromisesDueOn(DateTime.now());
      if (due.isEmpty) {
        await _notifications.markReadByDedupeKey('promises_today');
        return 0;
      }
      final names =
          due.map((p) => p.customerName ?? p.customerId).take(3).join(', ');
      final more = due.length > 3 ? ' +${due.length - 3}' : '';
      final body =
          '${due.length} promise(s) due today: $names$more. Call or SMS.';
      final isNew = await _notifications.pushIfNew(
        category: 'debt',
        priority: 'warning',
        title: 'Promises due today',
        body: body,
        deepLink: 'customers',
        entityType: 'promise',
        entityId: 'today',
        dedupeKey: 'promises_today',
      );
      if (isNew) {
        created++;
        await SystemNotificationService.instance.show(
          id: 'promises_today'.hashCode & 0x7fffffff,
          title: 'Promises due today',
          body: body,
          category: 'promise',
          priority: 'warning',
        );
      }
    } catch (_) {}
    return created;
  }

  Future<int> _scanUnclosedDays() async {
    var created = 0;
    try {
      final open = await _dayClose.unclosedDaysWithActivity(lookbackDays: 3);
      if (open.isEmpty) {
        await _notifications.markReadByDedupeKey('day_not_closed');
        return 0;
      }
      final first = open.first;
      final body =
          'Day ${first.businessDate} not closed — sales ${Money.format(first.salesTotal)}.';
      final isNew = await _notifications.pushIfNew(
        category: 'business',
        priority: 'info',
        title: 'Day not closed',
        body: body,
        deepLink: 'home',
        entityType: 'day',
        entityId: first.businessDate,
        dedupeKey: 'day_not_closed',
      );
      if (isNew) {
        created++;
        await SystemNotificationService.instance.show(
          id: 'day_not_closed'.hashCode & 0x7fffffff,
          title: 'Day not closed',
          body: body,
          category: 'day',
          priority: 'info',
        );
      }
    } catch (_) {}
    return created;
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
