import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/customer.dart';
import '../../core/utils/money.dart';
import '../../services/customer_service.dart';
import '../../services/debtor_service.dart';
import '../../services/policy_service.dart';
import 'customer_statement_page.dart';
import 'debtors_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _service = CustomerService();
  final _debtors = DebtorService();
  final _policies = PolicyService();

  List<Customer> _customers = [];
  final Map<String, double> _balances = {};
  int _debtorCount = 0;
  int _overdueCount = 0;
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
      final list = await _service.getAllCustomers(activeOnly: false);
      final balances = <String, double>{};
      for (final c in list) {
        balances[c.id] = await _debtors.getBalance(c.id);
      }
      final overdueDays = await _policies.getOverdueDebtDays();
      final outstanding = await _debtors.listOutstanding(overdueDays: overdueDays);
      if (!mounted) return;
      setState(() {
        _customers = list;
        _balances
          ..clear()
          ..addAll(balances);
        _debtorCount = outstanding.length;
        _overdueCount = outstanding.where((d) => d.isOverdue).length;
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

  Future<void> _openDebtors() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebtorsPage()),
    );
    if (mounted) _load();
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                helperText: 'Max 10 digits (e.g. 07XXXXXXXX)',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.createCustomer(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: _debtorCount == 0
                ? 'Who owes you'
                : 'Who owes you ($_debtorCount)'
                    '${_overdueCount > 0 ? ' · $_overdueCount overdue' : ''}',
            onPressed: _openDebtors,
            icon: Badge(
              isLabelVisible: _debtorCount > 0,
              label: Text('$_debtorCount'),
              backgroundColor: _overdueCount > 0 ? scheme.error : null,
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: _overdueCount > 0 ? scheme.error : null,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: _addCustomer,
          icon: const Icon(Icons.person_add),
          label: const Text('Add customer'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (_debtorCount > 0)
                      Material(
                        color: scheme.errorContainer.withOpacity(0.35),
                        child: ListTile(
                          leading: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: scheme.error,
                          ),
                          title: Text(
                            '$_debtorCount customer${_debtorCount == 1 ? '' : 's'} owe you'
                            '${_overdueCount > 0 ? ' · $_overdueCount overdue' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Call, SMS, promises — open wallet'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openDebtors,
                        ),
                      ),
                    Expanded(
                      child: _customers.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No customers yet. Tap Add customer for people who buy on credit.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                              itemCount: _customers.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final c = _customers[index];
                                final bal = _balances[c.id] ?? 0;
                                return ListTile(
                                  title: Text(
                                    c.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                                      if (bal > 0) 'Owes ${Money.format(bal)}',
                                    ].join(' · '),
                                  ),
                                  trailing: bal > 0
                                      ? Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 20,
                                          color: scheme.error,
                                        )
                                      : null,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerStatementPage(
                                          customerId: c.id,
                                          customerName: c.name,
                                        ),
                                      ),
                                    );
                                    if (mounted) _load();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
