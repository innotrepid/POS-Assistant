import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/report_service.dart';

/// Weekly and monthly sales graphs for the stall.
class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage>
    with SingleTickerProviderStateMixin {
  final _reports = ReportService();
  late final TabController _tabs;

  PeriodSeries? _week;
  PeriodSeries? _month;
  PeriodSeries? _last30;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final week = await _reports.calendarWeekSeries();
      final month = await _reports.thisMonthSeries();
      final last30 = await _reports.last30DaysSeries();
      if (!mounted) return;
      setState(() {
        _week = week;
        _month = month;
        _last30 = last30;
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
        title: const Text('Trends'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Week'),
            Tab(text: 'Month'),
            Tab(text: '30 days'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
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
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _PeriodTab(series: _week),
                    _PeriodTab(series: _month, denseLabels: true),
                    _PeriodTab(series: _last30, denseLabels: true),
                  ],
                ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final PeriodSeries? series;
  final bool denseLabels;

  const _PeriodTab({
    required this.series,
    this.denseLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = series;
    if (s == null) {
      return const Center(child: Text('No data'));
    }
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          s.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bars show daily sales. Long-press a bar for the amount.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _sumRow('Sales', Money.format(s.salesTotal), bold: true),
                _sumRow('Sales count', '${s.saleCount}'),
                _sumRow('Est. gross profit', Money.format(s.grossProfit)),
                _sumRow('Expenses', Money.format(s.expensesTotal)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'Sales by day',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: _PeriodBarChart(
                    buckets: s.days,
                    color: scheme.primary,
                    denseLabels: denseLabels,
                  ),
                ),
                if (s.days.every((d) => d.salesTotal <= 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 6),
                    child: Text(
                      'No completed sales in this period yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day by day',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final d in s.days.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            d.shortLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d.businessDate,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          Money.format(d.salesTotal),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sumRow(String label, String value, {bool bold = false}) {
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
}

class _PeriodBarChart extends StatelessWidget {
  final List<PeriodBucket> buckets;
  final Color color;
  final bool denseLabels;

  const _PeriodBarChart({
    required this.buckets,
    required this.color,
    this.denseLabels = false,
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

    // For long series, only label every nth day to avoid clutter.
    final labelEvery = denseLabels && buckets.length > 14
        ? 3
        : denseLabels && buckets.length > 7
            ? 2
            : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < buckets.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: buckets.length > 14 ? 0.5 : 1.5,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Tooltip(
                        message:
                            '${buckets[i].businessDate}: ${Money.format(buckets[i].salesTotal)} (${buckets[i].saleCount} sales)',
                        child: FractionallySizedBox(
                          heightFactor: maxV <= 0
                              ? 0.02
                              : (buckets[i].salesTotal / scale)
                                  .clamp(0.02, 1.0),
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: buckets[i].salesTotal > 0
                                  ? color
                                  : color.withOpacity(0.15),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i % labelEvery == 0 ? buckets[i].shortLabel : '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: denseLabels ? 8 : 10,
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
  }
}
