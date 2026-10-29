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
    'Recent calls',
    'Call log today',
    'Best sellers',
    'Low stock',
  ];

  static const Map<String, String> contactOutcomeLabels = {
    'no_answer': 'No answer',
    'spoke': 'Spoke',
    'busy': 'Busy',
    'wrong_number': 'Wrong number',
    'promised_tomorrow': 'Promised tomorrow',
    'promised_friday': 'Promised Friday',
    'will_pay_later': 'Will pay later',
    'paid_partial': 'Paid partial',
    'unreachable': 'Unreachable',
  };

  Future<AssistantReply> ask(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return const AssistantReply(
        'Ask about sales, debt, stock, or who owes you.\n'
        'Try: Call Mary · Called Mary, no answer · Recent calls',
      );
    }

    if (_matches(q, ['how does', 'how do i', 'help', 'guide', 'what can you'])) {
      return const AssistantReply(
        'I summarise sales and debt offline. I can open Call/SMS with your OK, '
        'log how the call went, and save promises. Money changes need Confirm.',
      );
    }

    if (_matches(q, ['who promised', 'promises today', 'promised to pay today', 'list promises'])) {
      return await _promisesDue();
    }

    if (_matches(q, ['recent calls', 'call log', 'calls today', 'who did i call', 'contact log'])) {
      return await _recentCallLog();
    }

    final callLog = await _tryLogCallOutcome(q);
    if (callLog != null) return callLog;

    final callAct = await _tryCallCustomer(q);
    if (callAct != null) return callAct;

    final write = await _tryWriteIntent(q);
    if (write != null) return write;

    if (_matches(q, ['how did i do', 'daily brief', 'summary today'])) {
      return AssistantReply(await _dailyBrief());
    }
    if (_matches(q, ['sell today', 'sales today', 'what did i sell', 'sold today'])) {
      return AssistantReply(await _todaySales());
    }
    if (_matches(q, ['overdue', 'who is overdue'])) {
      return await _whoIsOverdue();
    }
    if (_matches(q, ['who owes', 'debtor', 'customers owe', 'collect'])) {
      return await _whoOwesMe();
    }
    if (_matches(q, ['low stock', 'out of stock', 'reorder'])) {
      return AssistantReply(await _lowStock());
    }

    return const AssistantReply(
      'Try: "Who owes me?", "Call Mary", "Called Mary, no answer", "Recent calls".',
    );
  }

  Future<String> executeWrite(AssistantWriteKind kind, Map<String, dynamic> payload) async {
    switch (kind) {
      case AssistantWriteKind.recordRepayment:
        await _debtors.recordRepayment(
          customerId: payload['customerId'] as String,
          amount: (payload['amount'] as num).toDouble(),
          paymentType: payload['paymentType'] as String? ?? 'cash',
          notes: 'Recorded via Assistant',
        );
        return 'Recorded ${Money.format((payload['amount'] as num).toDouble())} from ${payload['customerName']}.';
      case AssistantWriteKind.addStock:
        await _inventory.addStock(
          productId: payload['productId'] as String,
          quantity: (payload['quantity'] as num).toDouble(),
          unitCost: payload['unitCost'] != null ? (payload['unitCost'] as num).toDouble() : null,
          movementType: 'purchase_received',
          reason: 'Added via Assistant',
        );
        return 'Added stock for ${payload['productName']}.';
      case AssistantWriteKind.recordPromise:
        await _collection.recordPromise(
          customerId: payload['customerId'] as String,
          promisedDate: DateTime.parse(payload['promisedDate'] as String),
          amount: payload['amount'] != null ? (payload['amount'] as num).toDouble() : null,
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

  String? _parseContactOutcome(String q) {
    if (q.contains('no answer') || q.contains("didn't answer") || q.contains('did not answer')) {
      return 'no_answer';
    }
    if (q.contains('unreachable') || q.contains('switched off')) return 'unreachable';
    if (q.contains('wrong number')) return 'wrong_number';
    if (q.contains('busy') || q.contains('engaged')) return 'busy';
    if (q.contains('promised tomorrow') || (q.contains('promise') && q.contains('tomorrow'))) {
      return 'promised_tomorrow';
    }
    if (q.contains('promised friday') || (q.contains('promise') && q.contains('friday'))) {
      return 'promised_friday';
    }
    if (q.contains('will pay') || q.contains('pay later')) return 'will_pay_later';
    if (q.contains('partial')) return 'paid_partial';
    if (q.contains('spoke') || q.contains('talked') || q.contains('answered')) return 'spoke';
    return null;
  }

  Future<AssistantReply?> _tryLogCallOutcome(String q) async {
    final looksLikeLog = q.contains('called') ||
        q.contains('spoke to') ||
        q.contains('spoke with') ||
        q.contains('talked to') ||
        q.contains('log call') ||
        q.contains('call result') ||
        (q.contains('sms') && (q.contains('sent') || q.contains('messaged')));
    if (!looksLikeLog) return null;

    final outcome = _parseContactOutcome(q);
    final customer = await _resolveCustomerName(q);
    if (customer == null) {
      return const AssistantReply(
        'Name the customer, e.g. "Called Mary, no answer" or "Spoke to John, promised Friday".',
      );
    }
    if (outcome == null) {
      return AssistantReply(
        'How did it go with ${customer.name}? e.g. "Called ${customer.name}, no answer".',
      );
    }

    final channel = (q.contains('sms') || q.contains('texted')) ? 'sms' : 'call';
    await _collection.logCommunication(
      partyType: 'customer',
      partyId: customer.id,
      partyName: customer.name,
      channel: channel,
      result: outcome,
      notes: 'Logged via assistant',
    );

    var extra = '';
    if (outcome == 'promised_tomorrow' || outcome == 'promised_friday') {
      final when = outcome == 'promised_tomorrow'
          ? DateTime.now().add(const Duration(days: 1))
          : _nextWeekday(DateTime.friday);
      await _collection.recordPromise(customerId: customer.id, promisedDate: when);
      extra = '\nPromise saved for ${when.toIso8601String().substring(0, 10)}.';
    }

    final label = contactOutcomeLabels[outcome] ?? outcome;
    return AssistantReply('Logged $channel with ${customer.name}: $label.$extra');
  }

  DateTime _nextWeekday(int weekday) {
    var d = DateTime.now();
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != weekday);
    return d;
  }

  Future<AssistantReply?> _tryCallCustomer(String q) async {
    final isCall = RegExp(r'\b(call|phone|dial)\b').hasMatch(q) &&
        !q.contains('called') &&
        !q.contains('log') &&
        !q.contains('recent');
    if (!isCall) return null;

    final customer = await _resolveCustomerName(q);
    if (customer == null) {
      return const AssistantReply('Who should I call? e.g. "Call Mary".');
    }
    final c = await _customers.getCustomer(customer.id);
    final phone = c?.phone?.trim();
    if (phone == null || phone.isEmpty) {
      return AssistantReply('${customer.name} has no phone number under Customers.');
    }
    final balance = await _debtors.getBalance(customer.id);
    final shop = await _profiles.getBusinessName();
    return AssistantReply(
      'Open dialer for ${customer.name} ($phone)?'
      '${balance > 0 ? '\nThey owe ${Money.format(balance)}.' : ''}\n'
      'Confirm below — then I ask how the call went.',
      actions: [
        AssistantAction(
          kind: AssistantActionKind.call,
          label: 'Call ${customer.name}',
          phone: phone,
          customerName: customer.name,
          customerId: customer.id,
        ),
        AssistantAction(
          kind: AssistantActionKind.sms,
          label: 'SMS ${customer.name}',
          phone: phone,
          customerName: customer.name,
          customerId: customer.id,
          smsBody: DebtorService.collectionSmsBody(
            customerName: customer.name,
            balance: balance,
            shopName: shop,
            daysOpen: 0,
          ),
        ),
      ],
    );
  }

  Future<AssistantReply> _recentCallLog() async {
    final list = await _collection.recentCommunications(limit: 20);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final todays = list.where((e) => !e.createdAt.isBefore(start)).toList();
    final use = todays.isNotEmpty ? todays : list.take(12).toList();
    if (use.isEmpty) {
      return const AssistantReply(
        'No calls logged yet. After Call, pick an outcome — or say "Called Mary, no answer".',
      );
    }
    final buf = StringBuffer(todays.isNotEmpty ? 'Contact log today:\n\n' : 'Recent contacts:\n\n');
    for (final e in use) {
      final label = contactOutcomeLabels[e.result ?? ''] ?? (e.result ?? '—');
      final when =
          '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
      buf.writeln('• ${e.partyName ?? 'Unknown'} · ${e.channel} · $label · $when');
    }
    return AssistantReply(buf.toString().trim());
  }

  Future<AssistantReply?> _tryWriteIntent(String q) async {
    if (_matches(q, ['paid', 'record payment', 'received from'])) {
      final amount = _extractAmount(q);
      if (amount == null || amount <= 0) {
        return const AssistantReply('Include customer and amount to record a payment.');
      }
      var type = 'cash';
      if (q.contains('mpesa') || q.contains('m-pesa')) type = 'mpesa';
      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return const AssistantReply('Could not match a customer name.');
      }
      final balance = await _debtors.getBalance(customer.id);
      if (balance <= 0) {
        return AssistantReply('${customer.name} has no outstanding balance.');
      }
      return AssistantReply(
        'Confirm payment:\n• ${customer.name}\n• ${Money.format(amount)} $type',
        actions: [
          AssistantAction(
            kind: AssistantActionKind.confirmWrite,
            label: 'Confirm payment',
            writeKind: AssistantWriteKind.recordRepayment,
            writePayload: {
              'customerId': customer.id,
              'customerName': customer.name,
              'amount': amount,
              'paymentType': type,
            },
          ),
          const AssistantAction(kind: AssistantActionKind.cancelWrite, label: 'Cancel'),
        ],
      );
    }

    if (_matches(q, ['promised', 'promise ']) &&
        !q.contains('who') &&
        !q.contains('list')) {
      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return const AssistantReply('Name a customer, e.g. "Mary promised Friday".');
      }
      final date = _extractRelativeDate(q) ?? DateTime.now().add(const Duration(days: 1));
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().substring(0, 10);
      return AssistantReply(
        'Confirm promise:\n• ${customer.name}\n• $dateStr',
        actions: [
          AssistantAction(
            kind: AssistantActionKind.confirmWrite,
            label: 'Confirm promise',
            writeKind: AssistantWriteKind.recordPromise,
            writePayload: {
              'customerId': customer.id,
              'customerName': customer.name,
              'promisedDate': dateStr,
            },
          ),
          const AssistantAction(kind: AssistantActionKind.cancelWrite, label: 'Cancel'),
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
    for (final m in re.allMatches(q).toList().reversed) {
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
        if (!d.isAfter(now) && d.day == now.day) d = d.add(const Duration(days: 7));
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
    final overdue = await _debtors.listOverdue(overdueDays: overdueDays, limit: 20);
    final promises = await _collection.listOpenPromises(onOrBefore: DateTime.now());
    final low = await _inventory.getLowStockProducts();
    final shop = await _profiles.getBusinessName();
    final debtTotal = debtors.fold<double>(0, (s, d) => s + d.balance);
    return 'Daily brief — $shop (${day.businessDate})\n\n'
        'Sales: ${Money.format(day.salesTotal)} (${day.saleCount})\n'
        'Cash ${Money.format(day.cash)} · M-Pesa ${Money.format(day.mpesa)}\n'
        'Customer debt: ${Money.format(debtTotal)}\n'
        'Overdue: ${overdue.length} · Promises due: ${promises.length} · Low stock: ${low.length}';
  }

  Future<String> _todaySales() async {
    final day = await _reports.daySales();
    return 'Sales today (${day.businessDate})\n'
        '• ${day.saleCount} · ${Money.format(day.salesTotal)}\n'
        '• Cash ${Money.format(day.cash)} · M-Pesa ${Money.format(day.mpesa)}';
  }

  Future<AssistantReply> _promisesDue() async {
    final list = await _collection.listOpenPromises(onOrBefore: DateTime.now());
    if (list.isEmpty) {
      return const AssistantReply('No promises due today or earlier.');
    }
    final buf = StringBuffer('Promises due by today:\n\n');
    for (final p in list.take(10)) {
      final name = p.customerName ?? p.customerId;
      buf.writeln('• $name — ${p.promisedDate.toIso8601String().substring(0, 10)}');
    }
    return AssistantReply(buf.toString().trim());
  }

  Future<AssistantReply> _whoOwesMe() async {
    final list = await _debtors.listOutstanding(limit: 15);
    if (list.isEmpty) return const AssistantReply('No one owes you right now.');
    final total = list.fold<double>(0, (s, d) => s + d.balance);
    final buf = StringBuffer('Who owes you (${Money.format(total)}):\n\n');
    final actions = <AssistantAction>[];
    final shop = await _profiles.getBusinessName();
    for (final d in list.take(8)) {
      buf.writeln('• ${d.customerName}: ${Money.format(d.balance)}');
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
    return AssistantReply(buf.toString().trim(), actions: actions.take(6).toList());
  }

  Future<AssistantReply> _whoIsOverdue() async {
    final days = await _policy.getOverdueDebtDays();
    final list = await _debtors.listOverdue(overdueDays: days, limit: 15);
    if (list.isEmpty) {
      return AssistantReply('No overdue debtors (threshold $days days).');
    }
    final buf = StringBuffer('Overdue (≥$days days):\n\n');
    for (final d in list.take(10)) {
      buf.writeln('• ${d.customerName}: ${Money.format(d.balance)} · ${d.daysOpen}d');
    }
    return AssistantReply(buf.toString().trim());
  }

  Future<String> _lowStock() async {
    final low = await _inventory.getLowStockProducts();
    if (low.isEmpty) return 'No low-stock items right now.';
    final buf = StringBuffer('Low stock:\n');
    for (final p in low.take(12)) {
      final q = await _inventory.getStock(p.id);
      buf.writeln('• ${p.name}: $q (min ${p.minimumStock})');
    }
    return buf.toString().trim();
  }
}
