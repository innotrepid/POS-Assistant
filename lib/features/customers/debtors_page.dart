import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/debtor_service.dart';
import '../../services/policy_service.dart';
import 'customer_statement_page.dart';

/// Debt collection: outstanding + overdue, with Call / SMS prep.
class DebtorsPage extends StatefulWidget {
  const DebtorsPage({super.key});

  @override
  State<DebtorsPage> createState() => _DebtorsPageState();
}

class _DebtorsPageState extends State<DebtorsPage> {
  final _debtors = DebtorService();
  final _policies = PolicyService();
  final _profiles = BusinessProfileService.instance;

  List<DebtorSummary> _rows = [];
  double _total = 0;
  int _overdueDays = 30;
  String _shopName = 'Shop';
  bool _overdueOnly = false;
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
      final overdueDays = await _policies.getOverdueDebtDays();
      final shopName = await _profiles.getBusinessName();
      final rows = await _debtors.listOutstanding(overdueDays: overdueDays);
      final total = await _debtors.totalOutstanding();
      if (!mounted) return;
      setState(() {
        _overdueDays = overdueDays;
        _shopName = shopName;
        _rows = rows;
        _total = total;
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

  List<DebtorSummary> get _visible =>
      _overdueOnly ? _rows.where((d) => d.isOverdue).toList() : _rows;

  int get _overdueCount => _rows.where((d) => d.isOverdue).length;

  Future<void> _call(DebtorSummary d) async {
    final raw = d.phone?.trim() ?? '';
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on this customer')),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dialer: $e')));
    }
  }

  Future<void> _sms(DebtorSummary d) async {
    final raw = d.phone?.trim() ?? '';
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on this customer')),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    final body = DebtorService.collectionSmsBody(
      customerName: d.customerName,
      balance: d.balance,
      shopName: _shopName,
      daysOpen: d.daysOpen,
    );
    final uri = Uri(scheme: 'sms', path: digits, queryParameters: {'body': body});
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        await Clipboard.setData(ClipboardData(text: body));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS unavailable — message copied')),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open SMS — message copied')),
      );
    }
  }

  Future<void> _copyMessage(DebtorSummary d) async {
    final body = DebtorService.collectionSmsBody(
      customerName: d.customerName,
      balance: d.balance,
      shopName: _shopName,
      daysOpen: d.daysOpen,
    );
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection message copied')),
    );
  }

  Future<void> _openStatement(DebtorSummary d) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerStatementPage(
          customerId: d.customerId,
          customerName: d.customerName,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Debtors'),
        actions: [
          IconButton(
            tooltip: _overdueOnly ? 'Show all' : 'Overdue only',
            icon: Icon(_overdueOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _overdueOnly = !_overdueOnly),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final visible = _visible;
    return Column(
      children: [
        GlassPanel(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total outstanding'),
                trailing: Text(
                  Money.format(_total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _overdueCount == 0
                    ? 'No overdue (limit $_overdueDays days)'
                    : '$_overdueCount overdue (≥ $_overdueDays days) · filter: ${_overdueOnly ? 'overdue only' : 'all'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(child: Text(_overdueOnly ? 'No overdue debtors' : 'No outstanding balances'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final d = visible[index];
                    return GlassPanel(
                      margin: const EdgeInsets.only(bottom: 8),
                      borderRadius: 16,
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(d.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            if (d.isOverdue)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text([
                          if (d.phone != null && d.phone!.trim().isNotEmpty) d.phone!.trim(),
                          if (d.daysOpen > 0) '${d.daysOpen} day${d.daysOpen == 1 ? '' : 's'} open',
                        ].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Money.format(d.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: d.isOverdue ? Theme.of(context).colorScheme.error : null,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'call') await _call(d);
                                if (v == 'sms') await _sms(d);
                                if (v == 'copy') await _copyMessage(d);
                                if (v == 'statement') await _openStatement(d);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'call', child: Text('Call')),
                                PopupMenuItem(value: 'sms', child: Text('SMS (prep)')),
                                PopupMenuItem(value: 'copy', child: Text('Copy message')),
                                PopupMenuItem(value: 'statement', child: Text('Statement / repay')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _openStatement(d),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
