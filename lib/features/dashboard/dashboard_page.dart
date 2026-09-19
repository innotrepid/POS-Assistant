import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/day_closing_service.dart';
import '../../services/expense_service.dart';
import '../../services/security_service.dart';
import '../security/lock_screen.dart';
import '../settings/business_profile_page.dart';
import '../settings/security_settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

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
      appBar: AppBar(
        title: Text(_shopName),
        actions: [
          IconButton(
            tooltip: 'Settings & security',
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
      return Center(child: Text(_error!));
    }

    final s = _summary!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_profileLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _profileLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Text(
          'Today · ${s.businessDate}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _tile('Sales', Money.format(s.salesTotal),
            subtitle: '${s.saleCount} sales'),
        _tile('Cash sales', Money.format(s.salesCash)),
        _tile('M-Pesa sales', Money.format(s.salesMpesa)),
        if (s.salesCard > 0) _tile('Card sales', Money.format(s.salesCard)),
        _tile('Expenses', Money.format(s.expensesTotal)),
        const SizedBox(height: 8),
        if (s.isClosed)
          const Chip(
            avatar: Icon(Icons.lock, size: 18),
            label: Text('Day closed'),
          )
        else
          FilledButton.icon(
            onPressed: _closeDay,
            icon: const Icon(Icons.lock_clock),
            label: const Text('Close day'),
          ),
        if (s.closing != null) ...[
          const SizedBox(height: 8),
          Text(
            'Counted cash ${Money.format((s.closing!['counted_cash'] as num).toDouble())} · '
            'Expected ${Money.format((s.closing!['expected_cash'] as num).toDouble())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const Divider(height: 32),
        Text(
          "Today's expenses",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_todayExpenses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No expenses yet'),
          )
        else
          ..._todayExpenses.map((e) {
            final amount = (e['amount'] as num?)?.toDouble() ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e['category'] as String? ?? ''),
              subtitle: Text(e['description'] as String? ?? ''),
              trailing: Text(Money.format(amount)),
            );
          }),
      ],
    );
  }

  Widget _tile(String label, String value, {String? subtitle}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
