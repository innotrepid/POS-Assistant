import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
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
  final _profiles = BusinessProfileService.instance;

  DaySalesReport? _day;
  List<StockRow> _stock = [];
  List<PartyBalanceRow> _debtors = [];
  List<PartyBalanceRow> _creditors = [];
  String _shopName = 'My shop';
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
      final shop = await _profiles.getBusinessName();
      if (!mounted) return;
      setState(() {
        _day = day;
        _stock = stock;
        _debtors = debtors;
        _creditors = creditors;
        _shopName = shop.isEmpty ? 'My shop' : shop;
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
    if (_day == null) return;
    setState(() => _exporting = true);
    try {
      final day = _day!;
      final sold = await _reports.itemsSoldOnDay();
      final bytes = await _pdf.buildBusinessReport(
        shopName: _shopName,
        day: day,
        stock: sold,
        debtors: _debtors,
        creditors: _creditors,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'mercate-report-${day.businessDate}.pdf',
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
    if (_day == null) return;
    setState(() => _exporting = true);
    try {
      final day = _day!;
      final sold = await _reports.itemsSoldOnDay();
      final bytes = await _pdf.buildBusinessReport(
        shopName: _shopName,
        day: day,
        stock: sold,
        debtors: _debtors,
        creditors: _creditors,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('PDF preview')),
            body: PdfPreview(build: (_) async => bytes),
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
    final day = _day;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Preview PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : _previewPdf,
          ),
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.share_outlined),
            onPressed: _exporting ? null : _sharePdf,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : day == null
                  ? const Center(child: Text('No data'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Today · ${day.businessDate}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _tile('Sales', Money.format(day.salesTotal)),
                        _tile('Paid', Money.format(day.paidTotal)),
                        _tile('Credit (deni)', Money.format(day.creditTotal)),
                        _tile('Cash', Money.format(day.cash)),
                        _tile('M-Pesa', Money.format(day.mpesa)),
                        _tile('Expenses', Money.format(day.expensesTotal)),
                        _tile('Gross profit (est.)', Money.format(day.grossProfit)),
                        const SizedBox(height: 16),
                        Text(
                          'Stock on hand',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text('${_stock.length} products'),
                        const SizedBox(height: 12),
                        Text(
                          'Debtors',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text('${_debtors.length} with balance'),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _exporting ? null : _sharePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Share PDF report'),
                        ),
                      ],
                    ),
    );
  }

  Widget _tile(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
