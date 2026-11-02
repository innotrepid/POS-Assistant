import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/day_closing_service.dart';
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
    final s = _summary;
    final r = _report;
    if (s == null || r == null) return;
    if (s.isClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This day is already closed')),
      );
      return;
    }

    // Always require PIN when one is set (even if "require unlock on open" is off).
    if (await _security.hasPin()) {
      final pinOk = await promptPinDialog(
        context,
        title: 'PIN to close day',
        security: _security,
      );
      if (!pinOk || !mounted) return;
    } else {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No PIN set'),
          content: const Text(
            'Closing without a PIN is less safe. Set a PIN in Settings when you can. Close anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close day'),
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
        const SnackBar(content: Text('Day closed')),
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
    final scheme = Theme.of(context).colorScheme;
    final s = _summary;
    final r = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Close day'),
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
                  ? const Center(child: Text('No data'))
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
                              ? 'Already closed — report only'
                              : 'Review the day, then confirm with PIN',
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
                                  'Day totals',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                _row('Sales total', Money.format(r.salesTotal),
                                    bold: true),
                                _row('Sales count', '${r.saleCount}'),
                                _row('Cash', Money.format(r.cash)),
                                _row('M-Pesa', Money.format(r.mpesa)),
                                if (r.card > 0)
                                  _row('Card', Money.format(r.card)),
                                if (r.other > 0)
                                  _row('Other paid', Money.format(r.other)),
                                _row(
                                  'New credit (deni)',
                                  Money.format(r.creditTotal),
                                ),
                                const Divider(height: 20),
                                _row(
                                  'Est. cost of goods',
                                  Money.format(r.estimatedCost),
                                ),
                                _row(
                                  'Est. gross profit',
                                  Money.format(r.grossProfit),
                                  bold: true,
                                ),
                                _row(
                                  'Expenses',
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
                                    'Sales by hour',
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
                                      'No completed sales yet today.',
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
                                    'Top items sold',
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
                            'Till count',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'M-Pesa is taken from sales '
                            '(${Money.format(s.salesMpesa)}) — no need to re-enter.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _openingCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Opening cash in till',
                              helperText: 'What was in the till this morning',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashCtrl,
                            decoration: InputDecoration(
                              labelText: 'Counted cash now',
                              helperText:
                                  'Cash sales today about ${Money.format(s.salesCash)}',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              border: OutlineInputBorder(),
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
                              _busy ? 'Closing…' : 'Confirm close with PIN',
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
      return const Center(child: Text('No data'));
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
