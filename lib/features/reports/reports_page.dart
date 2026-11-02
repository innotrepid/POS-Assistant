import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/excel_report_builder.dart';
import '../../services/pdf_report_builder.dart';
import '../../services/locale_service.dart';
import '../../services/report_service.dart';
import 'trends_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _reports = ReportService();
  final _pdf = PdfReportBuilder();
  final _excel = ExcelReportBuilder();
  final _profiles = BusinessProfileService.instance;

  DaySalesReport? _day;
  List<StockRow> _stock = [];
  List<StockRow> _sold = [];
  List<StockRow> _lowStock = [];
  List<PartyBalanceRow> _debtors = [];
  List<PartyBalanceRow> _creditors = [];
  List<CategoryTotal> _expenseCats = [];
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
      final sold = await _reports.itemsSoldOnDay();
      final low = await _reports.lowStockItems();
      final debtors = await _reports.debtorsOutstanding();
      final creditors = await _reports.creditorsOutstanding();
      final exp = await _reports.expensesByCategory();
      final shop = await _profiles.getBusinessName();
      if (!mounted) return;
      setState(() {
        _day = day;
        _stock = stock;
        _sold = sold;
        _lowStock = low;
        _debtors = debtors;
        _creditors = creditors;
        _expenseCats = exp;
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
      final bytes = await _pdf.buildBusinessReport(
        shopName: _shopName,
        day: day,
        stock: _sold,
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

  Future<void> _shareExcel() async {
    if (_day == null) return;
    setState(() => _exporting = true);
    try {
      final week = await _reports.calendarWeekSeries();
      final month = await _reports.thisMonthSeries();
      await _excel.shareWorkbook(
        shopName: _shopName,
        day: _day!,
        itemsSold: _sold,
        stock: _stock,
        debtors: _debtors,
        creditors: _creditors,
        expensesByCategory: _expenseCats,
        lowStock: _lowStock,
        week: week,
        month: month,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel failed: $e')),
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
      final bytes = await _pdf.buildBusinessReport(
        shopName: _shopName,
        day: day,
        stock: _sold,
        debtors: _debtors,
        creditors: _creditors,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(localeController.s.previewPdf)),
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

  void _openTrends() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrendsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = localeController.s;
    final day = _day;
    final debtorsTotal = _debtors.fold<double>(0, (sum, r) => sum + r.balance);
    final stockValue = _stock.fold<double>(0, (sum, r) => sum + r.stockValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.reports),
        actions: [
          IconButton(
            tooltip: s.weekMonthGraphs,
            icon: const Icon(Icons.show_chart),
            onPressed: _openTrends,
          ),
          IconButton(
            tooltip: s.previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : _previewPdf,
          ),
          IconButton(
            tooltip: s.shareExcel,
            icon: const Icon(Icons.table_view_outlined),
            onPressed: _exporting ? null : _shareExcel,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : day == null
                  ? Center(child: Text(s.noData))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        Text(
                          'Today · ${day.businessDate}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shopName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.4),
                          child: ListTile(
                            leading: const Icon(Icons.show_chart),
                            title: Text(s.weekMonthGraphs),
                            subtitle: Text(s.weekMonthHint),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _openTrends,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassPanel(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.salesToday,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              _row(s.sales, Money.format(day.salesTotal),
                                  bold: true),
                              _row(s.cash, Money.format(day.cash)),
                              _row(s.mpesa, Money.format(day.mpesa)),
                              if (day.card > 0)
                                _row('Card', Money.format(day.card)),
                              _row(
                                'New credit (deni)',
                                Money.format(day.creditTotal),
                              ),
                              _row('Sale count', '${day.saleCount}'),
                              const Divider(height: 20),
                              _row(
                                'Est. cost of goods',
                                Money.format(day.estimatedCost),
                              ),
                              _row(
                                'Est. gross profit',
                                Money.format(day.grossProfit),
                                bold: true,
                              ),
                              _row(
                                s.expenses,
                                Money.format(day.expensesTotal),
                              ),
                            ],
                          ),
                        ),
                        if (_sold.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GlassPanel(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.topItemsToday,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ..._sold.take(8).map(
                                      (i) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(i.name),
                                        trailing: Text(
                                          _qty(i.quantity),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                        if (_expenseCats.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GlassPanel(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.expensesByCategory,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ..._expenseCats.map(
                                  (e) => _row(
                                    e.category,
                                    Money.format(e.total),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GlassPanel(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.stockOnHand,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _row('Products', '${_stock.length}'),
                              _row(
                                'Value at cost',
                                Money.format(stockValue),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        if (_lowStock.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GlassPanel(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.lowStock,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ..._lowStock.take(10).map(
                                      (i) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(i.name),
                                        trailing: Text(
                                          _qty(i.quantity),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GlassPanel(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.whoOwes,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _row(
                                'Outstanding',
                                Money.format(debtorsTotal),
                                bold: true,
                              ),
                              if (_debtors.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(s.noOpenBalances),
                                )
                              else
                                ..._debtors.take(8).map(
                                      (d) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(d.name),
                                        subtitle: d.phone != null
                                            ? Text(d.phone!)
                                            : null,
                                        trailing: Text(
                                          Money.format(d.balance),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        if (_creditors.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GlassPanel(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.whatYouOwe,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ..._creditors.take(6).map(
                                      (c) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(c.name),
                                        trailing: Text(
                                          Money.format(c.balance),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _exporting ? null : _sharePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(s.sharePdf),
                        ),
                      ],
                    ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: bold
                ? const TextStyle(fontWeight: FontWeight.w800)
                : null,
          ),
        ],
      ),
    );
  }

  String _qty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toStringAsFixed(1);
  }
}
