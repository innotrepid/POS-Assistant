import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/customer.dart';
import '../../core/utils/money.dart';
import '../../services/customer_service.dart';
import '../../services/debtor_service.dart';
import '../../services/locale_service.dart';
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
      final outstanding =
          await _debtors.listOutstanding(overdueDays: overdueDays);
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
    final s = localeController.s;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.addCustomer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: s.name),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: s.phone,
                helperText: s.phoneHint,
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.save),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = localeController.s;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.customers),
        actions: [
          IconButton(
            tooltip: s.walletTooltip,
            onPressed: _openDebtors,
            icon: Badge(
              isLabelVisible: _debtorCount > 0,
              label: Text('$_debtorCount'),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: _addCustomer,
          icon: const Icon(Icons.person_add_outlined),
          label: Text(s.addCustomer),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _customers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.isSw
                              ? 'Bado hakuna wateja. Gusa Ongeza mteja kwa wanaonunua kwa mkopo.'
                              : 'No customers yet. Tap Add customer for people who buy on credit.',
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
                              if (c.phone != null && c.phone!.isNotEmpty)
                                c.phone!,
                              if (bal > 0)
                                (s.isSw
                                    ? 'Anadeni ${Money.format(bal)}'
                                    : 'Owes ${Money.format(bal)}'),
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
    );
  }
}
