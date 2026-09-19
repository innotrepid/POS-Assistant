import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/utils/money.dart';
import '../../services/pdf_report_builder.dart';
import '../../services/report_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _reports = ReportService();
  final _pdf = PdfReportBuilder();

  DaySalesReport? _day;
  List<StockRow> _stock = [];
  List<PartyBalanceRow> _debtors = [];
  List<PartyBalanceRow> _creditors = [];
  bool _loading = true;
  bool _exporting = false;
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
      final day = await _reports.daySales();
      final stock = await _reports.stockOnHand();
      final debtors = await _reports.debtorsOutstanding();
      final creditors = await _reports.creditorsOutstanding();
      if (!mounted) return;
      setState(() {
        _day = day;
        _stock = stock;
        _debtors = debtors;
        _creditors = creditors;
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

  Future<void> _sharePdf() async {
    final day = _day;
    if (day == null) return;

    setState(() => _exporting = true);
    try {
      final bytes = await _pdf.buildBusinessReport(
        day: day,
        stock: _stock,
        debtors: _debtors,
        creditors: _creditors,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'pos-report-${day.businessDate}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _previewPdf() async {
    final day = _day;
    if (day == null) return;

    setState(() => _exporting = true);
    try {
      final bytes = await _pdf.buildBusinessReport(
        day: day,
        stock: _stock,
        debtors: _debtors,
        creditors: _creditors,
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('PDF preview')),
            body: PdfPreview(
              build: (format) async => bytes,
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Preview PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _loading || _exporting ? null : _previewPdf,
          ),
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.share),
            onPressed: _loading || _exporting ? null : _sharePdf,
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

    final day = _day!;
    final stockValue =
        _stock.fold<double>(0, (s, r) => s + r.stockValue);
    final debtorsTotal =
        _debtors.fold<double>(0, (s, r) => s + r.balance);
    final creditorsTotal =
        _creditors.fold<double>(0, (s, r) => s + r.balance);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_exporting)
          const LinearProgressIndicator(),
        Text(
          'Today · ${day.businessDate}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _row('Sales', Money.format(day.salesTotal),
            subtitle: '${day.saleCount} transactions'),
        _row('Cash', Money.format(day.cash)),
        _row('M-Pesa', Money.format(day.mpesa)),
        if (day.card > 0) _row('Card', Money.format(day.card)),
        _row('New credit', Money.format(day.creditTotal)),
        _row('Est. COGS', Money.format(day.estimatedCost)),
        _row('Gross profit (est.)', Money.format(day.grossProfit)),
        _row('Expenses', Money.format(day.expensesTotal)),
        const Divider(height: 28),
        Text('Stock', style: Theme.of(context).textTheme.titleMedium),
        _row('Value at cost', Money.format(stockValue),
            subtitle: '${_stock.length} products'),
        const Divider(height: 28),
        Text('Debtors', style: Theme.of(context).textTheme.titleMedium),
        _row('Owed to you', Money.format(debtorsTotal)),
        ..._debtors.take(8).map(
              (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(d.name),
                trailing: Text(Money.format(d.balance)),
              ),
            ),
        if (_debtors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('None'),
          ),
        const Divider(height: 28),
        Text('Creditors', style: Theme.of(context).textTheme.titleMedium),
        _row('You owe', Money.format(creditorsTotal)),
        ..._creditors.take(8).map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(c.name),
                trailing: Text(Money.format(c.balance)),
              ),
            ),
        if (_creditors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('None'),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _exporting ? null : _sharePdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Share PDF report'),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {String? subtitle}) {
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
