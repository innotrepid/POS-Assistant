import 'package:flutter/material.dart';

import '../../core/models/customer.dart';
import '../../core/utils/money.dart';
import '../../services/customer_service.dart';
import '../../services/debtor_service.dart';
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
  List<Customer> _customers = [];
  Map<String, double> _balances = {};
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
      if (!mounted) return;
      setState(() {
        _customers = list;
        _balances = balances;
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

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
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

    if (ok != true) return;

    try {
      await _service.createCustomer(
        name: nameCtrl.text,
        phone: phoneCtrl.text,
      );
      await _load();
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
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Debtors',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DebtorsPage()),
              );
              _load();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
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
    if (_customers.isEmpty) {
      return const Center(child: Text('No customers yet. Tap + to add.'));
    }

    return ListView.separated(
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _customers[index];
        final bal = _balances[c.id] ?? 0;
        return ListTile(
          title: Text(c.name),
          subtitle: Text(
            [
              if (c.phone != null && c.phone!.isNotEmpty) c.phone,
              if (bal > 0) 'Owes ${Money.format(bal)}',
              if (!c.active) 'inactive',
            ].whereType<String>().join(' · '),
          ),
          trailing: bal > 0
              ? Text(
                  Money.format(bal),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerStatementPage(
                  customerId: c.id,
                  customerName: c.name,
                ),
              ),
            );
            _load();
          },
        );
      },
    );
  }
}
