import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/day_closing_service.dart';
import '../../services/expense_service.dart';
import '../../services/inventory_service.dart';
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
  final _inventory = InventoryService();
  final _profiles = BusinessProfileService.instance;

  DaySummary? _summary;
  List<Map<String, dynamic>> _todayExpenses = [];
  SpoilageDaySummary _spoilage = SpoilageDaySummary.empty;
  bool _loading = true;
  String? _error;
  String _shopName = 'My shop';

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

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
      final spoilage = await _inventory.getSpoilageSummary(now);
      final shop = await _profiles.getBusinessName();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _todayExpenses = expenses;
        _spoilage = spoilage;
        _shopName = shop.isEmpty ? 'My shop' : shop;
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

  Future<void> _closeDay() async {
    final openingCtrl = TextEditingController(text: '0');
    final cashCtrl = TextEditingController(text: '0');
    final mpesaCtrl = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close day'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Count the till before locking today.'),
              const SizedBox(height: 12),
              TextField(
                controller: openingCtrl,
                decoration: const InputDecoration(labelText: 'Opening cash'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cashCtrl,
                decoration: const InputDecoration(labelText: 'Counted cash'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mpesaCtrl,
                decoration: const InputDecoration(labelText: 'Counted M-Pesa'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close day')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _dayClose.closeDay(
        day: DateTime.now(),
        openingCash: Money.parse(openingCtrl.text),
        countedCash: Money.parse(cashCtrl.text),
        countedMpesa: Money.parse(mpesaCtrl.text),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Day closed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: kExpenseCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setLocal(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Paid with'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setLocal(() => method = v ?? method),
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
    if (ok != true) return;
    try {
      await _expenses.recordExpense(
        category: category,
        amount: Money.parse(amountCtrl.text),
        paymentMethod: method,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (widget.onOpenNotifications != null)
            IconButton(
              onPressed: widget.onOpenNotifications,
              icon: Badge(
                isLabelVisible: widget.unreadCount > 0,
                label: Text('${widget.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          if (widget.onOpenSettings != null)
            IconButton(
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : s == null
                  ? const Center(child: Text('No data'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '$_greeting · $_shopName',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, d MMM').format(DateTime.now()),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _metricTile(
                                label: 'Sales',
                                value: Money.format(s.salesTotal),
                                icon: Icons.point_of_sale_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _metricTile(
                                label: 'Expenses',
                                value: Money.format(s.expensesTotal),
                                icon: Icons.trending_down,
                                warn: s.expensesTotal > 0,
                                onAction: _addExpense,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _metricTile(
                                label: 'Cash',
                                value: Money.format(s.salesCash),
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _metricTile(
                                label: 'M-Pesa',
                                value: Money.format(s.salesMpesa),
                                icon: Icons.phone_android_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonalIcon(
                          onPressed: _addExpense,
                          icon: const Icon(Icons.add),
                          label: const Text('Record expense'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        ),
                        if (_spoilage.eventCount > 0) ...[
                          const SizedBox(height: 12),
                          GlassPanel(
                            borderRadius: 16,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(Icons.eco_outlined, color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spoilage today',
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        '${_spoilage.eventCount} record'
                                        '${_spoilage.eventCount == 1 ? '' : 's'} · '
                                        '${Money.format(_spoilage.estimatedCost)} est. loss',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        GlassPanel(
                          borderRadius: 22,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End of day',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
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
                            ],
                          ),
                        ),
                        if (_todayExpenses.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            "Today's expenses",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          for (final e in _todayExpenses)
                            ListTile(
                              title: Text('${e['category']}'),
                              subtitle: Text('${e['description'] ?? ''}'),
                              trailing: Text(Money.format((e['amount'] as num?)?.toDouble() ?? 0)),
                            ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
                            );
                          },
                          child: const Text('Sales history'),
                        ),
                      ],
                    ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    bool warn = false,
    VoidCallback? onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: warn ? scheme.error : null),
              const Spacer(),
              if (onAction != null)
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Record expense',
                  onPressed: onAction,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: warn ? scheme.error : null,
                ),
          ),
        ],
      ),
    );
  }
}
