import '../core/utils/money.dart';
import 'day_closing_service.dart';
import 'inventory_service.dart';
import 'report_service.dart';

/// Simple offline, rule-based assistant — no network, no AI model.
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

  /// Suggested chips shown in the UI.
  static const List<String> suggestions = [
    'How does this app work?',
    'What did I sell today?',
    'Who owes me?',
    'Who do I owe?',
    'Low stock',
    'Explain Home',
    'Explain POS',
    'Explain Stock',
    'Explain Customers',
    'Explain Suppliers',
    'Explain Reports',
  ];

  Future<String> ask(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return 'Ask me about sales, stock, debtors, or how each screen works.';
    }

    if (_matches(q, [
      'how does', 'how do i', 'how this app', 'help', 'guide',
      'what can you', 'what can this',
    ])) {
      return _appOverview();
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
        '"Low stock", or "How does this app work?"';
  }

  bool _matches(String q, List<String> keys) {
    for (final k in keys) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  String _appOverview() {
    return '''This app keeps your shop records offline on the phone.

• Home — today’s sales, expenses, close the day
• POS — sell (cash, M-Pesa, card, credit) + quick sale
• Stock — products and quantities
• Customers — people who buy on credit; debtors & repayments
• Suppliers — receive goods; creditors & pay suppliers
• Reports — summary + share PDF
• Assistant (this chat) — answers from your local data

Everything stays on the device. No internet required for normal use.''';
  }

  String _explainHome() {
    return '''Home (Dashboard)

Shows today’s sales total, cash vs M-Pesa, and expenses.

• Tap Expense to record transport, rent, utilities, etc.
• Close day: enter opening cash and counted cash/M-Pesa. The app compares that to expected amounts from sales and cash expenses.''';
  }

  String _explainPos() {
    return '''POS (Point of Sale)

1. Search or tap products into the cart (stock must be available).
2. Flash icon = Quick sale (not in catalogue; does not change stock).
3. Pay — cash, M-Pesa, card, or credit (pick a customer if balance remains).
4. History icon — past sales and receipts.

A completed sale updates stock, payments, debtors (if credit), and the audit log in one step.''';
  }

  String _explainStock() {
    return '''Stock (Inventory)

• + adds a product (name, selling price, optional cost & opening stock).
• Add box icon receives more stock for a product.

Stock is a ledger of movements (purchases, sales, adjustments) — not a single editable number — so history stays accurate.''';
  }

  String _explainCustomers() {
    return '''Customers & debtors

• Add customers you sell to on credit.
• Wallet icon opens Debtors (who still owes you).
• Tap a customer for their statement; use Repay for cash/M-Pesa/card.

Repayments apply to the oldest unpaid sales first (FIFO).''';
  }

  String _explainSuppliers() {
    return '''Suppliers & creditors

• Add suppliers, then Receive goods (inbox icon).
• Choose products, quantities, unit costs; paid now can be 0 (full credit).
• Stock increases and average cost updates.
• Balance icon lists Creditors; Pay reduces what you owe (FIFO on purchases).''';
  }

  String _explainReports() {
    return '''Reports

On-screen: today’s sales mix, estimated gross profit, expenses, stock value, debtors, creditors.

PDF icon / Share PDF — offline A4 report you can send via WhatsApp, Files, etc.''';
  }

  String _explainQuickSale() {
    return '''Quick sale

For items not in your catalogue (or one-off services).

• Does not reduce inventory.
• Still appears on the receipt as “(quick sale)”.
• Prefer catalogue products when you track stock.''';
  }

  String _explainCloseDay() {
    return '''Close day (on Home)

Locks a snapshot for the calendar day:
• Opening cash in the till
• Counted cash and M-Pesa

Expected cash ≈ opening + cash sales − cash expenses.
You can only close once per day.''';
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
