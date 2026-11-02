import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/day_closing_service.dart';
import '../../services/expense_service.dart';
import '../../services/inventory_service.dart';
import '../../services/locale_service.dart';
import '../../services/report_service.dart';
import '../pos/sales_history_page.dart';
import '../reports/day_close_page.dart';

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
  final _reports = ReportService();
  final _expenses = ExpenseService();
  final _closing = DayClosingService();
  final _inventory = InventoryService();
  final _profiles = BusinessProfileService.instance;

  DaySalesReport? _day;
  SpoilageDaySummary _spoilage = SpoilageDaySummary.empty;
  String _shopName = 'Mercate';
  bool _loading = true;
  String? _error;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return localeController.isSwahili ? 'Habari ya asubuhi' : 'Good morning';
    if (h < 17) return localeController.isSwahili ? 'Habari ya mchana' : 'Good afternoon';
    return localeController.isSwahili ? 'Habari ya jioni' : 'Good evening';
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
      final day = await _reports.daySales();
      final spoil = await _inventory.getSpoilageSummary(DateTime.now());
      final name = await _profiles.getBusinessName();
      if (!mounted) return;
      setState(() {
        _day = day;
        _spoilage = spoil;
        _shopName = name;
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

  Future<void> _recordExpense() async {
    final s = localeController.s;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var category = 'misc';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(s.recordExpense),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(labelText: s.amount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(labelText: s.noteOptional),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(labelText: s.category),
                  items: [
                    for (final c in ['transport', 'rent', 'utilities', 'stock', 'misc', 'other'])
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? 'misc'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.save)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _expenses.recordExpense(
        amount: Money.parse(amountCtrl.text),
        category: category,
        notes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      await _load();
      widget.onRefreshShell?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openCloseDay() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DayClosePage()),
    );
    _load();
    widget.onRefreshShell?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = localeController.s;
    final scheme = Theme.of(context).colorScheme;
    final day = _day;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.home),
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
              tooltip: s.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: widget.onOpenSettings,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      Text(
                        '$_greeting · $_shopName',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.today,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: s.sales,
                              value: day == null
                                  ? '—'
                                  : Money.format(day.salesTotal),
                              subtitle: day == null
                                  ? ''
                                  : '${day.saleCount}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              label: s.cash,
                              value: day == null ? '—' : Money.format(day.cash),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              label: s.mpesa,
                              value: day == null ? '—' : Money.format(day.mpesa),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GlassPanel(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.expenses,
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    day == null
                                        ? '—'
                                        : Money.format(day.expensesTotal),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _recordExpense,
                              child: Text(s.recordExpense),
                            ),
                          ],
                        ),
                      ),
                      if (_spoilage.eventCount > 0) ...[
                        const SizedBox(height: 12),
                        GlassPanel(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.eco_outlined, color: scheme.error),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.spoilageToday),
                                    Text(
                                      s.recordsCount(_spoilage.eventCount),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Money.format(_spoilage.estimatedCost),
                                style: TextStyle(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openCloseDay,
                        icon: const Icon(Icons.nightlight_round),
                        label: Text(s.endOfDay),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SalesHistoryPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: Text(s.salesHistory),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
