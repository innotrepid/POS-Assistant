import '../core/models/business_profile.dart';
import '../core/utils/money.dart';
import 'day_closing_service.dart';
import 'inventory_service.dart';
import 'report_service.dart';

/// Offline rule-based assistant for Mercate — no network, no AI model.
class AssistantService {
  AssistantService({
    ReportService? reports,
    InventoryService? inventory,
    DayClosingService? closing,
  })  : _reports = reports ?? ReportService(),
        _inventory = inventory ?? InventoryService(),
        _closing = closing ?? DayClosingService();

  final ReportService _reports;
  final InventoryService _inventory;
  final DayClosingService _closing;

  static const List<String> suggestions = [
    'How does Mercate work?',
    'Explain business profiles',
    'What did I sell today?',
    'Who owes me?',
    'Who do I owe?',
    'Low stock',
    'Explain POS',
    'Explain Stock',
    'Explain void / refund',
    'Explain split payment',
  ];

  Future<String> ask(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return 'Ask me about sales, stock, debt, profiles, or how each screen works.';
    }

    if (_matches(q, [
      'how does', 'how do i', 'how this app', 'help', 'guide',
      'what can you', 'what can this', 'mercate work',
    ])) {
      return _appOverview();
    }

    if (_matches(q, [
      'business profile', 'explain profile', 'profiles',
      'mama mboga', 'which profile', 'shop type',
    ])) {
      return _explainProfiles(q);
    }

    if (_matches(q, ['explain home', 'explain dashboard', 'what is home'])) {
      return _explainHome();
    }
    if (_matches(q, ['explain pos', 'what is pos', 'point of sale'])) {
      return _explainPos();
    }
    if (_matches(q, ['explain stock', 'explain inventory', 'what is stock'])) {
      return _explainStock();
    }
    if (_matches(q, [
      'explain customer', 'explain debtor', 'what is customer',
    ])) {
      return _explainCustomers();
    }
    if (_matches(q, [
      'explain supplier', 'explain creditor', 'what is supplier',
    ])) {
      return _explainSuppliers();
    }
    if (_matches(q, ['explain report', 'what is report', 'pdf'])) {
      return _explainReports();
    }
    if (_matches(q, ['quick sale', 'explain quick'])) {
      return _explainQuickSale();
    }
    if (_matches(q, ['close day', 'closing', 'end of day'])) {
      return _explainCloseDay();
    }
    if (_matches(q, ['void', 'refund'])) {
      return _explainVoid();
    }
    if (_matches(q, ['split payment', 'split pay'])) {
      return _explainSplit();
    }
    if (_matches(q, ['pin', 'biometric', 'lock', 'security'])) {
      return _explainSecurity();
    }

    if (_matches(q, [
      'sell today', 'sales today', 'what did i sell', 'today sales',
      'sold today',
    ])) {
      return _todaySales();
    }

    if (_matches(q, [
      'who owes', 'debtor', 'owed to me', 'customers owe', 'credit balance',
    ])) {
      return _whoOwesMe();
    }

    if (_matches(q, [
      'who do i owe', 'creditor', 'i owe', 'supplier balance', 'we owe',
    ])) {
      return _whoIOwe();
    }

    if (_matches(q, ['low stock', 'out of stock', 'reorder', 'running out'])) {
      return _lowStock();
    }

    if (_matches(q, ['expense', 'expenses today'])) {
      return _expensesToday();
    }

    if (_matches(q, ['stock value', 'inventory value'])) {
      return _stockValue();
    }

    return 'I did not understand that yet.\n\n'
        'Try: "What did I sell today?", "Who owes me?", '
        '"Explain business profiles", or "How does Mercate work?"';
  }

  bool _matches(String q, List<String> keys) {
    for (final k in keys) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  String _appOverview() {
    return '''Mercate keeps your shop records offline on this phone.

• Home — today’s sales, expenses, close the day
• POS — sell (cash, M-Pesa, card, credit, split) + quick sale
• Stock — products and quantities
• Customers — credit sales, debtors & repayments
• Suppliers — receive goods; creditors (if your profile shows it)
• Reports — summary + share PDF
• Assistant — answers from your local data

Shop profile focuses the screens for your business type — the same engine runs underneath.\n\nAsk “Explain business profiles” for details.''';
  }

  String _explainProfiles(String q) {
    final buf = StringBuffer();
    buf.writeln(
      'Profiles change what you see, not how strong Mercate is.\n'
      'Same sales, stock, and debt engine — different focus.\n',
    );

    // Specific profile if named
    for (final p in BusinessProfile.all) {
      final label = p.label.toLowerCase();
      final key = p.id.name.toLowerCase();
      if (q.contains(key) ||
          q.contains(label.split('/').first.trim()) ||
          (p.id == BusinessProfileId.mamaMboga && q.contains('mama'))) {
        buf.writeln('**${p.label}** (${p.interfaceLevel.name})');
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
    buf.writeln(
      '\nExample: Mama mboga gets sell, stock, customers, debts, '
      'M-Pesa — without supplier complexity.\n'
      'Duka adds suppliers, categories, barcodes.\n'
      'Pharmacy turns on batch/expiry defaults.\n\n'
      'Ask “mama mboga profile” or “pharmacy profile” for one type.',
    );
    return buf.toString();
  }

  String _explainHome() {
    return '''Home

Today’s sales, cash vs M-Pesa, expenses.\n'
        'Expense button records costs. Close day counts the till.\n'
        'Notifications and settings are in the top bar.''';
  }

  String _explainPos() {
    return '''POS

1. Add products (or Quick sale for one-offs).
2. Pay — cash, M-Pesa, card, bank, credit, or SPLIT.
3. M-Pesa/bank need a reference.
4. History for receipts; Void on a receipt reverses stock and debt once.''';
  }

  String _explainStock() {
    return '''Stock

Add products with price, cost, opening qty, and minimum stock (for alerts).
Add stock when goods arrive. Sales reduce stock automatically.''';
  }

  String _explainCustomers() {
    return '''Customers

People who buy on credit. Debtors list who still owes.
Repayments apply to oldest unpaid sales first.''';
  }

  String _explainSuppliers() {
    return '''Suppliers

Receive goods, track what you owe (creditors).
Shown when your profile includes suppliers (e.g. Duka, not Mama mboga).''';
  }

  String _explainReports() {
    return '''Reports

On-screen summary and Share PDF for WhatsApp or Files — all offline.''';
  }

  String _explainQuickSale() {
    return '''Quick sale — items not in the catalogue. Does not change stock.''';
  }

  String _explainCloseDay() {
    return '''Close day — lock today’s snapshot with counted cash/M-Pesa.
Requires PIN/biometrics if app lock is on. Once per day.''';
  }

  String _explainVoid() {
    return '''Void (on a receipt)

Full reverse of a completed sale: stock restored once, debt reversed,
money marked refunded. Needs a reason and PIN if lock is on.
Cannot void twice.''';
  }

  String _explainSplit() {
    return '''Split payment

On checkout choose SPLIT. Add legs (e.g. cash 400 + M-Pesa 600).
Shortfall can go on credit if a customer is selected.''';
  }

  String _explainSecurity() {
    return '''Settings → Set PIN → Require unlock.
Optional biometrics. Gates day close, profile change, and void.''';
  }

  Future<String> _todaySales() async {
    final day = await _reports.daySales();
    return '''Sales today (${day.businessDate})

• ${day.saleCount} sales · total ${Money.format(day.salesTotal)}
• Cash ${Money.format(day.cash)}
• M-Pesa ${Money.format(day.mpesa)}
• Card ${Money.format(day.card)}
• New credit ${Money.format(day.creditTotal)}
• Est. gross profit ${Money.format(day.grossProfit)}
• Expenses ${Money.format(day.expensesTotal)}''';
  }

  Future<String> _whoOwesMe() async {
    final list = await _reports.debtorsOutstanding();
    if (list.isEmpty) {
      return 'No one owes you right now.';
    }
    final total = list.fold<double>(0, (s, r) => s + r.balance);
    final lines = list
        .take(10)
        .map((d) => '• ${d.name}: ${Money.format(d.balance)}')
        .join('\n');
    return 'Customers who owe you (total ${Money.format(total)}):\n\n$lines'
        '${list.length > 10 ? '\n… and more in Customers → Debtors' : ''}';
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
      buf.writeln(
        '• ${p.name}: $qty (min ${p.minimumStock})',
      );
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
}
