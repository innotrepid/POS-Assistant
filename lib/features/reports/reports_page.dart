import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Reports',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
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
      return Center(
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
          child: Text(_error!),
        ),
      );
    }

    final day = _day!;
    final stockValue = _stock.fold<double>(0, (s, r) => s + r.stockValue);
    final debtorsTotal = _debtors.fold<double>(0, (s, r) => s + r.balance);
    final creditorsTotal = _creditors.fold<double>(0, (s, r) => s + r.balance);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_exporting) const LinearProgressIndicator(),

        GlassPanel(
          accent: true,
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day.businessDate,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                Money.format(day.salesTotal),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
              ),
              Text(
                '${day.saleCount} sales · profit est. ${Money.format(day.grossProfit)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _mini(
                'Cash',
                Money.format(day.cash),
                Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mini(
                'M-Pesa',
                Money.format(day.mpesa),
                Icons.phone_android_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _mini(
                'Credit',
                Money.format(day.creditTotal),
                Icons.handshake_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mini(
                'Expenses',
                Money.format(day.expensesTotal),
                Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock value',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                Money.format(stockValue),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                '${_stock.length} products at cost',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debtors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                Money.format(debtorsTotal),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (_debtors.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('None'),
                )
              else
                ..._debtors.take(8).map(
                      (d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(d.name),
                        trailing: Text(
                          Money.format(d.balance),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creditors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                Money.format(creditorsTotal),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (_creditors.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('None'),
                )
              else
                ..._creditors.take(8).map(
                      (c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(c.name),
                        trailing: Text(
                          Money.format(c.balance),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
            ],
          ),
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

  Widget _mini(String label, String value, IconData icon) {
    return GlassPanel(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
