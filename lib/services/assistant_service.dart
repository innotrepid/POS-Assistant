import '../core/database/app_database.dart';
import '../core/models/business_profile.dart';
import '../core/utils/money.dart';
import 'business_profile_service.dart';
import 'day_closing_service.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'policy_service.dart';
import 'report_service.dart';

/// Safe external action the UI may offer (never auto-executes).
enum AssistantActionKind { call, sms }

class AssistantAction {
  final AssistantActionKind kind;
  final String label;
  final String? phone;
  final String? smsBody;
  final String? customerName;

  const AssistantAction({
    required this.kind,
    required this.label,
    this.phone,
    this.smsBody,
    this.customerName,
  });
}

class AssistantReply {
  final String text;
  final List<AssistantAction> actions;

  const AssistantReply(this.text, {this.actions = const []});
}

/// Offline rule-based business partner — local data only, no cloud model.
class AssistantService {
  AssistantService({
    ReportService? reports,
    InventoryService? inventory,
    DayClosingService? closing,
    DebtorService? debtors,
    PolicyService? policy,
    BusinessProfileService? profiles,
    AppDatabase? database,
  })  : _reports = reports ?? ReportService(),
        _inventory = inventory ?? InventoryService(),
        _closing = closing ?? DayClosingService(),
        _debtors = debtors ?? DebtorService(),
        _policy = policy ?? PolicyService(),
        _profiles = profiles ?? BusinessProfileService.instance,
        _database = database ?? AppDatabase.instance;

  final ReportService _reports;
  final InventoryService _inventory;
  final DayClosingService _closing;
  final DebtorService _debtors;
  final PolicyService _policy;
  final BusinessProfileService _profiles;
  final AppDatabase _database;

  static const List<String> suggestions = [
    'How did I do today?',
    'What did I sell today?',
    'Who owes me?',
    'Who is overdue?',
    'Who do I owe?',
    'Low stock',
    'What is not moving?',
    'Best sellers',
    'What am I losing money on?',
    'Stock value',
    'How does Mercate work?',
  ];

  Future<AssistantReply> ask(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return const AssistantReply(
        'Ask me about sales, profit, stock, who owes you, or how Mercate works.\n'
        'I only use data on this phone — offline.',
      );
    }

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
    if (_matches(q, ['explain home', 'explain dashboard', 'what is home'])) {
      return AssistantReply(_explainHome());
    }
    if (_matches(q, ['explain pos', 'what is pos', 'point of sale'])) {
      return AssistantReply(_explainPos());
    }
    if (_matches(q, ['explain stock', 'explain inventory', 'what is stock'])) {
      return AssistantReply(_explainStock());
    }
    if (_matches(q, ['explain customer', 'explain debtor', 'what is customer'])) {
      return AssistantReply(_explainCustomers());
    }
    if (_matches(q, ['explain supplier', 'explain creditor', 'what is supplier'])) {
      return AssistantReply(_explainSuppliers());
    }
    if (_matches(q, ['explain report', 'what is report', 'pdf'])) {
      return AssistantReply(_explainReports());
    }
    if (_matches(q, ['quick sale', 'explain quick'])) {
      return AssistantReply(_explainQuickSale());
    }
    if (_matches(q, ['close day', 'closing', 'end of day'])) {
      return AssistantReply(_explainCloseDay());
    }
    if (_matches(q, ['void', 'refund'])) {
      return AssistantReply(_explainVoid());
    }
    if (_matches(q, ['split payment', 'split pay'])) {
      return AssistantReply(_explainSplit());
    }
    if (_matches(q, ['pin', 'biometric', 'lock', 'security'])) {
      return AssistantReply(_explainSecurity());
    }

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
    if (_matches(q, [
      'this week', 'week sales', 'sales this week', 'compared to yesterday',
      'yesterday',
    ])) {
      return AssistantReply(await _weekVsToday());
    }
    if (_matches(q, [
      'best sell', 'top sell', 'what sold most', 'fast moving', 'moving fast',
    ])) {
      return AssistantReply(await _bestSellers());
    }
    if (_matches(q, [
      'not moving', 'slow moving', 'dead stock', 'sitting', 'is not selling',
    ])) {
      return AssistantReply(await _slowMoving());
    }
    if (_matches(q, [
      'losing money', 'below cost', 'low margin', 'worst margin', 'losing on',
    ])) {
      return AssistantReply(await _losingMoney());
    }
    if (_matches(q, ['profit today', 'gross profit', 'how much profit'])) {
      return AssistantReply(await _profitToday());
    }
    if (_matches(q, ['overdue', 'who is overdue', 'late payers', 'long debt'])) {
      return await _whoIsOverdue();
    }
    if (_matches(q, [
      'who owes', 'debtor', 'owed to me', 'customers owe', 'credit balance',
      'collect',
    ])) {
      return await _whoOwesMe();
    }
    if (_matches(q, [
      'who do i owe', 'creditor', 'i owe', 'supplier balance', 'we owe',
    ])) {
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
    if (_matches(q, ['cash should', 'how much cash', 'expected cash'])) {
      return AssistantReply(await _cashPosition());
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
      'Try: "How did I do today?", "Who is overdue?", "Best sellers", '
      '"What is not moving?", or "Who owes me?"',
    );
  }

  Future<String> askText(String raw) async => (await ask(raw)).text;

  bool _matches(String q, List<String> keys) {
    for (final k in keys) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  String _appOverview() {
    return 'Mercate keeps your shop records offline on this phone.\n\n'
        '• Home — today’s sales, expenses, close the day\n'
        '• POS — sell (cash, M-Pesa, card, credit, split) + quick sale\n'
        '• Stock — products and quantities\n'
        '• Customers — credit, debtors & repayments\n'
        '• Suppliers — receive goods (if your profile shows it)\n'
        '• Reports — summary + share PDF\n'
        '• Assistant — answers from your local data only\n\n'
        'Shop profile changes what you see; the same engine runs underneath.';
  }

  String _explainProfiles(String q) {
    final buf = StringBuffer();
    buf.writeln(
      'Profiles change what you see, not how strong Mercate is.\n'
      'Same sales, stock, and debt engine — different focus.\n',
    );
    for (final p in BusinessProfile.all) {
      final label = p.label.toLowerCase();
      final key = p.id.name.toLowerCase();
      if (q.contains(key) ||
          q.contains(label.split('/').first.trim()) ||
          (p.id == BusinessProfileId.mamaMboga && q.contains('mama'))) {
        buf.writeln('${p.label} (${p.interfaceLevel.name})');
        buf.writeln(p.description);
        buf.writeln(
          'Default unit: ${p.defaultUnit}. '
          'Suppliers tab: ${p.features.suppliers ? 'yes' : 'hidden'}.',
        );
        return buf.toString();
      }
    }
    buf.writeln('Available types:\n');
    for (final p in BusinessProfile.all) {
      final status = p.enabled ? '' : ' (later)';
      buf.writeln('• ${p.label}$status — ${p.interfaceLevel.name}');
    }
    return buf.toString();
  }

  String _explainHome() =>
      'Home shows today’s sales, cash vs M-Pesa, expenses, and close day.';
  String _explainPos() =>
      'POS: add products or Quick sale → pay (cash, M-Pesa, card, bank, credit, SPLIT). '
      'M-Pesa/bank need a reference. Void on a receipt reverses stock and debt once.';
  String _explainStock() =>
      'Stock: add products with price, cost, qty, minimum. '
      'Sales reduce stock automatically.';
  String _explainCustomers() =>
      'Customers buy on credit. Debtors list who still owes. '
      'Repayments apply to oldest unpaid sales first.';
  String _explainSuppliers() =>
      'Suppliers: receive goods and track what you owe. '
      'Hidden on simple profiles like Mama mboga.';
  String _explainReports() =>
      'Reports: on-screen summary and Share PDF — offline.';
  String _explainQuickSale() =>
      'Quick sale is for items not in the catalogue. Does not change stock.';
  String _explainCloseDay() =>
      'Close day locks today’s snapshot with counted cash/M-Pesa. '
      'PIN if app lock is on. Once per day.';
  String _explainVoid() =>
      'Void fully reverses a completed sale: stock once, debt reversed, '
      'refund recorded. Needs reason and PIN if lock is on.';
  String _explainSplit() =>
      'SPLIT on checkout: e.g. cash + M-Pesa. Shortfall can go on credit with a customer.';
  String _explainSecurity() =>
      'Settings → PIN / biometrics. Gates day close, profile change, and void.';

  Future<String> _dailyBrief() async {
    final day = await _reports.daySales();
    final debtors = await _debtors.listOutstanding(limit: 50);
    final overdueDays = await _policy.getOverdueDebtDays();
    final overdue =
        await _debtors.listOverdue(overdueDays: overdueDays, limit: 20);
    final low = await _inventory.getLowStockProducts();
    final shop = await _profiles.getBusinessName();

    final debtTotal = debtors.fold<double>(0, (s, d) => s + d.balance);

    return 'Daily brief — $shop (${day.businessDate})\n\n'
        'Sales: ${Money.format(day.salesTotal)} '
        '(${day.saleCount} sales)\n'
        'Cash ${Money.format(day.cash)} · M-Pesa ${Money.format(day.mpesa)}\n'
        'Est. gross profit: ${Money.format(day.grossProfit)}\n'
        'Expenses: ${Money.format(day.expensesTotal)}\n'
        'Customer debt: ${Money.format(debtTotal)} '
        '(${debtors.length} people)\n'
        'Overdue (≥$overdueDays days): ${overdue.length}\n'
        'Low-stock products: ${low.length}\n\n'
        'Ask "Who is overdue?" or "Low stock" for details.';
  }

  Future<String> _todaySales() async {
    final day = await _reports.daySales();
    return 'Sales today (${day.businessDate})\n\n'
        '• ${day.saleCount} sales · total ${Money.format(day.salesTotal)}\n'
        '• Cash ${Money.format(day.cash)}\n'
        '• M-Pesa ${Money.format(day.mpesa)}\n'
        '• Card ${Money.format(day.card)}\n'
        '• New credit ${Money.format(day.creditTotal)}\n'
        '• Est. gross profit ${Money.format(day.grossProfit)}\n'
        '• Expenses ${Money.format(day.expensesTotal)}';
  }

  Future<String> _weekVsToday() async {
    final today = await _reports.daySales();
    final yesterday = await _reports.daySales(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final delta = Money.round(today.salesTotal - yesterday.salesTotal);
    final dir = delta > 0
        ? 'up ${Money.format(delta)} vs yesterday'
        : delta < 0
            ? 'down ${Money.format(-delta)} vs yesterday'
            : 'same as yesterday';
    return 'Today ${Money.format(today.salesTotal)} ($dir)\n'
        'Yesterday ${Money.format(yesterday.salesTotal)} '
        '(${yesterday.saleCount} sales)';
  }

  Future<String> _profitToday() async {
    final day = await _reports.daySales();
    return 'Estimated gross profit today: ${Money.format(day.grossProfit)}\n'
        '(Sales ${Money.format(day.salesTotal)} − cost of goods '
        '${Money.format(day.estimatedCost)})\n'
        'Expenses ${Money.format(day.expensesTotal)} are separate.';
  }

  Future<String> _bestSellers() async {
    final rows = await _topProducts(limit: 10);
    if (rows.isEmpty) {
      return 'No completed sales in the last 30 days to rank products.';
    }
    final buf = StringBuffer('Best sellers (last 30 days):\n\n');
    for (final r in rows) {
      buf.writeln(
        '• ${r['name']}: qty ${_fmt(r['qty'] as double)} · '
        '${Money.format(r['revenue'] as double)}',
      );
    }
    return buf.toString().trim();
  }

  Future<String> _slowMoving() async {
    final stock = await _reports.stockOnHand();
    final soldIds = await _productIdsSoldSince(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    final dead = stock
        .where((s) => s.quantity > 0.001 && !soldIds.contains(s.productId))
        .toList();
    if (dead.isEmpty) {
      return 'No obvious dead stock: products with quantity all sold at least '
          'once in the last 30 days (or stock is empty).';
    }
    final buf = StringBuffer(
      'Not moving (qty on hand, no sale in 30 days):\n\n',
    );
    for (final s in dead.take(15)) {
      buf.writeln(
        '• ${s.name}: ${_fmt(s.quantity)} '
        '(value ${Money.format(s.stockValue)})',
      );
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
             COALESCE(SUM(si.quantity), 0) AS qty,
             COALESCE(SUM(si.total), 0) AS revenue,
             COALESCE(SUM(si.quantity * COALESCE(si.unit_cost, 0)), 0) AS cost
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sale_status = 'completed'
        AND s.created_at >= ?
        AND si.unit_cost IS NOT NULL
      GROUP BY si.product_name
      HAVING revenue + 0.001 < cost
      ORDER BY (cost - revenue) DESC
      LIMIT 10
      ''',
      [since],
    );
    if (rows.isEmpty) {
      return 'No products with recorded cost sold below cost in the last 30 days.\n'
          '(Items without cost are skipped.)';
    }
    final buf = StringBuffer('Sold below cost (last 30 days):\n\n');
    for (final r in rows) {
      final rev = Money.round((r['revenue'] as num?)?.toDouble() ?? 0);
      final cost = Money.round((r['cost'] as num?)?.toDouble() ?? 0);
      buf.writeln(
        '• ${r['name']}: revenue ${Money.format(rev)} · '
        'cost ${Money.format(cost)} · loss ${Money.format(cost - rev)}',
      );
    }
    return buf.toString().trim();
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
      final days = d.daysOpen > 0 ? ' · ${d.daysOpen}d' : '';
      buf.writeln('• ${d.customerName}: ${Money.format(d.balance)}$days');
      final phone = d.phone?.trim();
      if (phone != null && phone.isNotEmpty) {
        actions.add(AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
        ));
        actions.add(AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
          smsBody: DebtorService.collectionSmsBody(
            customerName: d.customerName,
            balance: d.balance,
            shopName: shop,
            daysOpen: d.daysOpen,
          ),
        ));
      }
    }
    if (list.length > 10) {
      buf.writeln('… and more in Customers → Debtors');
    }
    buf.writeln('\nUse Call / SMS below when a phone number is saved.');
    return AssistantReply(
      buf.toString().trim(),
      actions: actions.take(6).toList(),
    );
  }

  Future<AssistantReply> _whoIsOverdue() async {
    final days = await _policy.getOverdueDebtDays();
    final list = await _debtors.listOverdue(overdueDays: days, limit: 15);
    if (list.isEmpty) {
      return AssistantReply(
        'No overdue debtors (threshold $days days).\n'
        'You can change this in Settings.',
      );
    }
    final total = list.fold<double>(0, (s, d) => s + d.balance);
    final buf = StringBuffer(
      'Overdue (≥$days days) — total ${Money.format(total)}:\n\n',
    );
    final actions = <AssistantAction>[];
    final shop = await _profiles.getBusinessName();
    for (final d in list.take(10)) {
      buf.writeln(
        '• ${d.customerName}: ${Money.format(d.balance)} · ${d.daysOpen} days',
      );
      final phone = d.phone?.trim();
      if (phone != null && phone.isNotEmpty) {
        actions.add(AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
        ));
        actions.add(AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${d.customerName}',
          phone: phone,
          customerName: d.customerName,
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
    if (list.isEmpty) {
      return 'You do not owe any supplier right now.';
    }
    final total = list.fold<double>(0, (s, r) => s + r.balance);
    final lines = list
        .take(10)
        .map((c) => '• ${c.name}: ${Money.format(c.balance)}')
        .join('\n');
    return 'Suppliers you owe (total ${Money.format(total)}):\n\n$lines'
        '${list.length > 10 ? '\n… and more in Suppliers → Creditors' : ''}';
  }

  Future<String> _lowStock() async {
    final low = await _inventory.getLowStockProducts();
    if (low.isEmpty) {
      return 'No products are at or below minimum stock right now.\n'
          '(Set minimum stock on products to get alerts.)';
    }
    final buf = StringBuffer('Low stock:\n\n');
    for (final p in low.take(15)) {
      final qty = await _inventory.getStock(p.id);
      buf.writeln('• ${p.name}: ${_fmt(qty)} (min ${p.minimumStock})');
    }
    return buf.toString().trim();
  }

  Future<String> _expensesToday() async {
    final summary = await _closing.getSummary(DateTime.now());
    return 'Expenses today: ${Money.format(summary.expensesTotal)}\n'
        '(Cash expenses: ${Money.format(summary.expensesCash)})';
  }

  Future<String> _stockValue() async {
    final stock = await _reports.stockOnHand();
    final value = stock.fold<double>(0, (s, r) => s + r.stockValue);
    return 'Stock on hand: ${stock.length} products\n'
        'Value at cost: ${Money.format(value)}';
  }

  Future<String> _cashPosition() async {
    final day = await _reports.daySales();
    return 'From completed sales today:\n'
        '• Cash recorded ${Money.format(day.cash)}\n'
        '• M-Pesa recorded ${Money.format(day.mpesa)}\n'
        'Close the day on Home to compare with counted till.';
  }

  Future<AssistantReply> _contactIntent(String q) async {
    final list = await _debtors.listOutstanding(limit: 50);
    if (list.isEmpty) {
      return const AssistantReply(
        'No debtors with balances to call or message.',
      );
    }
    DebtorSummary? match;
    for (final d in list) {
      final name = d.customerName.toLowerCase();
      final parts = name.split(RegExp(r'\s+'));
      for (final p in parts) {
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
        '${match.customerName} owes ${Money.format(match.balance)}, '
        'but has no phone number saved. Add a phone under Customers.',
      );
    }
    final shop = await _profiles.getBusinessName();
    final body = DebtorService.collectionSmsBody(
      customerName: match.customerName,
      balance: match.balance,
      shopName: shop,
      daysOpen: match.daysOpen,
    );
    final wantSms =
        q.contains('sms') || q.contains('message') || q.contains('text');
    return AssistantReply(
      '${match.customerName} owes ${Money.format(match.balance)}'
      '${match.daysOpen > 0 ? ' (${match.daysOpen} days)' : ''}.\n'
      'Phone: $phone\n\n'
      'I will not call or send anything until you tap a button.',
      actions: [
        if (!wantSms)
          AssistantAction(
            kind: AssistantActionKind.call,
            label: 'Call ${match.customerName}',
            phone: phone,
            customerName: match.customerName,
          ),
        AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${match.customerName}',
          phone: phone,
          customerName: match.customerName,
          smsBody: body,
        ),
        if (wantSms)
          AssistantAction(
            kind: AssistantActionKind.call,
            label: 'Call ${match.customerName}',
            phone: phone,
            customerName: match.customerName,
          ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _topProducts({int limit = 10}) async {
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
      ORDER BY qty DESC
      LIMIT ?
      ''',
      [since, limit],
    );
    return rows
        .map(
          (r) => {
            'name': r['name'] as String? ?? 'Item',
            'qty': (r['qty'] as num?)?.toDouble() ?? 0.0,
            'revenue': Money.round((r['revenue'] as num?)?.toDouble() ?? 0),
          },
        )
        .toList();
  }

  Future<Set<String>> _productIdsSoldSince(DateTime since) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT si.product_id AS id
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sale_status = 'completed'
        AND s.created_at >= ?
        AND si.product_id IS NOT NULL
      ''',
      [since.toIso8601String()],
    );
    return rows
        .map((r) => r['id'] as String?)
        .whereType<String>()
        .toSet();
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
