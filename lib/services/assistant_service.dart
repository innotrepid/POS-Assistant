import '../core/database/app_database.dart';
import '../core/models/business_profile.dart';
import '../core/utils/money.dart';
import 'business_profile_service.dart';
import 'collection_service.dart';
import 'customer_service.dart';
import 'day_closing_service.dart';
import 'debtor_service.dart';
import 'inventory_service.dart';
import 'locale_service.dart';
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

  static List<String> get suggestions {
    final s = localeController.s;
    if (s.isSw) {
      return [
        'Nimefanyaje leo?',
        'Nimeuza nini leo?',
        'Mauzo ya wiki hii',
        'Mwenendo wa mwezi',
        'Biashara inaendaje?',
        'Siku bora wiki hii',
        'Saa za shughuli leo',
        'Nani anadeni?',
        'Nani amechelewa?',
        'Nani ameahidi leo?',
        'Simu za hivi karibuni',
        'Bidhaa zimepungua',
      ];
    }
    return [
      'How did I do today?',
      'What did I sell today?',
      'This week sales',
      'This month trend',
      'How is business doing?',
      'Best day this week',
      'Busy hours today',
      'Who owes me?',
      'Who is overdue?',
      'Who promised to pay today?',
      'Recent calls',
      'Low stock',
    ];
  }

  static Map<String, String> get contactOutcomeLabels {
    final s = localeController.s;
    return {
      'no_answer': s.outcomeNoAnswer,
      'spoke': s.outcomeSpoke,
      'busy': s.outcomeBusy,
      'wrong_number': s.outcomeWrongNumber,
      'promised_tomorrow': s.outcomePromisedTomorrow,
      'promised_friday': s.outcomePromisedFriday,
      'will_pay_later': s.outcomeWillPayLater,
      'paid_partial': s.outcomePaidPartial,
      'unreachable': s.outcomeUnreachable,
    };
  }

  Future<String> reply(String raw) async => (await ask(raw)).text;

  Future<AssistantReply> ask(String raw) async {
    try {
      return await _askImpl(raw);
    } catch (e) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Hitilafu kusoma data ya duka. Fungua programu mara moja kisha jaribu tena.\n($e)'
            : 'Something went wrong reading shop data. Open the app once to finish setup, then try again.\n($e)',
      );
    }
  }

  Future<AssistantReply> _askImpl(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Uliza kuhusu mauzo, mwenendo, deni, bidhaa, au nani anadeni.\n'
                'Jaribu: Wiki hii · Biashara inaendaje · Piga Mary · Bidhaa zimepungua'
            : 'Ask about sales, trends, debt, stock, or who owes you.\n'
                'Try: This week · How is business · Call Mary · Low stock',
      );
    }

    if (_matches(q, ['how does', 'how do i', 'help', 'guide', 'what can you'])) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Msaidizi wa Mercate anafanya kazi bila mtandao kwenye data ya duka lako.\n'
                'Uliza kuhusu leo, wiki, mwezi, saa za shughuli, deni, na bidhaa.\n'
                'Mabadiliko ya fedha yanahitaji Thibitisha.'
            : 'Mercate Assistant works offline on your shop data.\n'
                'Ask about today, this week, this month, busy hours, debt, and stock.\n'
                'Money changes always need Confirm.',
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

    if (_matches(q, [
      'this week', 'week sales', 'weekly', 'this month', 'month sales', 'monthly',
      'last 30', '30 days', 'trend', 'trends', 'how is business', 'business doing',
      'how am i doing', 'compare week', 'best day', 'worst day', 'busy hours',
      'peak hours', 'slow hours', 'predict', 'outlook', 'forecast',
      'wiki hii', 'mauzo ya wiki', 'mwezi', 'biashara', 'saa za shughuli',
      'nimefanyaje', 'mwenendo',
    ])) {
      return AssistantReply(await _trendsBrief(q));
    }
    if (_matches(q, ['how did i do', 'daily brief', 'summary today', 'nimefanyaje', 'muhtasari'])) {
      return AssistantReply(await _dailyBrief());
    }
    if (_matches(q, ['sell today', 'sales today', 'what did i sell', 'sold today', 'nimeuza', 'mauzo leo'])) {
      return AssistantReply(await _todaySales());
    }
    if (_matches(q, ['overdue', 'who is overdue', 'amechelewa'])) {
      return await _whoIsOverdue();
    }
    if (_matches(q, ['who owes', 'debtor', 'customers owe', 'collect', 'anadeni', 'nani anadeni'])) {
      return await _whoOwesMe();
    }
    if (_matches(q, ['low stock', 'out of stock', 'reorder', 'zimepungua', 'bidhaa zimepungua'])) {
      return AssistantReply(await _lowStock());
    }

    return AssistantReply(
      localeController.isSwahili
          ? 'Jaribu: "Wiki hii", "Biashara inaendaje?", "Saa za shughuli", "Nani anadeni?", "Piga Mary".'
          : 'Try: "This week", "How is business?", "Busy hours", "Who owes me?", "Call Mary".',
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
        return localeController.isSwahili
            ? 'Imerekodi ${Money.format((payload['amount'] as num).toDouble())} kutoka ${payload['customerName']}.'
            : 'Recorded ${Money.format((payload['amount'] as num).toDouble())} from ${payload['customerName']}.';
      case AssistantWriteKind.addStock:
        await _inventory.addStock(
          productId: payload['productId'] as String,
          quantity: (payload['quantity'] as num).toDouble(),
          unitCost: payload['unitCost'] != null ? (payload['unitCost'] as num).toDouble() : null,
          movementType: 'purchase_received',
          reason: 'Added via Assistant',
        );
        return localeController.isSwahili
            ? 'Imeongezwa stock ya ${payload['productName']}.'
            : 'Added stock for ${payload['productName']}.';
      case AssistantWriteKind.recordPromise:
        await _collection.recordPromise(
          customerId: payload['customerId'] as String,
          promisedDate: DateTime.parse(payload['promisedDate'] as String),
          amount: payload['amount'] != null ? (payload['amount'] as num).toDouble() : null,
        );
        return localeController.isSwahili
            ? 'Ahadi imehifadhiwa kwa ${payload['customerName']}.'
            : 'Saved promise for ${payload['customerName']}.';
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
    if (q.contains('no answer') || q.contains('hakujibu') || q.contains("didn't answer")) {
      return 'no_answer';
    }
    if (q.contains('unreachable') || q.contains('haipatikani')) return 'unreachable';
    if (q.contains('wrong number') || q.contains('nambari si')) return 'wrong_number';
    if (q.contains('busy') || q.contains('inatumika')) return 'busy';
    if (q.contains('promised tomorrow') || q.contains('ameahidi kesho')) {
      return 'promised_tomorrow';
    }
    if (q.contains('promised friday') || q.contains('ameahidi ijumaa')) {
      return 'promised_friday';
    }
    if (q.contains('will pay') || q.contains('atatoa')) return 'will_pay_later';
    if (q.contains('partial') || q.contains('sehemu')) return 'paid_partial';
    if (q.contains('spoke') || q.contains('walizungumza') || q.contains('answered')) return 'spoke';
    return null;
  }

  Future<AssistantReply?> _tryLogCallOutcome(String q) async {
    final looksLikeLog = q.contains('called') ||
        q.contains('nilipiga') ||
        q.contains('spoke to') ||
        q.contains('log call');
    if (!looksLikeLog) return null;

    final outcome = _parseContactOutcome(q);
    final customer = await _resolveCustomerName(q);
    if (customer == null) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Taja mteja, mf. "Nilipiga Mary, hakujibu".'
            : 'Name the customer, e.g. "Called Mary, no answer".',
      );
    }
    if (outcome == null) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Iliendaje na ${customer.name}?'
            : 'How did it go with ${customer.name}?',
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
      extra = localeController.isSwahili
          ? '\nAhadi imehifadhiwa kwa ${when.toIso8601String().substring(0, 10)}.'
          : '\nPromise saved for ${when.toIso8601String().substring(0, 10)}.';
    }

    final label = contactOutcomeLabels[outcome] ?? outcome;
    return AssistantReply(
      localeController.isSwahili
          ? 'Imerekodi $channel na ${customer.name}: $label.$extra'
          : 'Logged $channel with ${customer.name}: $label.$extra',
    );
  }

  DateTime _nextWeekday(int weekday) {
    var d = DateTime.now();
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != weekday);
    return d;
  }

  Future<AssistantReply?> _tryCallCustomer(String q) async {
    final isCall = RegExp(r'\b(call|phone|dial|piga)\b').hasMatch(q) &&
        !q.contains('called') &&
        !q.contains('nilipiga') &&
        !q.contains('log');
    if (!isCall) return null;

    final customer = await _resolveCustomerName(q);
    if (customer == null) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Nimpigie nani? mf. "Piga Mary".'
            : 'Who should I call? e.g. "Call Mary".',
      );
    }
    final c = await _customers.getCustomer(customer.id);
    final phone = c?.phone?.trim();
    if (phone == null || phone.isEmpty) {
      return AssistantReply(
        localeController.isSwahili
            ? '${customer.name} hana nambari ya simu chini ya Wateja.'
            : '${customer.name} has no phone number under Customers.',
      );
    }
    final balance = await _debtors.getBalance(customer.id);
    final shop = await _profiles.getBusinessName();
    return AssistantReply(
      localeController.isSwahili
          ? 'Fungua simu kwa ${customer.name} ($phone)?'
              '${balance > 0 ? '\nAnadeni ${Money.format(balance)}.' : ''}\n'
              'Thibitisha hapa chini — kisha nitauliza simu iliendaje.'
          : 'Open dialer for ${customer.name} ($phone)?'
              '${balance > 0 ? '\nThey owe ${Money.format(balance)}.' : ''}\n'
              'Confirm below — then I ask how the call went.',
      actions: [
        AssistantAction(
          kind: AssistantActionKind.call,
          label: localeController.isSwahili
              ? 'Piga ${customer.name}'
              : 'Call ${customer.name}',
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
      return AssistantReply(
        localeController.isSwahili
            ? 'Bado hakuna simu zilizorekodiwa. Baada ya kupiga, chagua matokeo.'
            : 'No calls logged yet. After Call, pick an outcome.',
      );
    }
    final buf = StringBuffer(
      todays.isNotEmpty
          ? (localeController.isSwahili ? 'Rekodi za leo:\n\n' : 'Contact log today:\n\n')
          : (localeController.isSwahili ? 'Mawasiliano ya hivi karibuni:\n\n' : 'Recent contacts:\n\n'),
    );
    for (final e in use) {
      final label = contactOutcomeLabels[e.result ?? ''] ?? (e.result ?? '—');
      final when =
          '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
      buf.writeln('• ${e.partyName ?? '—'} · ${e.channel} · $label · $when');
    }
    return AssistantReply(buf.toString().trim());
  }

  Future<AssistantReply?> _tryWriteIntent(String q) async {
    if (_matches(q, ['paid', 'record payment', 'received from', 'amelipa', 'rekodi malipo'])) {
      final amount = _extractAmount(q);
      if (amount == null || amount <= 0) {
        return AssistantReply(
          localeController.isSwahili
              ? 'Taja mteja na kiasi ili kurekodi malipo.'
              : 'Include customer and amount to record a payment.',
        );
      }
      var type = 'cash';
      if (q.contains('mpesa') || q.contains('m-pesa')) type = 'mpesa';
      final customer = await _resolveCustomerName(q);
      if (customer == null) {
        return AssistantReply(
          localeController.isSwahili
              ? 'Jina la mteja halikupatikana.'
              : 'Could not match a customer name.',
        );
      }
      final balance = await _debtors.getBalance(customer.id);
      if (balance <= 0) {
        return AssistantReply(
          localeController.isSwahili
              ? '${customer.name} hana deni lililo wazi.'
              : '${customer.name} has no outstanding balance.',
        );
      }
      return AssistantReply(
        localeController.isSwahili
            ? 'Thibitisha malipo:\n• ${customer.name}\n• ${Money.format(amount)} $type'
            : 'Confirm payment:\n• ${customer.name}\n• ${Money.format(amount)} $type',
        actions: [
          AssistantAction(
            kind: AssistantActionKind.confirmWrite,
            label: localeController.isSwahili ? 'Thibitisha malipo' : 'Confirm payment',
            writeKind: AssistantWriteKind.recordRepayment,
            writePayload: {
              'customerId': customer.id,
              'customerName': customer.name,
              'amount': amount,
              'paymentType': type,
            },
          ),
          AssistantAction(
            kind: AssistantActionKind.cancelWrite,
            label: localeController.s.cancel,
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
    for (final m in re.allMatches(q).toList().reversed) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v != null && v > 0) return Money.round(v);
    }
    return null;
  }

  bool _matches(String q, List<String> keys) {
    for (final k in keys) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  Future<String> _trendsBrief(String q) async {
    final wantHours = _matches(q, ['busy hours', 'peak hours', 'slow hours', 'hour', 'saa za']);
    final wantMonth = _matches(q, ['month', '30 days', 'last 30', 'monthly', 'mwezi']);

    if (wantHours) {
      return await _busyHoursBrief();
    }

    final week = await _reports.thisWeekSeries();
    final month = await _reports.last30DaysSeries();
    final today = await _reports.daySales();

    final buf = StringBuffer();
    if (!wantMonth) {
      buf.writeln(_formatSeriesInsight(week, comparePrevious: true));
      buf.writeln();
    }
    if (wantMonth) {
      buf.writeln(_formatSeriesInsight(month, comparePrevious: false));
      buf.writeln();
    }

    final outlook = _simpleOutlook(month);
    if (outlook != null) {
      buf.writeln(outlook);
      buf.writeln();
    }

    buf.writeln(
      localeController.isSwahili
          ? 'Leo hadi sasa: ${Money.format(today.salesTotal)} (${today.saleCount} mauzo).'
          : 'Today so far: ${Money.format(today.salesTotal)} (${today.saleCount} sales).',
    );
    buf.write(
      localeController.isSwahili
          ? '\nKidokezo: fungua Ripoti → Mwenendo kwa chati.'
          : '\nTip: open Reports → Trends for graphs.',
    );
    return buf.toString().trim();
  }

  Future<String> _busyHoursBrief() async {
    final hours = await _reports.salesByHour();
    final withSales = hours.where((h) => h.salesTotal > 0).toList();
    if (withSales.isEmpty) {
      return (localeController.isSwahili
              ? 'Bado hakuna mauzo kwa saa leo. '
              : 'No sales recorded by hour yet today. ') +
          localeController.s.asstAfterFewSales;
    }
    withSales.sort((a, b) => b.salesTotal.compareTo(a.salesTotal));
    final top = withSales.take(3).toList();
    final buf = StringBuffer(
      localeController.isSwahili ? 'Saa za shughuli leo:\n' : 'Busy hours today:\n',
    );
    for (final h in top) {
      buf.writeln('• ${h.label}: ${Money.format(h.salesTotal)} (${h.saleCount})');
    }
    buf.writeln(localeController.s.asstBasedOnToday);
    return buf.toString().trim();
  }

  String _formatSeriesInsight(PeriodSeries series, {required bool comparePrevious}) {
    final title = series.title;
    final buf = StringBuffer();
    buf.writeln(title);
    buf.writeln(
      localeController.isSwahili
          ? '• Mauzo ${Money.format(series.salesTotal)} (${series.saleCount})'
          : '• Sales ${Money.format(series.salesTotal)} (${series.saleCount})',
    );
    buf.writeln(
      localeController.isSwahili
          ? '• Faida ~${Money.format(series.grossProfit)}'
          : '• Gross ~${Money.format(series.grossProfit)}',
    );
    if (series.saleCount == 0) {
      buf.writeln(
        localeController.isSwahili
            ? '• Bado hakuna mauzo kipindi hiki.'
            : '• No sales in this period yet.',
      );
    }
    return buf.toString().trim();
  }

  String? _simpleOutlook(PeriodSeries series) {
    if (series.days.length < 6) return null;
    final days = series.days;
    final half = days.length ~/ 2;
    final early = days.take(half).fold<double>(0, (s, d) => s + d.salesTotal);
    final late = days.skip(half).fold<double>(0, (s, d) => s + d.salesTotal);
    if (early <= 0 && late <= 0) return null;
    if (late > early * 1.15) {
      return localeController.isSwahili
          ? 'Mtazamo: mauzo yameongezeka siku za hivi karibuni.'
          : 'Outlook: sales picked up in the last days.';
    }
    if (late < early * 0.85) {
      return localeController.isSwahili
          ? 'Mtazamo: siku za hivi karibuni ziko dhaifu kuliko awali.'
          : 'Outlook: recent days are softer than earlier.';
    }
    return localeController.isSwahili
        ? 'Mtazamo: mauzo yanalingana na awali katika kipindi hiki.'
        : 'Outlook: recent days are similar to earlier in the period.';
  }

  Future<String> _dailyBrief() async {
    final day = await _reports.daySales();
    final shop = await _profiles.getBusinessName();
    if (localeController.isSwahili) {
      return 'Muhtasari wa siku — $shop (${day.businessDate})\n\n'
          'Mauzo: ${Money.format(day.salesTotal)} (${day.saleCount})\n'
          'Taslimu: ${Money.format(day.cash)} · M-Pesa: ${Money.format(day.mpesa)}\n'
          'Faida ~${Money.format(day.grossProfit)}\n'
          'Matumizi: ${Money.format(day.expensesTotal)}';
    }
    return 'Daily brief — $shop (${day.businessDate})\n\n'
        'Sales: ${Money.format(day.salesTotal)} (${day.saleCount})\n'
        'Cash: ${Money.format(day.cash)} · M-Pesa: ${Money.format(day.mpesa)}\n'
        'Gross ~${Money.format(day.grossProfit)}\n'
        'Expenses: ${Money.format(day.expensesTotal)}';
  }

  Future<String> _todaySales() async {
    final day = await _reports.daySales();
    if (localeController.isSwahili) {
      return 'Mauzo leo (${day.businessDate})\n'
          'Jumla ${Money.format(day.salesTotal)} · ${day.saleCount} mauzo';
    }
    return 'Sales today (${day.businessDate})\n'
        'Total ${Money.format(day.salesTotal)} · ${day.saleCount} sales';
  }

  Future<AssistantReply> _whoOwesMe() async {
    final rows = await _debtors.listOutstanding();
    if (rows.isEmpty) {
      return AssistantReply(localeController.s.asstNoOneOwes);
    }
    final buf = StringBuffer(
      localeController.isSwahili ? 'Wanaodaiwa:\n\n' : 'Who owes you:\n\n',
    );
    for (final d in rows.take(12)) {
      buf.writeln('• ${d.customerName}: ${Money.format(d.balance)}');
    }
    return AssistantReply(buf.toString().trim());
  }

  Future<AssistantReply> _whoIsOverdue() async {
    final days = await _policy.getOverdueDebtDays();
    final rows = await _debtors.listOutstanding(overdueDays: days);
    final overdue = rows.where((d) => d.isOverdue).toList();
    if (overdue.isEmpty) {
      return AssistantReply(
        localeController.isSwahili
            ? 'Hakuna wadeni walioechelewa (siku $days).'
            : 'No overdue debtors (threshold $days days).',
      );
    }
    final buf = StringBuffer(
      localeController.isSwahili ? 'Waliochelewa:\n\n' : 'Overdue:\n\n',
    );
    for (final d in overdue.take(12)) {
      buf.writeln('• ${d.customerName}: ${Money.format(d.balance)}');
    }
    return AssistantReply(buf.toString().trim());
  }

  Future<AssistantReply> _promisesDue() async {
    return AssistantReply(
      localeController.isSwahili
          ? 'Hakuna ahadi zilizofikia leo au mapema (angalia deni kwa ahadi).'
          : 'No promises due today or earlier.',
    );
  }

  Future<String> _lowStock() async {
    final low = await _reports.lowStockItems();
    if (low.isEmpty) return localeController.s.asstNoLowStock;
    final buf = StringBuffer(
      localeController.isSwahili ? 'Bidhaa zimepungua:\n\n' : 'Low stock:\n\n',
    );
    for (final i in low.take(12)) {
      buf.writeln('• ${i.name}: ${i.quantity}');
    }
    return buf.toString().trim();
  }
}
