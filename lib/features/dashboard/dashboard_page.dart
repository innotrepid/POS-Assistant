import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/day_closing_service.dart';
import '../../services/expense_service.dart';
import '../../services/security_service.dart';
import '../security/lock_screen.dart';
import '../settings/business_profile_page.dart';
import '../settings/security_settings_page.dart';

class DashboardPage extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssistant;

  const DashboardPage({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
    this.onOpenAssistant,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _closing = DayClosingService();
  final _expenses = ExpenseService();
  final _profileService = BusinessProfileService();
  final _security = SecurityService();

  DaySummary? _summary;
  List<Map<String, dynamic>> _todayExpenses = [];
  String _shopName = 'My shop';
  String _profileLabel = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final summary = await _closing.getSummary(now);
      final expenses = await _expenses.listExpenses(day: now);
      final name = await _profileService.getBusinessName();
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _todayExpenses = expenses;
        _shopName = name;
        _profileLabel = profile.label;
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

  Future<bool> _confirmIdentity(String reason) async {
    return _security.requireUnlock(
      biometricReason: reason,
      promptPin: () => promptPinDialog(context, title: reason),
    );
  }

  Future<void> _openProfile() async {
    final ok = await _confirmIdentity('Confirm to change shop profile');
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BusinessProfilePage(),
      ),
    );
    _load();
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
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => category = v);
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
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

    if (ok != true) return;

    try {
      await _expenses.recordExpense(
        category: category,
        amount: Money.parse(amountCtrl.text),
        description: descCtrl.text,
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
    final summary = _summary;
    if (summary == null) return;
    if (summary.isClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today is already closed')),
      );
      return;
    }

    final identityOk = await _confirmIdentity('Confirm to close the day');
    if (!identityOk || !mounted) return;

    final openingCtrl = TextEditingController(text: '0');
    final cashCtrl = TextEditingController();
    final mpesaCtrl = TextEditingController(
      text: summary.salesMpesa.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Close ${summary.businessDate}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales ${Money.format(summary.salesTotal)}'),
                Text('Cash in ${Money.format(summary.salesCash)}'),
                Text('M-Pesa in ${Money.format(summary.salesMpesa)}'),
                Text('Expenses ${Money.format(summary.expensesTotal)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: openingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opening cash in till',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: cashCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Counted cash',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: mpesaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Counted M-Pesa',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
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

    if (ok != true) return;

    try {
      final opening = Money.parse(openingCtrl.text);
      await _closing.closeDay(
        day: DateTime.now(),
        openingCash: opening,
        countedCash: Money.parse(cashCtrl.text),
        countedMpesa: Money.parse(mpesaCtrl.text),
        notes: notesCtrl.text,
      );
      await _load();
      if (!mounted) return;

      final expected = summary.expectedCashFromOps(opening);
      final counted = Money.parse(cashCtrl.text);
      final diff = Money.round(counted - expected);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            diff == 0
                ? 'Day closed · cash matches'
                : 'Day closed · cash variance ${Money.format(diff)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SecuritySettingsPage(),
                ),
              );
              _load();
            },
          ),
          IconButton(
            tooltip: 'Shop profile',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: _openProfile,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expense_fab',
        onPressed: _addExpense,
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Expense'),
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
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight - 8;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 100),
      children: [
        // Greeting + shop
        Text(
          _greeting,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _shopName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (_profileLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _profileLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 20),

        // Hero sales glass
        GlassPanel(
          accent: true,
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'TODAY'S SALES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (s.isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CLOSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                Money.format(s.salesTotal),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.05,
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

        // Metric grid
        Row(
          children: [
            Expanded(
              child: _metricTile(
                label: 'Cash',
                value: Money.format(s.salesCash),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricTile(
                label: 'M-Pesa',
                value: Money.format(s.salesMpesa),
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricTile(
                label: s.salesCard > 0 ? 'Card' : 'Net feel',
                value: s.salesCard > 0
                    ? Money.format(s.salesCard)
                    : Money.format(s.salesTotal - s.expensesTotal),
                icon: s.salesCard > 0
                    ? Icons.credit_card_outlined
                    : Icons.insights_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Close day
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (s.closing != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Counted ${Money.format((s.closing!['counted_cash'] as num).toDouble())}  ·  '
                  'Expected ${Money.format((s.closing!['expected_cash'] as num).toDouble())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (!s.isClosed) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _closeDay,
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Close day'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Expenses section
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Expenses',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              'today',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_todayExpenses.isEmpty)
          GlassPanel(
            child: Text(
              'Nothing spent yet — tap Expense when you pay for something.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          ..._todayExpenses.map((e) {
            final amount = (e['amount'] as num?)?.toDouble() ?? 0;
            return GlassPanel(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['category'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if ((e['description'] as String?)?.isNotEmpty == true)
                          Text(
                            e['description'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    Money.format(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    bool warn = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: warn ? scheme.error : scheme.primary,
          ),
          const SizedBox(height: 14),
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
