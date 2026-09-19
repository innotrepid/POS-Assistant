import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/creditor_service.dart';
import 'supplier_statement_page.dart';

class CreditorsPage extends StatefulWidget {
  const CreditorsPage({super.key});

  @override
  State<CreditorsPage> createState() => _CreditorsPageState();
}

class _CreditorsPageState extends State<CreditorsPage> {
  final _creditors = CreditorService();
  List<CreditorSummary> _rows = [];
  double _total = 0;
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
      final rows = await _creditors.listOutstanding();
      final total = await _creditors.totalOutstanding();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _total = total;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creditors'),
        actions: [
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
      return Center(child: Text(_error!));
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            title: const Text('Total we owe'),
            trailing: Text(
              Money.format(_total),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? const Center(child: Text('No outstanding supplier balances'))
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _rows[index];
                    return ListTile(
                      title: Text(c.supplierName),
                      subtitle: c.phone == null ? null : Text(c.phone!),
                      trailing: Text(
                        Money.format(c.balance),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SupplierStatementPage(
                              supplierId: c.supplierId,
                              supplierName: c.supplierName,
                            ),
                          ),
                        );
                        _load();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
