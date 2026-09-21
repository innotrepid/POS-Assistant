import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/day_closing_service.dart';
import '../../services/expense_service.dart';
import '../../services/report_service.dart';
import '../../services/security_service.dart';
import '../pos/sales_history_page.dart';
import '../security/lock_screen.dart';

class DashboardPage extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onRefreshShell;

  const DashboardPage({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
    this.onOpenAssistant,
    this.onRefreshShell,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _reports = ReportService();
  final _expenses = ExpenseService();
  final _dayClose = DayClosingService();
  final _security = SecurityService();

  DaySalesReport? _summary;
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
      final summary = await _reports.getDaySalesReport(now);
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
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 8),
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
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _closeDay() async {
    if (_summary?.isClosed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today is already closed')),
      );
      return;
    }

    final identityOk = await _security.requireUnlock(
      biometricReason: 'Confirm day close',
      promptPin: () => promptPinDialog(context, title: 'PIN to close day'),
    );
    if (!identityOk || !mounted) return;

    final cashCtrl = TextEditingController();
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s != null) ...[
                  Text('Sales ${Money.format(s.salesTotal)}'),
                  const SizedBox(height: 6),
                  Text('Cash expected ${Money.format(s.cash)}'),
                  const SizedBox(height: 6),
                  Text('M-Pesa ${Money.format(s.mpesa)}'),
                  const SizedBox(height: 6),
                  Text('Expenses ${Money.format(s.expensesTotal)}'),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: cashCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cash counted in till',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close day'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;
    try {
      await _dayClose.closeDay(
        cashCounted: Money.parse(cashCtrl.text),
        notes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day closed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
        title: Text(
          'Home',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
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
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, d MMM').format(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text(
          _greeting,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(20),
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TODAY'S SALES",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                Money.format(s.salesTotal),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                s.saleCount == 1
                    ? '1 sale recorded'
                    : '${s.saleCount} sales recorded',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'Cash',
                value: Money.format(s.cash),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricTile(
                label: 'M-Pesa',
                value: Money.format(s.mpesa),
                icon: Icons.phone_android_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'Expenses',
                value: Money.format(s.expensesTotal),
                icon: Icons.trending_down,
                warn: s.expensesTotal > 0,
                onAction: _addExpense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricTile(
                label: 'Net feel',
                value: Money.format(s.salesTotal - s.expensesTotal),
                icon: Icons.insights_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'End of day',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                s.isClosed
                    ? 'Today is locked. Come back tomorrow.'
                    : 'Count the till when you are done selling.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: s.isClosed ? null : _closeDay,
                child: Text(s.isClosed ? 'Day closed' : 'Close day'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SalesHistoryPage(),
                    ),
                  );
                },
                child: const Text('Sales history'),
              ),
            ],
          ),
        ),
        if (_todayExpenses.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Today\'s expenses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final e in _todayExpenses)
            GlassPanel(
              margin: const EdgeInsets.only(bottom: 8),
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e['category'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    Money.format((e['amount'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
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
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: warn ? scheme.error : scheme.primary,
              ),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
