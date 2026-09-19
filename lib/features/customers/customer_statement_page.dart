import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/debtor_service.dart';

class CustomerStatementPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerStatementPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerStatementPage> createState() => _CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  final _debtors = DebtorService();
  double _balance = 0;
  List<Map<String, dynamic>> _txns = [];
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
      final balance = await _debtors.getBalance(widget.customerId);
      final txns = await _debtors.getStatement(widget.customerId);
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _txns = txns;
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

  Future<void> _recordPayment() async {
    if (_balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing outstanding')),
      );
      return;
    }

    final amountCtrl = TextEditingController(
      text: _balance.toStringAsFixed(2),
    );
    final refCtrl = TextEditingController();
    var paymentType = 'cash';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Record repayment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Outstanding ${Money.format(_balance)}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final t in ['cash', 'mpesa', 'card'])
                          ChoiceChip(
                            label: Text(t.toUpperCase()),
                            selected: paymentType == t,
                            onSelected: (_) => setLocal(() => paymentType = t),
                          ),
                      ],
                    ),
                    if (paymentType == 'mpesa') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'M-Pesa reference',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
      await _debtors.recordRepayment(
        customerId: widget.customerId,
        amount: Money.parse(amountCtrl.text),
        paymentType: paymentType,
        reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repayment recorded')),
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
        title: Text(widget.customerName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: _balance > 0
          ? FloatingActionButton.extended(
              onPressed: _recordPayment,
              icon: const Icon(Icons.payments),
              label: const Text('Repay'),
            )
          : null,
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
            title: const Text('Balance'),
            trailing: Text(
              Money.format(_balance),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        Expanded(
          child: _txns.isEmpty
              ? const Center(child: Text('No transactions yet'))
              : ListView.separated(
                  itemCount: _txns.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = _txns[index];
                    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                    final type = t['transaction_type'] as String? ?? '';
                    final created = t['created_at'] as String? ?? '';
                    final isCredit = amount >= 0;

                    return ListTile(
                      title: Text(_label(type)),
                      subtitle: Text(created),
                      trailing: Text(
                        '${isCredit ? '+' : ''}${Money.format(amount)}',
                        style: TextStyle(
                          color: isCredit
                              ? Theme.of(context).colorScheme.error
                              : Colors.greenAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _label(String type) {
    switch (type) {
      case 'credit_sale':
        return 'Credit sale';
      case 'repayment':
        return 'Repayment';
      default:
        return type;
    }
  }
}
