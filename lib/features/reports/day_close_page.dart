import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/day_closing_service.dart';
import '../../services/locale_service.dart';
import '../../services/report_service.dart';
import '../../services/security_service.dart';
import '../security/lock_screen.dart';

/// Full close-day flow: day report + graph, then PIN, then till count.
class DayClosePage extends StatefulWidget {
  final DateTime? day;

  const DayClosePage({super.key, this.day});

  @override
  State<DayClosePage> createState() => _DayClosePageState();
}

class _DayClosePageState extends State<DayClosePage> {
  final _dayClose = DayClosingService();
  final _reports = ReportService();
  final _security = SecurityService();

  late final DateTime _day;
  DaySummary? _summary;
  DaySalesReport? _report;
  List<HourlySalesBucket> _hours = [];
  List<StockRow> _topItems = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _openingCtrl = TextEditingController(text: '0');
  final _cashCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = widget.day ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    _cashCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _dayClose.getSummary(_day);
      final report = await _reports.daySales(_day);
      final hours = await _reports.salesByHour(_day);
      final sold = await _reports.itemsSoldOnDay(_day);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _report = report;
        _hours = hours;
        _topItems = sold.take(8).toList();
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

  Future<void> _confirmClose() async {
    final loc = localeController.s;
    final s = _summary;
    final r = _report;
    if (s == null || r == null) return;
    if (s.isClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.thisDayAlreadyClosed)),
      );
      return;
    }

    if (await _security.hasPin()) {
      final pinOk = await promptPinDialog(
        context,
        title: loc.pinToCloseDay,
        security: _security,
      );
      if (!pinOk || !mounted) return;
    } else {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.noPinSet),
          content: Text(
            loc.isSw
                ? 'Kufunga bila PIN si salama sana. Weka PIN kwenye Mipangilio. Endelea kufunga?'
                : 'Closing without a PIN is less safe. Set a PIN in Settings when you can. Close anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.closeDay),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await _dayClose.closeDay(
        day: _day,
        openingCash: Money.parse(_openingCtrl.text),
        countedCash: Money.parse(_cashCtrl.text),
        countedMpesa: s.salesMpesa,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.dayClosed)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = localeController.s;
    final scheme = Theme.of(context).colorScheme;
    final s = _summary;
    final r = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.closeDay),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _load,
          ),
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
              : s == null || r == null
                  ? Center(child: Text(loc.noData))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        Text(
                          s.businessDate,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.isClosed
                              ? loc.alreadyClosed
                              : loc.reviewThenPin,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.dayTotals,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                _row(loc.salesTotal, Money.format(r.salesTotal),
                                    bold: true),
                                _row(loc.salesCount, '${r.saleCount}'),
                                _row(loc.cash, Money.format(r.cash)),
                                _row(loc.mpesa, Money.format(r.mpesa)),
                                if (r.card > 0)
                                  _row(loc.card, Money.format(r.card)),
                                if (r.other > 0)
                                  _row(loc.otherPaid, Money.format(r.other)),
                                _row(
                                  loc.newCredit,
                                  Money.format(r.creditTotal),
                                ),
                                const Divider(height: 20),
                                _row(
                                  loc.estCostGoods,
                                  Money.format(r.estimatedCost),
                                ),
                                _row(
                                  loc.estGrossProfit,
                                  Money.format(r.grossProfit),
                                  bold: true,
                                ),
                                _row(
                                  loc.expenses,
                                  Money.format(r.expensesTotal),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    loc.salesByHour,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 160,
                                  child: _HourlyBarChart(
                                    buckets: _hours,
                                    color: scheme.primary,
                                  ),
                                ),
                                if (_hours.every((b) => b.salesTotal <= 0))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      loc.noCompletedSalesToday,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_topItems.isNotEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.topItemsSold,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final item in _topItems)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(item.name)),
                                          Text(
                                            _qty(item.quantity),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (!s.isClosed) ...[
                          const SizedBox(height: 16),
                          Text(
                            loc.tillCount,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${loc.mpesaFromSales} (${Money.format(s.salesMpesa)})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _openingCtrl,
                            decoration: InputDecoration(
                              labelText: loc.openingCash,
                              helperText: loc.openingCashHint,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashCtrl,
                            decoration: InputDecoration(
                              labelText: loc.countedCashNow,
                              helperText:
                                  '${loc.cash}: ${Money.format(s.salesCash)}',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesCtrl,
                            decoration: InputDecoration(
                              labelText: loc.notesOptional,
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _busy ? null : _confirmClose,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline),
                            label: Text(
                              _busy ? loc.closingBusy : loc.confirmCloseWithPin,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
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
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
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

class _HourlyBarChart extends StatelessWidget {
  final List<HourlySalesBucket> buckets;
  final Color color;

  const _HourlyBarChart({
    required this.buckets,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return Center(child: Text(localeController.s.noData));
    }
    final maxV = buckets.fold<double>(
      0,
      (m, b) => b.salesTotal > m ? b.salesTotal : m,
    );
    final scale = maxV <= 0 ? 1.0 : maxV;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final b in buckets)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Tooltip(
                            message:
                                '${b.label}: ${Money.format(b.salesTotal)} (${b.saleCount})',
                            child: FractionallySizedBox(
                              heightFactor: maxV <= 0
                                  ? 0.02
                                  : (b.salesTotal / scale).clamp(0.02, 1.0),
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: b.salesTotal > 0
                                      ? color
                                      : color.withOpacity(0.15),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
