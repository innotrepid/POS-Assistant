import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/collection_service.dart';
import '../../services/debtor_service.dart';
import '../../services/policy_service.dart';
import 'customer_statement_page.dart';

/// Debt collection: outstanding + overdue, Call/SMS, promises, contact log.
class DebtorsPage extends StatefulWidget {
  const DebtorsPage({super.key});

  @override
  State<DebtorsPage> createState() => _DebtorsPageState();
}

class _DebtorsPageState extends State<DebtorsPage> {
  final _debtors = DebtorService();
  final _policies = PolicyService();
  final _profiles = BusinessProfileService.instance;
  final _collection = CollectionService();

  List<DebtorSummary> _rows = [];
  final Map<String, PromiseToPay?> _promises = {};
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
      final promiseMap = <String, PromiseToPay?>{};
      for (final d in rows) {
        promiseMap[d.customerId] =
            await _collection.latestOpenPromise(d.customerId);
      }
      if (!mounted) return;
      setState(() {
        _overdueDays = overdueDays;
        _shopName = shopName;
        _rows = rows;
        _total = total;
        _promises
          ..clear()
          ..addAll(promiseMap);
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

  Future<void> _afterContact({
    required DebtorSummary d,
    required String channel,
  }) async {
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How did it go with ${d.customerName}?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in [
                      ('no_answer', 'No answer'),
                      ('spoke', 'Spoke'),
                      ('busy', 'Busy'),
                      ('wrong_number', 'Wrong number'),
                      ('promised_tomorrow', 'Promised tomorrow'),
                      ('promised_friday', 'Promised Friday'),
                      ('will_pay_later', 'Will pay later'),
                      ('paid_partial', 'Paid partial'),
                      ('skip', 'Skip log'),
                    ])
                      ActionChip(
                        label: Text(e.$2),
                        onPressed: () => Navigator.pop(context, e.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || result == 'skip' || !mounted) return;

    await _collection.logCommunication(
      partyType: 'customer',
      partyId: d.customerId,
      partyName: d.customerName,
      channel: channel,
      result: result,
    );

    // Auto-create promise for common outcomes
    if (result == 'promised_tomorrow' || result == 'promised_friday') {
      final when = result == 'promised_tomorrow'
          ? DateTime.now().add(const Duration(days: 1))
          : _nextWeekday(DateTime.friday);
      await _collection.recordPromise(
        customerId: d.customerId,
        promisedDate: when,
        notes: 'From $channel contact',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged: ${_labelResult(result)}')),
    );
    _load();
  }

  DateTime _nextWeekday(int weekday) {
    var d = DateTime.now();
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != weekday);
    return d;
  }

  String _labelResult(String code) {
    return switch (code) {
      'no_answer' => 'No answer',
      'spoke' => 'Spoke',
      'busy' => 'Busy',
      'wrong_number' => 'Wrong number',
      'promised_tomorrow' => 'Promised tomorrow',
      'promised_friday' => 'Promised Friday',
      'will_pay_later' => 'Will pay later',
      'paid_partial' => 'Paid partial',
      _ => code,
    };
  }

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
        return;
      }
      await _afterContact(d: d, channel: 'call');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dialer: $e')),
      );
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
    final uri =
        Uri(scheme: 'sms', path: digits, queryParameters: {'body': body});
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        await Clipboard.setData(ClipboardData(text: body));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS unavailable — message copied')),
        );
      }
      await _afterContact(d: d, channel: 'sms');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open SMS — message copied')),
      );
      await _afterContact(d: d, channel: 'sms');
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

  Future<void> _setPromise(DebtorSummary d) async {
    DateTime date = DateTime.now().add(const Duration(days: 1));
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Promise — ${d.customerName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Promised date'),
                      subtitle: Text(
                        date.toIso8601String().substring(0, 10),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setLocal(() => date = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    final amount = Money.parse(amountCtrl.text);
    await _collection.recordPromise(
      customerId: d.customerId,
      promisedDate: date,
      amount: amount > 0 ? amount : null,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promise saved')),
    );
    _load();
  }

  Future<void> _showCommLog(DebtorSummary d) async {
    final log = await _collection.recentCommunications(
      partyId: d.customerId,
      limit: 30,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Contact log — ${d.customerName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (log.isEmpty)
                  const Text('No contact history yet.')
                else
                  for (final e in log)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        e.channel == 'call'
                            ? Icons.call
                            : e.channel == 'sms'
                                ? Icons.sms
                                : Icons.chat_bubble_outline,
                      ),
                      title: Text(
                        '${e.channel.toUpperCase()}'
                        '${e.result != null ? ' · ${_labelResult(e.result!)}' : ''}',
                      ),
                      subtitle: Text(
                        e.createdAt.toIso8601String().replaceFirst('T', ' '),
                      ),
                    ),
              ],
            );
          },
        );
      },
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
            icon: Icon(
              _overdueOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Text(
                _overdueCount == 0
                    ? 'No overdue (limit $_overdueDays days)'
                    : '$_overdueCount overdue (≥ $_overdueDays days) · '
                        'filter: ${_overdueOnly ? 'overdue only' : 'all'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _overdueOnly
                        ? 'No overdue debtors'
                        : 'No outstanding balances',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final d = visible[index];
                    final promise = _promises[d.customerId];
                    return GlassPanel(
                      margin: const EdgeInsets.only(bottom: 8),
                      borderRadius: 16,
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (d.isOverdue)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (d.phone != null && d.phone!.trim().isNotEmpty)
                              d.phone!.trim(),
                            if (d.daysOpen > 0)
                              '${d.daysOpen} day${d.daysOpen == 1 ? '' : 's'} open',
                            if (promise != null)
                              'Promise ${promise.promisedDate.toIso8601String().substring(0, 10)}'
                              '${promise.amount != null ? ' · ${Money.format(promise.amount!)}' : ''}',
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Money.format(d.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: d.isOverdue
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'call') await _call(d);
                                if (v == 'sms') await _sms(d);
                                if (v == 'copy') await _copyMessage(d);
                                if (v == 'promise') await _setPromise(d);
                                if (v == 'log') await _showCommLog(d);
                                if (v == 'statement') await _openStatement(d);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'call',
                                  child: Text('Call'),
                                ),
                                PopupMenuItem(
                                  value: 'sms',
                                  child: Text('SMS (prep)'),
                                ),
                                PopupMenuItem(
                                  value: 'copy',
                                  child: Text('Copy message'),
                                ),
                                PopupMenuItem(
                                  value: 'promise',
                                  child: Text('Set promise to pay'),
                                ),
                                PopupMenuItem(
                                  value: 'log',
                                  child: Text('Contact log'),
                                ),
                                PopupMenuItem(
                                  value: 'statement',
                                  child: Text('Statement / repay'),
                                ),
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
