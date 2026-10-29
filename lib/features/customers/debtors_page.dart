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
  final _searchCtrl = TextEditingController();

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        _shopName = shopName.isEmpty ? 'Shop' : shopName;
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

  List<DebtorSummary> get _visible {
    var list = _overdueOnly
        ? _rows.where((d) => d.isOverdue).toList()
        : List<DebtorSummary>.from(_rows);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((d) =>
              d.customerName.toLowerCase().contains(q) ||
              (d.phone ?? '').contains(q))
          .toList();
    }
    return list;
  }

  int get _overdueCount => _rows.where((d) => d.isOverdue).length;

  DateTime _nextWeekday(int weekday) {
    var d = DateTime.now();
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != weekday);
    return d;
  }

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How did it go with ${d.customerName}?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  channel == 'call'
                      ? 'Log the call so you remember next time.'
                      : 'Log the SMS outcome.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in [
                      ('no_answer', 'No answer', Icons.phone_missed_outlined),
                      ('unreachable', 'Unreachable', Icons.signal_wifi_off_outlined),
                      ('busy', 'Busy', Icons.phone_locked_outlined),
                      ('spoke', 'Spoke', Icons.phone_in_talk_outlined),
                      ('promised_tomorrow', 'Promised tomorrow', Icons.event_available_outlined),
                      ('promised_friday', 'Promised Friday', Icons.event_outlined),
                      ('will_pay_later', 'Will pay later', Icons.schedule_outlined),
                      ('paid_partial', 'Paid partial', Icons.payments_outlined),
                      ('wrong_number', 'Wrong number', Icons.phonelink_erase_outlined),
                      ('skip', 'Skip', Icons.close),
                    ])
                      ActionChip(
                        avatar: Icon(e.$3, size: 18),
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
    final labels = {
      'no_answer': 'No answer',
      'unreachable': 'Unreachable',
      'busy': 'Busy',
      'spoke': 'Spoke',
      'promised_tomorrow': 'Promised tomorrow',
      'promised_friday': 'Promised Friday',
      'will_pay_later': 'Will pay later',
      'paid_partial': 'Paid partial',
      'wrong_number': 'Wrong number',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged: ${labels[result] ?? result}')),
    );
    await _load();
  }

  Future<void> _call(DebtorSummary d) async {
    final raw = d.phone?.trim() ?? '';
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number — add it under Customers')),
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
                      subtitle: Text(date.toIso8601String().substring(0, 10)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setLocal(() => date = picked);
                      },
                    ),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (optional)',
                        helperText: 'Leave empty if full balance',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      final raw = amountCtrl.text.trim();
      final amount = raw.isEmpty ? null : Money.parse(raw);
      await _collection.recordPromise(
        customerId: d.customerId,
        promisedDate: date,
        amount: amount,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promise saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showCommLog(DebtorSummary d) async {
    final list = await _collection.recentCommunications(limit: 30);
    final mine = list.where((e) => e.partyId == d.customerId).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
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
                  'Contact log — ${d.customerName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                if (mine.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No calls or SMS logged yet.'),
                  )
                else
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      itemCount: mine.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = mine[i];
                        final icon = e.channel == 'call'
                            ? Icons.call
                            : e.channel == 'sms'
                                ? Icons.sms
                                : Icons.chat_bubble_outline;
                        final when = e.createdAt
                            .toIso8601String()
                            .substring(0, 16)
                            .replaceFirst('T', ' ');
                        return ListTile(
                          dense: true,
                          leading: Icon(icon, size: 20),
                          title: Text(e.result ?? e.channel),
                          subtitle: Text(when),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who owes you'),
        actions: [
          IconButton(
            tooltip: _overdueOnly ? 'Show all' : 'Overdue only',
            icon: Icon(
              _overdueOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _overdueOnly ? scheme.error : null,
            ),
            onPressed: () => setState(() => _overdueOnly = !_overdueOnly),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
          borderRadius: 16,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total outstanding',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          Money.format(_total),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_overdueCount > 0)
                    Chip(
                      avatar: Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                      label: Text('$_overdueCount overdue'),
                      side: BorderSide(color: scheme.error.withOpacity(0.4)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _overdueCount == 0
                    ? 'No overdue (limit $_overdueDays days) · ${_rows.length} open'
                    : '$_overdueCount overdue (≥ $_overdueDays days) · filter: ${_overdueOnly ? 'overdue only' : 'all'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      _rows.isEmpty
                          ? 'No one owes you right now.\nCredit sales will appear here.'
                          : 'No matches for that search.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final d = visible[index];
                    final promise = _promises[d.customerId];
                    final hasPhone = (d.phone ?? '').trim().isNotEmpty;

                    return Card(
                      elevation: 0,
                      color: scheme.surfaceContainerHighest.withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: d.isOverdue
                              ? scheme.error.withOpacity(0.45)
                              : scheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openStatement(d),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: d.isOverdue
                                        ? scheme.errorContainer
                                        : scheme.primaryContainer,
                                    child: Text(
                                      d.customerName.isNotEmpty
                                          ? d.customerName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: d.isOverdue
                                            ? scheme.onErrorContainer
                                            : scheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.customerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (hasPhone) d.phone!,
                                            if (d.daysOpen > 0)
                                              '${d.daysOpen} day${d.daysOpen == 1 ? '' : 's'} open',
                                            if (d.isOverdue) 'OVERDUE',
                                          ].join(' · '),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: d.isOverdue ? scheme.error : null,
                                                fontWeight: d.isOverdue ? FontWeight.w600 : null,
                                              ),
                                        ),
                                        if (promise != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Promise ${promise.promisedDate.toIso8601String().substring(0, 10)}'
                                              '${promise.amount != null ? ' · ${Money.format(promise.amount!)}' : ''}',
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: scheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8, top: 4),
                                    child: Text(
                                      Money.format(d.balance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: d.isOverdue ? scheme.error : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: 'Call',
                                    onPressed: hasPhone ? () => _call(d) : null,
                                    icon: const Icon(Icons.call, size: 20),
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'SMS',
                                    onPressed: hasPhone ? () => _sms(d) : null,
                                    icon: const Icon(Icons.sms_outlined, size: 20),
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'Promise to pay',
                                    onPressed: () => _setPromise(d),
                                    icon: const Icon(Icons.event_available_outlined, size: 20),
                                  ),
                                  const Spacer(),
                                  PopupMenuButton<String>(
                                    tooltip: 'More',
                                    onSelected: (v) async {
                                      if (v == 'copy') await _copyMessage(d);
                                      if (v == 'log') await _showCommLog(d);
                                      if (v == 'statement') await _openStatement(d);
                                      if (v == 'call') await _call(d);
                                      if (v == 'sms') await _sms(d);
                                      if (v == 'promise') await _setPromise(d);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'call', child: Text('Call')),
                                      PopupMenuItem(value: 'sms', child: Text('SMS')),
                                      PopupMenuItem(value: 'copy', child: Text('Copy message')),
                                      PopupMenuItem(value: 'promise', child: Text('Set promise')),
                                      PopupMenuItem(value: 'log', child: Text('Contact log')),
                                      PopupMenuItem(value: 'statement', child: Text('Statement / repay')),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
