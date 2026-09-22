import '../core/database/app_database.dart';
import '../core/models/business_profile.dart';
import '../core/utils/money.dart';
import 'business_profile_service.dart';
import 'collection_service.dart';
import 'customer_service.dart';
import 'day_closing_service.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'policy_service.dart';
import 'report_service.dart';

enum AssistantActionKind { call, sms, confirmWrite, cancelWrite }

enum AssistantWriteKind { recordRepayment, addStock, recordPromise }

class AssistantAction {
  final AssistantActionKind kind;
  final String label;
  final String? phone;
  final String? smsBody;
  final String? customerName;
  final String? customerId;
  final AssistantWriteKind? writeKind;
  final Map<String, dynamic>? writePayload;

  const AssistantAction({
    required this.kind,
    required this.label,
    this.phone,
    this.smsBody,
    this.customerName,
    this.customerId,
    this.writeKind,
    this.writePayload,
  });
}

class AssistantReply {
  final String text;
  final List<AssistantAction> actions;

  const AssistantReply(this.text, {this.actions = const []});
}

/// Offline rule-based business partner — local data only.
class AssistantService {
  AssistantService({
    ReportService? reports,
    InventoryService? inventory,
    DayClosingService? closing,
    DebtorService? debtors,
    PolicyService? policy,
    BusinessProfileService? profiles,
    CollectionService? collection,
    CustomerService? customers,
    AppDatabase? database,
  })  : _reports = reports ?? ReportService(),
        _inventory = inventory ?? InventoryService(),
        _closing = closing ?? DayClosingService(),
        _debtors = debtors ?? DebtorService(),
        _policy = policy ?? PolicyService(),
        _profiles = profiles ?? BusinessProfileService.instance,
        _collection = collection ?? CollectionService(),
        _customers = customers ?? CustomerService(),
        _database = database ?? AppDatabase.instance;

  final ReportService _reports;
  final InventoryService _inventory;
  final DayClosingService _closing;
  final DebtorService _debtors;
  final PolicyService _policy;
  final BusinessProfileService _profiles;
  final CollectionService _collection;
  final CustomerService _customers;
  final AppDatabase _database;

  static const List<String> suggestions = [
    'How did I do today?',
    'Who owes me?',
    'Who is overdue?',
    'Who promised to pay today?',
    'Best sellers',
    'What is not moving?',
    'Low stock',
    'Record that John paid 500 cash',
    'Add 10 of sugar',
  ];

  Future<AssistantReply> ask(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return const AssistantReply(
        'Ask about sales, debt, stock — or say "Record that John paid 500 cash".\n'
        'Money and stock changes always need your confirmation.',
      );
    }

    // Guides
    if (_matches(q, [
      'how does', 'how do i', 'how this app', 'help', 'guide',
      'what can you', 'what can this', 'mercate work',
    ])) {
      return AssistantReply(_appOverview());
    }
    if (_matches(q, [
      'business profile', 'explain profile', 'profiles',
      'mama mboga', 'which profile', 'shop type',
    ])) {
      return AssistantReply(_explainProfiles(q));
    }
    if (_matches(q, ['explain pos', 'what is pos'])) {
      return const AssistantReply(
        'POS: sell with cash, M-Pesa, card, bank, credit or SPLIT. '
        'M-Pesa/bank need a reference. Void on receipt reverses stock and debt once.',
      );
    }

    // Write intents (proposal only — UI must confirm)
    final write = await _tryWriteIntent(q, raw);
    if (write != null) return write;

    // Intelligence
    if (_matches(q, [
      'how did i do', 'how am i doing', 'daily brief', 'summary today',
      'business today', 'today summary',
    ])) {
      return AssistantReply(await _dailyBrief());
    }
    if (_matches(q, [
      'sell today', 'sales today', 'what did i sell', 'today sales', 'sold today',
    ])) {
      return AssistantReply(await _todaySales());
    }
    if (_matches(q, ['yesterday', 'this week', 'week sales'])) {
      return AssistantReply(await _weekVsToday());
    }
    if (_matches(q, ['best sell', 'top sell', 'what sold most', 'fast moving'])) {
      return AssistantReply(await _bestSellers());
    }
    if (_matches(q, ['not moving', 'slow moving', 'dead stock'])) {
      return AssistantReply(await _slowMoving());
    }
    if (_matches(q, ['losing money', 'below cost', 'low margin'])) {
      return AssistantReply(await _losingMoney());
    }
    if (_matches(q, ['profit today', 'gross profit'])) {
      return AssistantReply(await _profitToday());
    }
    if (_matches(q, [
      'promised', 'promise to pay', 'who promised', 'promises today',
    ])) {
      return await _promisesDue();
    }
    if (_matches(q, ['overdue', 'who is overdue', 'late payers'])) {
      return await _whoIsOverdue();
    }
    if (_matches(q, [
      'who owes', 'debtor', 'owed to me', 'customers owe', 'collect',
    ])) {
      return await _whoOwesMe();
    }
    if (_matches(q, ['who do i owe', 'creditor', 'i owe', 'we owe'])) {
      return AssistantReply(await _whoIOwe());
    }
    if (_matches(q, ['low stock', 'out of stock', 'reorder', 'running out'])) {
      return AssistantReply(await _lowStock());
    }
    if (_matches(q, ['expense', 'expenses today'])) {
      return AssistantReply(await _expensesToday());
    }
    if (_matches(q, ['stock value', 'inventory value'])) {
      return AssistantReply(await _stockValue());
    }

    if (_matches(q, ['call ', 'phone ', 'dial ']) ||
        q.startsWith('call') ||
        q.startsWith('message') ||
        q.startsWith('sms') ||
        q.startsWith('text ')) {
      return await _contactIntent(q);
    }

    return const AssistantReply(
      'I did not understand that yet.\n\n'
      'Try: "How did I do today?", "Who is overdue?", '
      '"Who promised to pay today?", "Record that Mary paid 500 cash", '
      'or "Add 10 of sugar".',
    );
  }

  /// Execute a previously proposed write after user confirmation.
  Future<String> executeWrite(
    AssistantWriteKind kind,
    Map<String, dynamic> payload,
  ) async {
    switch (kind) {
      case AssistantWriteKind.recordRepayment:
        final customerId = payload['customerId'] as String;
        final amount = (payload['amount'] as num).toDouble();
        final type = payload['paymentType'] as String? ?? 'cash';
        final ref = payload['reference'] as String?;
        await _debtors.recordRepayment(
          customerId: customerId,
          amount: amount,
          paymentType: type,
          reference: ref,
          notes: 'Recorded via Assistant',
        );
        final name = payload['customerName'] as String? ?? 'Customer';
        return 'Recorded ${Money.format(amount)} $type from $name.';

      case AssistantWriteKind.addStock:
        final productId = payload['productId'] as String;
        final qty = (payload['quantity'] as num).toDouble();
        final cost = payload['unitCost'] != null
            ? (payload['unitCost'] as num).toDouble()
            : null;
        await _inventory.addStock(
          productId: productId,
          quantity: qty,
          unitCost: cost,
          movementType: 'purchase_received',
          reason: 'Added via Assistant',
        );
        final name = payload['productName'] as String? ?? 'Product';
        return 'Added ${_fmt(qty)} of $name to stock.';

      case AssistantWriteKind.recordPromise:
        final customerId = payload['customerId'] as String;
        final dateStr = payload['promisedDate'] as String;
        final date = DateTime.parse(dateStr);
        final amount = payload['amount'] != null
            ? (payload['amount'] as num).toDouble()
            : null;
        await _collection.recordPromise(
          customerId: customerId,
          promisedDate: date,
          amount: amount,
          notes: payload['notes'] as String?,
        );
        final name = payload['customerName'] as String? ?? 'Customer';
        return 'Saved promise: $name on ${dateStr.substring(0, 10)}'
            '${amount != null ? ' · ${Money.format(amount)}' : ''}.';
    }
  }

  Future<void> logCallOrSmsResult({
    required String customerId,
    required String customerName,
    required String channel,
    required String result,
  }) async {
    await _collection.logCommunication(
      partyType: 'customer',
      partyId: customerId,
      partyName: customerName,
      channel: channel,
      result: result,
    );
  }

  // --- Write intent parsing ---

  Future<AssistantReply?> _tryWriteIntent(String q, String raw) async {
    // Record payment: "record that john paid 500 cash" / "john paid 500 mpesa"
    if (_matches(q, ['paid', 'record payment', 'record that', 'received from'])) {
      final amount = _extractAmount(q);
      if (amount == null || amount <= 0) {
        return const AssistantReply(
          'To record a payment, include the amount, e.g. '
          '"Record that John paid 500 cash".',
        );
      }
      var type = 'cash';
      if (q.contains('mpesa') || q.contains('m-pesa')) type = 'mpesa';
      if (q.contains('card')) type = 'card';
      if (q.contains('bank')) type = 'bank';

      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return const AssistantReply(
          'I could not match a customer. Use a name that exists under Customers.',
        );
      }
      final balance = await _debtors.getBalance(customer.id);
      if (balance <= 0) {
        return AssistantReply(
          '${customer.name} has no outstanding balance.',
        );
      }
      if (amount > balance + 0.001) {
        return AssistantReply(
          'Amount ${Money.format(amount)} is more than '
          '${customer.name} owes (${Money.format(balance)}).',
        );
      }

      final payload = <String, dynamic>{
        'customerId': customer.id,
        'customerName': customer.name,
        'amount': amount,
        'paymentType': type,
      };
      return AssistantReply(
        'Confirm payment:\n'
        '• ${customer.name}\n'
        '• ${Money.format(amount)} $type\n'
        '• Current debt ${Money.format(balance)}\n\n'
        'Nothing is saved until you tap Confirm.',
        actions: [
          AssistantAction(
            kind: AssistantActionKind.confirmWrite,
            label: 'Confirm payment',
            writeKind: AssistantWriteKind.recordRepayment,
            writePayload: payload,
          ),
          const AssistantAction(
            kind: AssistantActionKind.cancelWrite,
            label: 'Cancel',
          ),
        ],
      );
    }

    // Add stock: "add 10 of sugar" / "add 20 bags maize at 3000"
    if (_matches(q, ['add stock', 'add ', 'receive ']) &&
        !_matches(q, ['add customer', 'add supplier'])) {
      final qty = _extractQuantity(q);
      if (qty == null || qty <= 0) {
        return const AssistantReply(
          'To add stock: "Add 10 of sugar" or "Add 20 of maize at 50".',
        );
      }
      final product = await _resolveProductName(q);
      if (product == null) {
        return const AssistantReply(
          'I could not match a product. Use a name from Stock.',
        );
      }
      final cost = _extractCostAfterAt(q);
      final payload = <String, dynamic>{
        'productId': product.id,
        'productName': product.name,
        'quantity': qty,
        if (cost != null) 'unitCost': cost,
      };
      return AssistantReply(
        'Confirm stock add:\n'
        '• ${product.name}\n'
        '• Quantity ${_fmt(qty)} ${product.unit}\n'
        '${cost != null ? '• Unit cost ${Money.format(cost)}\n' : ''}'
        '\nNothing is saved until you tap Confirm.',
        actions: [
          AssistantAction(
            kind: AssistantActionKind.confirmWrite,
            label: 'Confirm add stock',
            writeKind: AssistantWriteKind.addStock,
            writePayload: payload,
          ),
          const AssistantAction(
            kind: AssistantActionKind.cancelWrite,
            label: 'Cancel',
          ),
        ],
      );
    }

    // Promise: "mary promised friday" / "promise john tomorrow 500"
    if (_matches(q, ['promised', 'promise '])) {
      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return const AssistantReply(
          'Name a customer, e.g. "Mary promised Friday" or '
          '"Promise John tomorrow 500".',
        );
      }
      final date = _extractRelativeDate(q) ??
          DateTime.now().add(const Duration(days: 1));
      final amount = _extractAmount(q);
      final dateStr = DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .substring(0, 10);
      final payload = <String, dynamic>{
        'customerId': customer.id,
        'customerName': customer.name,
        'promisedDate': dateStr,
        if (amount != null) 'amount': amount,
      };
      return AssistantReply(
        'Confirm promise to pay:\n'
        '• ${customer.name}\n'
        '• Date $dateStr\n'
        '${amount != null ? '• Amount ${Money.format(amount)}\n' : ''}'
        '\nNothing is saved until you tap Confirm.',
        actions: [
          AssistantAction(
            kind: AssistantActionKind.confirmWrite,
            label: 'Confirm promise',
            writeKind: AssistantWriteKind.recordPromise,
            writePayload: payload,
          ),
          const AssistantAction(
            kind: AssistantActionKind.cancelWrite,
            label: 'Cancel',
          ),
        ],
      );
    }

    return null;
  }

  Future<({String id, String name})?> _resolveCustomerName(String q) async {
    final all = await _customers.getAllCustomers();
    ({String id, String name})? best;
    var bestLen = 0;
    for (final c in all) {
      final name = c.name.toLowerCase();
      if (name.length >= 3 && q.contains(name) && name.length > bestLen) {
        best = (id: c.id, name: c.name);
        bestLen = name.length;
      } else {
        for (final part in name.split(RegExp(r'\s+'))) {
          if (part.length >= 3 && q.contains(part) && part.length > bestLen) {
            best = (id: c.id, name: c.name);
            bestLen = part.length;
          }
        }
      }
    }
    return best;
  }

  Future<({String id, String name, String unit})?> _resolveProductName(
    String q,
  ) async {
    final all = await _inventory.getAllProducts();
    ({String id, String name, String unit})? best;
    var bestLen = 0;
    for (final p in all) {
      final name = p.name.toLowerCase();
      if (name.length >= 2 && q.contains(name) && name.length > bestLen) {
        best = (id: p.id, name: p.name, unit: p.unit);
        bestLen = name.length;
      }
    }
    return best;
  }

  double? _extractAmount(String q) {
    // Prefer number near paid/ksh
    final re = RegExp(
      r'(?:ksh\s*)?(\d+(?:[.,]\d+)?)',
      caseSensitive: false,
    );
    final matches = re.allMatches(q).toList();
    if (matches.isEmpty) return null;
    // Prefer larger plausible money amounts later in phrase
    for (final m in matches.reversed) {
      final raw = m.group(1)!.replaceAll(',', '');
      final v = double.tryParse(raw);
      if (v != null && v > 0) return Money.round(v);
    }
    return null;
  }

  double? _extractQuantity(String q) {
    final m = RegExp(r'add\s+(\d+(?:[.,]\d+)?)', caseSensitive: false)
        .firstMatch(q);
    if (m != null) {
      return double.tryParse(m.group(1)!.replaceAll(',', ''));
    }
    return _extractAmount(q);
  }

  double? _extractCostAfterAt(String q) {
    final m = RegExp(r'at\s+(\d+(?:[.,]\d+)?)', caseSensitive: false)
        .firstMatch(q);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', ''));
  }

  DateTime? _extractRelativeDate(String q) {
    final now = DateTime.now();
    if (q.contains('today')) return now;
    if (q.contains('tomorrow')) return now.add(const Duration(days: 1));
    const days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final e in days.entries) {
      if (q.contains(e.key)) {
        var d = now;
        while (d.weekday != e.value) {
          d = d.add(const Duration(days: 1));
        }
        if (!d.isAfter(now) && d.day == now.day) {
          d = d.add(const Duration(days: 7));
        }
        return d;
      }
    }
    return null;
  }

  bool _matches(String q, List<String> keys) {
    for (final k in keys) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  String _appOverview() {
    return 'Mercate is offline on this phone.\n'
        'I can summarise sales and debt, and propose actions like '
        'recording a repayment or adding stock — you always confirm first.';
  }

  String _explainProfiles(String q) {
    final buf = StringBuffer('Profiles change what you see, not the engine.\n');
    for (final p in BusinessProfile.all) {
      final status = p.enabled ? '' : ' (later)';
      buf.writeln('• ${p.label}$status');
    }
    return buf.toString();
  }

  Future<String> _dailyBrief() async {
    final day = await _reports.daySales();
    final debtors = await _debtors.listOutstanding(limit: 50);
    final overdueDays = await _policy.getOverdueDebtDays();
    final overdue =
        await _debtors.listOverdue(overdueDays: overdueDays, limit: 20);
    final promises = await _collection.listOpenPromises(onOrBefore: DateTime.now());
    final low = await _inventory.getLowStockProducts();
    final shop = await _profiles.getBusinessName();
    final debtTotal = debtors.fold<double>(0, (s, d) => s + d.balance);
    return 'Daily brief — $shop (${day.businessDate})\n\n'
        'Sales: ${Money.format(day.salesTotal)} (${day.saleCount})\n'
        'Cash ${Money.format(day.cash)} · M-Pesa ${Money.format(day.mpesa)}\n'
        'Est. gross profit: ${Money.format(day.grossProfit)}\n'
        'Expenses: ${Money.format(day.expensesTotal)}\n'
        'Customer debt: ${Money.format(debtTotal)}\n'
        'Overdue (≥$overdueDays days): ${overdue.length}\n'
        'Promises due by today: ${promises.length}\n'
        'Low stock: ${low.length}';
  }

  Future<String> _todaySales() async {
    final day = await _reports.daySales();
    return 'Sales today (${day.businessDate})\n'
        '• ${day.saleCount} · ${Money.format(day.salesTotal)}\n'
        '• Cash ${Money.format(day.cash)} · M-Pesa ${Money.format(day.mpesa)}\n'
        '• Credit ${Money.format(day.creditTotal)}\n'
        '• Est. profit ${Money.format(day.grossProfit)}';
  }

  Future<String> _weekVsToday() async {
    final today = await _reports.daySales();
    final yesterday = await _reports.daySales(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final delta = Money.round(today.salesTotal - yesterday.salesTotal);
    final dir = delta > 0
        ? 'up ${Money.format(delta)}'
        : delta < 0
            ? 'down ${Money.format(-delta)}'
            : 'same';
    return 'Today ${Money.format(today.salesTotal)} ($dir vs yesterday)\n'
        'Yesterday ${Money.format(yesterday.salesTotal)}';
  }

  Future<String> _profitToday() async {
    final day = await _reports.daySales();
    return 'Est. gross profit today: ${Money.format(day.grossProfit)}\n'
        '(Sales − cost of goods; expenses separate.)';
  }

  Future<String> _bestSellers() async {
    final db = await _database.database;
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT si.product_name AS name,
             COALESCE(SUM(si.quantity), 0) AS qty,
             COALESCE(SUM(si.total), 0) AS revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sale_status = 'completed' AND s.created_at >= ?
      GROUP BY si.product_name
      ORDER BY qty DESC LIMIT 10
      ''',
      [since],
    );
    if (rows.isEmpty) return 'No sales in the last 30 days to rank.';
    final buf = StringBuffer('Best sellers (30 days):\n');
    for (final r in rows) {
      buf.writeln(
        '• ${r['name']}: ${_fmt((r['qty'] as num).toDouble())} · '
        '${Money.format((r['revenue'] as num).toDouble())}',
      );
    }
    return buf.toString().trim();
  }

  Future<String> _slowMoving() async {
    final stock = await _reports.stockOnHand();
    final db = await _database.database;
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final sold = await db.rawQuery(
      '''
      SELECT DISTINCT si.product_id AS id FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sale_status = 'completed' AND s.created_at >= ?
        AND si.product_id IS NOT NULL
      ''',
      [since],
    );
    final soldIds =
        sold.map((r) => r['id'] as String?).whereType<String>().toSet();
    final dead = stock
        .where((s) => s.quantity > 0.001 && !soldIds.contains(s.productId))
        .toList();
    if (dead.isEmpty) return 'No obvious dead stock in the last 30 days.';
    final buf = StringBuffer('Not moving (no sale in 30 days):\n');
    for (final s in dead.take(15)) {
      buf.writeln('• ${s.name}: ${_fmt(s.quantity)}');
    }
    return buf.toString().trim();
  }

  Future<String> _losingMoney() async {
    final db = await _database.database;
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT si.product_name AS name,
             COALESCE(SUM(si.total), 0) AS revenue,
             COALESCE(SUM(si.quantity * COALESCE(si.unit_cost, 0)), 0) AS cost
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sale_status = 'completed' AND s.created_at >= ?
        AND si.unit_cost IS NOT NULL
      GROUP BY si.product_name
      HAVING revenue + 0.001 < cost
      ORDER BY (cost - revenue) DESC LIMIT 10
      ''',
      [since],
    );
    if (rows.isEmpty) {
      return 'No below-cost sales with recorded cost in the last 30 days.';
    }
    final buf = StringBuffer('Sold below cost (30 days):\n');
    for (final r in rows) {
      final rev = (r['revenue'] as num).toDouble();
      final cost = (r['cost'] as num).toDouble();
      buf.writeln(
        '• ${r['name']}: loss ${Money.format(cost - rev)}',
      );
    }
    return buf.toString().trim();
  }

  Future<AssistantReply> _promisesDue() async {
    final list =
        await _collection.listOpenPromises(onOrBefore: DateTime.now());
    if (list.isEmpty) {
      return const AssistantReply('No open promises due today or earlier.');
    }
    final buf = StringBuffer('Promises due by today:\n\n');
    final actions = <AssistantAction>[];
    for (final p in list.take(10)) {
      final name = p.customerName ?? p.customerId;
      final amt =
          p.amount != null ? ' · ${Money.format(p.amount!)}' : '';
      buf.writeln(
        '• $name — ${p.promisedDate.toIso8601String().substring(0, 10)}$amt',
      );
      final phone = p.phone?.trim();
      if (phone != null && phone.isNotEmpty) {
        actions.add(AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call $name',
          phone: phone,
          customerName: name,
          customerId: p.customerId,
        ));
      }
    }
    return AssistantReply(buf.toString().trim(), actions: actions);
  }

  Future<AssistantReply> _whoOwesMe() async {
    final list = await _debtors.listOutstanding(limit: 15);
    if (list.isEmpty) {
      return const AssistantReply('No one owes you right now.');
    }
    final total = list.fold<double>(0, (s, d) => s + d.balance);
    final buf = StringBuffer(
      'Customers who owe you (total ${Money.format(total)}):\n\n',
    );
    final actions = <AssistantAction>[];
    final shop = await _profiles.getBusinessName();
    for (final d in list.take(10)) {
      buf.writeln(
        '• ${d.customerName}: ${Money.format(d.balance)}'
        '${d.daysOpen > 0 ? ' · ${d.daysOpen}d' : ''}',
      );
      final phone = d.phone?.trim();
      if (phone != null && phone.isNotEmpty) {
        actions.add(AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
          customerId: d.customerId,
        ));
        actions.add(AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
          customerId: d.customerId,
          smsBody: DebtorService.collectionSmsBody(
            customerName: d.customerName,
            balance: d.balance,
            shopName: shop,
            daysOpen: d.daysOpen,
          ),
        ));
      }
    }
    return AssistantReply(
      buf.toString().trim(),
      actions: actions.take(6).toList(),
    );
  }

  Future<AssistantReply> _whoIsOverdue() async {
    final days = await _policy.getOverdueDebtDays();
    final list = await _debtors.listOverdue(overdueDays: days, limit: 15);
    if (list.isEmpty) {
      return AssistantReply('No overdue debtors (threshold $days days).');
    }
    final total = list.fold<double>(0, (s, d) => s + d.balance);
    final buf = StringBuffer(
      'Overdue (≥$days days) — ${Money.format(total)}:\n\n',
    );
    final actions = <AssistantAction>[];
    final shop = await _profiles.getBusinessName();
    for (final d in list.take(10)) {
      buf.writeln(
        '• ${d.customerName}: ${Money.format(d.balance)} · ${d.daysOpen}d',
      );
      final phone = d.phone?.trim();
      if (phone != null && phone.isNotEmpty) {
        actions.add(AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
          customerId: d.customerId,
        ));
        actions.add(AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
          customerId: d.customerId,
          smsBody: DebtorService.collectionSmsBody(
            customerName: d.customerName,
            balance: d.balance,
            shopName: shop,
            daysOpen: d.daysOpen,
          ),
        ));
      }
    }
    return AssistantReply(
      buf.toString().trim(),
      actions: actions.take(6).toList(),
    );
  }

  Future<String> _whoIOwe() async {
    final list = await _reports.creditorsOutstanding();
    if (list.isEmpty) return 'You do not owe any supplier right now.';
    final total = list.fold<double>(0, (s, r) => s + r.balance);
    final lines = list
        .take(10)
        .map((c) => '• ${c.name}: ${Money.format(c.balance)}')
        .join('\n');
    return 'Suppliers you owe (${Money.format(total)}):\n$lines';
  }

  Future<String> _lowStock() async {
    final low = await _inventory.getLowStockProducts();
    if (low.isEmpty) return 'No products at or below minimum stock.';
    final buf = StringBuffer('Low stock:\n');
    for (final p in low.take(15)) {
      final qty = await _inventory.getStock(p.id);
      buf.writeln('• ${p.name}: ${_fmt(qty)} (min ${p.minimumStock})');
    }
    return buf.toString().trim();
  }

  Future<String> _expensesToday() async {
    final summary = await _closing.getSummary(DateTime.now());
    return 'Expenses today: ${Money.format(summary.expensesTotal)}';
  }

  Future<String> _stockValue() async {
    final stock = await _reports.stockOnHand();
    final value = stock.fold<double>(0, (s, r) => s + r.stockValue);
    return 'Stock value at cost: ${Money.format(value)} '
        '(${stock.length} products)';
  }

  Future<AssistantReply> _contactIntent(String q) async {
    final list = await _debtors.listOutstanding(limit: 50);
    if (list.isEmpty) {
      return const AssistantReply('No debtors to call or message.');
    }
    DebtorSummary? match;
    for (final d in list) {
      final name = d.customerName.toLowerCase();
      for (final p in name.split(RegExp(r'\s+'))) {
        if (p.length >= 3 && q.contains(p)) {
          match = d;
          break;
        }
      }
      if (match != null) break;
    }
    match ??= list.first;
    final phone = match.phone?.trim();
    if (phone == null || phone.isEmpty) {
      return AssistantReply(
        '${match.customerName} owes ${Money.format(match.balance)} '
        'but has no phone number.',
      );
    }
    final shop = await _profiles.getBusinessName();
    final body = DebtorService.collectionSmsBody(
      customerName: match.customerName,
      balance: match.balance,
      shopName: shop,
      daysOpen: match.daysOpen,
    );
    return AssistantReply(
      '${match.customerName} owes ${Money.format(match.balance)}.\n'
      'Phone: $phone\n'
      'Nothing is sent until you tap a button.',
      actions: [
        AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call ${match.customerName}',
          phone: phone,
          customerName: match.customerName,
          customerId: match.customerId,
        ),
        AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${match.customerName}',
          phone: phone,
          customerName: match.customerName,
          customerId: match.customerId,
          smsBody: body,
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
