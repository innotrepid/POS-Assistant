import 'package:flutter/material.dart';

import '../../core/models/supplier.dart';
import '../../core/utils/money.dart';
import '../../services/creditor_service.dart';
import '../../services/supplier_service.dart';
import 'creditors_page.dart';
import 'receive_purchase_page.dart';
import 'supplier_statement_page.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _suppliers = SupplierService();
  final _creditors = CreditorService();
  List<Supplier> _list = [];
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
      final list = await _suppliers.getAllSuppliers(activeOnly: false);
      final balances = <String, double>{};
      for (final s in list) {
        balances[s.id] = await _creditors.getBalance(s.id);
      }
      if (!mounted) return;
      setState(() {
        _list = list;
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

  Future<void> _addSupplier() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add supplier'),
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
      await _suppliers.createSupplier(
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
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            tooltip: 'Creditors',
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CreditorsPage()),
              );
              _load();
            },
          ),
          IconButton(
            tooltip: 'Receive goods',
            icon: const Icon(Icons.move_to_inbox),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReceivePurchasePage(),
                ),
              );
              _load();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSupplier,
        child: const Icon(Icons.add),
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
    if (_list.isEmpty) {
      return const Center(
        child: Text('No suppliers yet.\nTap + to add, then Receive goods.'),
      );
    }

    return ListView.separated(
      itemCount: _list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = _list[index];
        final bal = _balances[s.id] ?? 0;
        return ListTile(
          title: Text(s.name),
          subtitle: Text(
            [
              if (s.phone != null && s.phone!.isNotEmpty) s.phone,
              if (bal > 0) 'We owe ${Money.format(bal)}',
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
                builder: (_) => SupplierStatementPage(
                  supplierId: s.id,
                  supplierName: s.name,
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
