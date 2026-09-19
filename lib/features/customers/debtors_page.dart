import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/debtor_service.dart';
import 'customer_statement_page.dart';

/// List of customers who currently owe money.
class DebtorsPage extends StatefulWidget {
  const DebtorsPage({super.key});

  @override
  State<DebtorsPage> createState() => _DebtorsPageState();
}

class _DebtorsPageState extends State<DebtorsPage> {
  final _debtors = DebtorService();
  List<DebtorSummary> _rows = [];
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
      final rows = await _debtors.listOutstanding();
      final total = await _debtors.totalOutstanding();
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
        title: const Text('Debtors'),
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
            title: const Text('Total outstanding'),
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
              ? const Center(child: Text('No outstanding debts'))
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = _rows[index];
                    return ListTile(
                      title: Text(d.customerName),
                      subtitle: d.phone == null ? null : Text(d.phone!),
                      trailing: Text(
                        Money.format(d.balance),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CustomerStatementPage(
                              customerId: d.customerId,
                              customerName: d.customerName,
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
