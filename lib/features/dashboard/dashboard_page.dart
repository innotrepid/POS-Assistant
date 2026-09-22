import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/day_closing_service.dart';
import '../../services/expense_service.dart';
import '../../services/security_service.dart';
import '../pos/sales_history_page.dart';
import '../security/lock_screen.dart';

class DashboardPage extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRefreshShell;

  const DashboardPage({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
    this.onOpenAssistant,
    this.onOpenSettings,
    this.onRefreshShell,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _expenses = ExpenseService();
  final _dayClose = DayClosingService();
  final _security = SecurityService();

  DaySummary? _summary;
  List<Map<String, dynamic>> _todayExpenses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final summary = await _dayClose.getSummary(now);
      final expenses = await _expenses.listExpenses(day: now);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _todayExpenses = expenses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addExpense() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var category = kExpenseCategories.first;
    var method = 'cash';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Record expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      items: kExpenseCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => category = v);
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final m in ['cash', 'mpesa', 'card'])
                          ChoiceChip(
                            label: Text(m.toUpperCase()),
                            selected: method == m,
                            onSelected: (_) => setLocal(() => method = m),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;
    try {
      await _expenses.recordExpense(
        category: category,
        amount: Money.parse(amountCtrl.text),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        paymentMethod: method,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _voidExpense(Map<String, dynamic> expense) async {
    final id = expense['id'] as String?;
    if (id == null) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${expense['category']} · ${Money.format((expense['amount'] as num?)?.toDouble() ?? 0)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Void')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _expenses.voidExpense(expenseId: id, reason: reasonCtrl.text);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense voided')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _closeDay() async {
    if (_summary?.isClosed == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Today is already closed')));
      return;
    }

    final identityOk = await _security.requireUnlock(
      biometricReason: 'Confirm day close',
      promptPin: () => promptPinDialog(context, title: 'PIN to close day'),
    );
    if (!identityOk || !mounted) return;

    final openingCtrl = TextEditingController(text: '0');
    final cashCtrl = TextEditingController();
    final mpesaCtrl = TextEditingController(text: _summary != null ? '${_summary!.salesMpesa}' : '0');
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final s = _summary;
        return AlertDialog(
          title: const Text('Close day'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s != null) ...[
                  Text('Sales ${Money.format(s.salesTotal)} · ${s.saleCount} sales'),
                  const SizedBox(height: 6),
                  Text('Cash in ${Money.format(s.salesCash)} · M-Pesa in ${Money.format(s.salesMpesa)}'),
                  const SizedBox(height: 6),
                  Text('Cash expenses out ${Money.format(s.expensesCash)}'),
                  const SizedBox(height: 6),
                  Text('All expenses ${Money.format(s.expensesTotal)}'),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: openingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opening cash in till',
                    border: OutlineInputBorder(),
                    helperText: 'What was in the drawer this morning',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cashCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cash counted now',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mpesaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa confirmed on phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                if (s != null)
                  Text(
                    'Expected cash ≈ ${Money.format(s.expectedCashFromOps(0))} with opening 0\n'
                    '(opening + cash sales − cash expenses)\n'
                    'Expected M-Pesa ≈ ${Money.format(s.expectedMpesa)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close day')),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;
    try {
      await _dayClose.closeDay(
        day: DateTime.now(),
        openingCash: Money.parse(openingCtrl.text),
        countedCash: Money.parse(cashCtrl.text),
        countedMpesa: Money.parse(mpesaCtrl.text),
        notes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      final opening = Money.parse(openingCtrl.text);
      final countedC = Money.parse(cashCtrl.text);
      final countedM = Money.parse(mpesaCtrl.text);
      final s0 = _summary;
      final cashVar = s0 == null ? 0.0 : s0.cashVariance(opening, countedC);
      final mpesaVar = s0 == null ? 0.0 : s0.mpesaVariance(countedM);
      await _load();
      if (!mounted) return;
      final cashMsg = cashVar == 0
          ? 'Cash matched'
          : cashVar > 0
              ? 'Cash over by ${Money.format(cashVar)}'
              : 'Cash short by ${Money.format(-cashVar)}';
      final mpesaMsg = mpesaVar == 0
          ? 'M-Pesa matched'
          : mpesaVar > 0
              ? 'M-Pesa over by ${Money.format(mpesaVar)}'
              : 'M-Pesa short by ${Money.format(-mpesaVar)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Day closed · $cashMsg · $mpesaMsg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Home', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          if (widget.onOpenNotifications != null)
            IconButton(
              tooltip: 'Notifications',
              onPressed: widget.onOpenNotifications,
              icon: Badge(
                isLabelVisible: widget.unreadCount > 0,
                label: Text('${widget.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          if (widget.onOpenSettings != null)
            IconButton(
              tooltip: 'Settings · profile',
              icon: const Icon(Icons.settings_outlined),
              onPressed: widget.onOpenSettings,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final s = _summary!;
    final dateLabel = DateFormat('EEEE, d MMM').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text(_greeting, style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        Text(dateLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(20),
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TODAY'S SALES", style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(Money.format(s.salesTotal), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(s.saleCount == 1 ? '1 sale recorded' : '${s.saleCount} sales recorded', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _metricTile(label: 'Cash', value: Money.format(s.salesCash), icon: Icons.payments_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _metricTile(label: 'M-Pesa', value: Money.format(s.salesMpesa), icon: Icons.phone_android_outlined)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metricTile(label: 'Expenses', value: Money.format(s.expensesTotal), icon: Icons.trending_down, warn: s.expensesTotal > 0, onAction: _addExpense)),
          const SizedBox(width: 12),
          Expanded(child: _metricTile(label: 'Net feel', value: Money.format(s.salesTotal - s.expensesTotal), icon: Icons.insights_outlined)),
        ]),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: _addExpense,
          icon: const Icon(Icons.add),
          label: const Text('Record expense'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('End of day', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(s.isClosed ? 'Today is locked. Come back tomorrow.' : 'Count the till when you are done selling.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton(onPressed: s.isClosed ? null : _closeDay, child: Text(s.isClosed ? 'Day closed' : 'Close day')),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SalesHistoryPage()));
                },
                child: const Text('Sales history'),
              ),
            ],
          ),
        ),
        if (_todayExpenses.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text("Today's expenses", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final e in _todayExpenses)
            GlassPanel(
              margin: const EdgeInsets.only(bottom: 8),
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['category'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if ((e['description'] as String?)?.isNotEmpty == true)
                        Text(e['description'] as String, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(Money.format((e['amount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Void expense',
                  icon: const Icon(Icons.undo, size: 20),
                  onPressed: () => _voidExpense(e),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    bool warn = false,
    VoidCallback? onAction,
    IconData actionIcon = Icons.add,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: warn ? scheme.error : scheme.primary),
            const Spacer(),
            if (onAction != null)
              IconButton(
                tooltip: 'Record expense',
                onPressed: onAction,
                icon: Icon(actionIcon, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ]),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
