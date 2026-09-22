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
    'What did I sell today?',
    'Who owes me?',
    'Who is overdue?',
    'Who promised to pay today?',
    'Best sellers',
    'What is not moving?',
    'Low stock',
    'Stock value',
  ];

  Future<AssistantReply> ask(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return const AssistantReply(
        'Ask about sales, debt, stock, or who owes you.\n'
        'Money and stock changes always need your confirmation.',
      );
    }

    if (_matches(q, [
      'how does', 'how do i', 'help', 'guide', 'what can you', 'mercate work',
    ])) {
      return const AssistantReply(
        'Mercate is offline on this phone. I summarise sales and debt, '
        'and can propose recording a payment or adding stock — you confirm first.',
      );
    }

    // Promise QUESTIONS before write intents
    if (_matches(q, [
          'who promised',
          'promises today',
          'promised to pay today',
          'list promises',
          'show promises',
          'any promises',
        ]) ||
        (q.contains('promise') &&
            (q.contains('who') ||
                q.contains('what') ||
                q.contains('list') ||
                q.contains('show') ||
                q.contains('any')))) {
      return await _promisesDue();
    }

    final write = await _tryWriteIntent(q);
    if (write != null) return write;

    if (_matches(q, [
      'how did i do', 'daily brief', 'summary today', 'today summary',
    ])) {
      return AssistantReply(await _dailyBrief());
    }
    if (_matches(q, [
      'sell today', 'sales today', 'what did i sell', 'today sales', 'sold today',
    ])) {
      return AssistantReply(await _todaySales());
    }
    if (_matches(q, ['best sell', 'top sell', 'what sold most'])) {
      return AssistantReply(await _bestSellers());
    }
    if (_matches(q, ['not moving', 'slow moving', 'dead stock'])) {
      return AssistantReply(await _slowMoving());
    }
    if (_matches(q, ['overdue', 'who is overdue'])) {
      return await _whoIsOverdue();
    }
    if (_matches(q, ['who owes', 'debtor', 'customers owe', 'collect'])) {
      return await _whoOwesMe();
    }
    if (_matches(q, ['who do i owe', 'creditor', 'i owe', 'we owe'])) {
      return AssistantReply(await _whoIOwe());
    }
    if (_matches(q, ['low stock', 'out of stock', 'reorder', 'running out'])) {
      return AssistantReply(await _lowStock());
    }
    if (_matches(q, ['stock value', 'inventory value'])) {
      return AssistantReply(await _stockValue());
    }
    if (_matches(q, ['expense', 'expenses today'])) {
      return AssistantReply(await _expensesToday());
    }

    return const AssistantReply(
      'I did not understand that yet.\n\n'
      'Try: "How did I do today?", "Who is overdue?", '
      '"Who promised to pay today?", or "Low stock".',
    );
  }

  Future<String> executeWrite(
    AssistantWriteKind kind,
    Map<String, dynamic> payload,
  ) async {
    switch (kind) {
      case AssistantWriteKind.recordRepayment:
        await _debtors.recordRepayment(
          customerId: payload['customerId'] as String,
          amount: (payload['amount'] as num).toDouble(),
          paymentType: payload['paymentType'] as String? ?? 'cash',
          reference: payload['reference'] as String?,
          notes: 'Recorded via Assistant',
        );
        return 'Recorded ${Money.format((payload['amount'] as num).toDouble())} '
            '${payload['paymentType'] ?? 'cash'} from ${payload['customerName']}.';
      case AssistantWriteKind.addStock:
        await _inventory.addStock(
          productId: payload['productId'] as String,
          quantity: (payload['quantity'] as num).toDouble(),
          unitCost: payload['unitCost'] != null
              ? (payload['unitCost'] as num).toDouble()
              : null,
          movementType: 'purchase_received',
          reason: 'Added via Assistant',
        );
        return 'Added stock for ${payload['productName']}.';
      case AssistantWriteKind.recordPromise:
        await _collection.recordPromise(
          customerId: payload['customerId'] as String,
          promisedDate: DateTime.parse(payload['promisedDate'] as String),
          amount: payload['amount'] != null
              ? (payload['amount'] as num).toDouble()
              : null,
        );
        return 'Saved promise for ${payload['customerName']}.';
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

  Future<AssistantReply?> _tryWriteIntent(String q) async {
    if (_matches(q, ['paid', 'record payment', 'record that', 'received from'])) {
      final amount = _extractAmount(q);
      if (amount == null || amount <= 0) {
        return const AssistantReply(
          'To record a payment, include the customer and amount.',
        );
      }
      var type = 'cash';
      if (q.contains('mpesa') || q.contains('m-pesa')) type = 'mpesa';
      if (q.contains('card')) type = 'card';
      if (q.contains('bank')) type = 'bank';
      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return const AssistantReply(
          'I could not match a customer. Use a name under Customers.',
        );
      }
      final balance = await _debtors.getBalance(customer.id);
      if (balance <= 0) {
        return AssistantReply('${customer.name} has no outstanding balance.');
      }
      if (amount > balance + 0.001) {
        return AssistantReply(
          'Amount ${Money.format(amount)} exceeds debt '
          '${Money.format(balance)} for ${customer.name}.',
        );
      }
      final payload = {
        'customerId': customer.id,
        'customerName': customer.name,
        'amount': amount,
        'paymentType': type,
      };
      return AssistantReply(
        'Confirm payment:\n• ${customer.name}\n'
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

    if (_matches(q, ['promised', 'promise ']) &&
        !q.contains('who') &&
        !q.contains('what') &&
        !q.contains('list') &&
        !q.contains('show') &&
        !q.contains('any')) {
      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return const AssistantReply(
          'Name a customer, e.g. "Mary promised Friday".',
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
        'Confirm promise:\n• ${customer.name}\n• $dateStr\n'
        '${amount != null ? '• ${Money.format(amount)}\n' : ''}'
        '\nNothing is saved until you Confirm.',
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

  double? _extractAmount(String q) {
    final re = RegExp(r'(?:ksh\s*)?(\d+(?:[.,]\d+)?)', caseSensitive: false);
    final matches = re.allMatches(q).toList();
    for (final m in matches.reversed) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v != null && v > 0) return Money.round(v);
    }
    return null;
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

  Future<String> _dailyBrief() async {
    final day = await _reports.daySales();
    final debtors = await _debtors.listOutstanding(limit: 50);
    final overdueDays = await _policy.getOverdueDebtDays();
    final overdue =
        await _debtors.listOverdue(overdueDays: overdueDays, limit: 20);
    final promises =
        await _collection.listOpenPromises(onOrBefore: DateTime.now());
    final low = await _inventory.getLowStockProducts();
    final shop = await _profiles.getBusinessName();
    final debtTotal = debtors.fold<double>(0, (s, d) => s + d.balance);
    return 'Daily brief — $shop (${day.businessDate})\n\n'
        'Sales: ${Money.format(day.salesTotal)} (${day.saleCount})\n'
        'Cash ${Money.format(day.cash)} · M-Pesa ${Money.format(day.mpesa)}\n'
        'Est. gross profit: ${Money.format(day.grossProfit)}\n'
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
        '• Credit ${Money.format(day.creditTotal)}';
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
      GROUP BY si.product_name ORDER BY qty DESC LIMIT 10
      ''',
      [since],
    );
    if (rows.isEmpty) return 'No sales in the last 30 days to rank.';
    final buf = StringBuffer('Best sellers (30 days):\n');
    for (final r in rows) {
      buf.writeln('• ${r['name']}: ${r['qty']} · ${Money.format((r['revenue'] as num).toDouble())}');
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
      buf.writeln('• ${s.name}: ${s.quantity}');
    }
    return buf.toString().trim();
  }

  Future<AssistantReply> _promisesDue() async {
    final list =
        await _collection.listOpenPromises(onOrBefore: DateTime.now());
    if (list.isEmpty) {
      return const AssistantReply(
        'No one has a promise to pay due today or earlier.',
      );
    }
    final buf = StringBuffer('Promises due by today:\n\n');
    for (final p in list.take(10)) {
      final name = p.customerName ?? p.customerId;
      final amt =
          p.amount != null ? ' · ${Money.format(p.amount!)}' : '';
      buf.writeln(
        '• $name — ${p.promisedDate.toIso8601String().substring(0, 10)}$amt',
      );
    }
    return AssistantReply(buf.toString().trim());
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
    for (final d in list.take(10)) {
      buf.writeln(
        '• ${d.customerName}: ${Money.format(d.balance)} · ${d.daysOpen}d',
      );
    }
    return AssistantReply(buf.toString().trim());
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
      buf.writeln('• ${p.name}: $qty (min ${p.minimumStock})');
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
}
