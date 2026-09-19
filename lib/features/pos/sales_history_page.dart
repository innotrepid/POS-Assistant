import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/sales_service.dart';
import 'receipt_page.dart';

class SalesHistoryPage extends StatefulWidget {
  final String? highlightSaleId;

  const SalesHistoryPage({super.key, this.highlightSaleId});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final _sales = SalesService();
  List<Map<String, dynamic>> _rows = [];
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
      final rows = await _sales.listSales(limit: 100);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });

      final highlight = widget.highlightSaleId;
      if (highlight != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReceiptPage(saleId: highlight),
            ),
          );
        });
      }
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
        title: const Text('Sales history'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
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
    if (_rows.isEmpty) {
      return const Center(child: Text('No sales yet'));
    }

    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = _rows[index];
        final id = row['id'] as String? ?? '';
        final total = (row['total'] as num?)?.toDouble() ?? 0;
        final status = row['payment_status'] as String? ?? '';
        final created = row['created_at'] as String? ?? '';

        return ListTile(
          title: Text(Money.format(total)),
          subtitle: Text('$status · $created'),
          trailing: const Icon(Icons.chevron_right),
          selected: id == widget.highlightSaleId,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReceiptPage(saleId: id),
              ),
            );
          },
        );
      },
    );
  }
}
