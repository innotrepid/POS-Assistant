import '../core/utils/money.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'notification_service.dart';

/// Background-style scan that creates in-app notifications (not system push).
/// Safe to call often — uses dedupe keys so unread alerts are not duplicated.
class AlertScannerService {
  AlertScannerService({
    InventoryService? inventory,
    DebtorService? debtors,
    NotificationService? notifications,
  })  : _inventory = inventory ?? InventoryService(),
        _debtors = debtors ?? DebtorService(),
        _notifications = notifications ?? NotificationService();

  final InventoryService _inventory;
  final DebtorService _debtors;
  final NotificationService _notifications;

  /// Scan stock and debt; create missing alerts; clear resolved low-stock keys.
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
      // Only alert when minimum is configured (> 0) or stock is zero
      final stock = await _inventory.getStock(product.id);
      final min = product.minimumStock;

      final outKey = 'stock_out_${product.id}';
      final lowKey = 'stock_low_${product.id}';

      if (stock <= 0) {
        // Out of stock supersedes low-stock
        final id = await _notifications.push(
          category: 'inventory',
          priority: 'critical',
          title: 'Out of stock',
          body: '${product.name} has no stock left.',
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: outKey,
        );
        // If this is a new notification id from a previous unread, push returns existing
        // We can't easily know if new — approximate by counting low creates only when needed
        created++;
        // Mark low-stock unread as read (condition escalated)
        await _notifications.markReadByDedupeKey(lowKey);
      } else if (min > 0 && stock <= min) {
        await _notifications.push(
          category: 'inventory',
          priority: 'warning',
          title: 'Low stock',
          body:
              '${product.name}: $stock left (minimum ${min.toStringAsFixed(min == min.truncateToDouble() ? 0 : 1)}).',
          deepLink: 'stock',
          entityType: 'product',
          entityId: product.id,
          dedupeKey: lowKey,
        );
        created++;
        // Clear out-of-stock if restocked above zero but still low
        await _notifications.markReadByDedupeKey(outKey);
      } else {
        // Recovered — mark both resolved
        await _notifications.markReadByDedupeKey(outKey);
        await _notifications.markReadByDedupeKey(lowKey);
      }
    }

    return created;
  }

  Future<int> _scanDebt() async {
    var created = 0;
    final list = await _debtors.listOutstanding(limit: 50);

    for (final d in list) {
      // Significant debt alert (any outstanding); dedupe per customer
      final key = 'debt_outstanding_${d.customerId}';
      if (d.balance > 0.001) {
        await _notifications.push(
          category: 'debt',
          priority: d.balance >= 5000 ? 'warning' : 'info',
          title: 'Customer owes you',
          body:
              '${d.customerName}: ${Money.format(d.balance)} outstanding.',
          deepLink: 'customers',
          entityType: 'customer',
          entityId: d.customerId,
          dedupeKey: key,
        );
        created++;
      }
    }

    // Note: when balance hits 0, next scan won't create; old unread stays until read.
    // Optionally clear zero-balance keys:
    // (list only has positive balances, so we skip clearing all customers for performance)

    return created;
  }
}
