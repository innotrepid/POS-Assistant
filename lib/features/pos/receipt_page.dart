import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/sales_service.dart';

class ReceiptPage extends StatefulWidget {
  final String saleId;

  const ReceiptPage({super.key, required this.saleId});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _sales = SalesService();
  Map<String, dynamic>? _sale;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale = await _sales.getSale(widget.saleId);
      final items = await _sales.getSaleItems(widget.saleId);
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _items = items;
        _loading = false;
        if (sale == null) _error = 'Sale not found';
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
      appBar: AppBar(title: const Text('Receipt')),
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

    final sale = _sale!;
    final total = (sale['total'] as num?)?.toDouble() ?? 0;
    final paid = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = (sale['balance'] as num?)?.toDouble() ?? 0;
    final discount = (sale['discount'] as num?)?.toDouble() ?? 0;
    final subtotal = (sale['subtotal'] as num?)?.toDouble() ?? 0;
    final status = sale['payment_status'] as String? ?? '';
    final created = sale['created_at'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'POS Assistant',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          created,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 32),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['product_name']} × ${item['quantity']}',
                  ),
                ),
                Text(
                  Money.format((item['total'] as num?)?.toDouble() ?? 0),
                ),
              ],
            ),
          ),
        const Divider(height: 32),
        _row('Subtotal', Money.format(subtotal)),
        if (discount > 0) _row('Discount', '- ${Money.format(discount)}'),
        _row('Total', Money.format(total), bold: true),
        _row('Paid', Money.format(paid)),
        if (balance > 0) _row('Balance', Money.format(balance)),
        const SizedBox(height: 8),
        Text('Status: $status', textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Sale ID: ${widget.saleId}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
