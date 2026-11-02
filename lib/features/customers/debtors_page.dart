import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/collection_service.dart';
import '../../services/debtor_service.dart';
import '../../services/locale_service.dart';
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
  /// 0=all, 1=overdue, 2=promises today
  int _filterMode = 0;
  List<PromiseToPay> _dueToday = const [];
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
      List<PromiseToPay> dueToday = const [];
      try {
        dueToday = await _collection.listPromisesDueOn(DateTime.now());
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _overdueDays = overdueDays;
        _shopName = shopName.isEmpty ? 'Shop' : shopName;
        _rows = rows;
        _total = total;
        _dueToday = dueToday;
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
    var list = List<DebtorSummary>.from(_rows);
    if (_filterMode == 1 || _overdueOnly) {
      list = list.where((d) => d.isOverdue).toList();
    } else if (_filterMode == 2) {
      final ids = _dueToday.map((pr) => pr.customerId).toSet();
      list = list.where((d) => ids.contains(d.customerId)).toList();
    }
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

  String _smsBody(DebtorSummary d, {bool promiseReminder = false}) {
    final sw = localeController.isSwahili;
    if (promiseReminder) {
      return DebtorService.promiseDueSmsBody(
        customerName: d.customerName,
        balance: d.balance,
        shopName: _shopName,
        promisedDate: sw ? 'leo' : 'today',
        swahili: sw,
      );
    }
    return DebtorService.collectionSmsBody(
      customerName: d.customerName,
      balance: d.balance,
      shopName: _shopName,
      daysOpen: d.daysOpen,
      swahili: sw,
    );
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
    final loc = localeController.s;
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
                  '${loc.howDidItGo} ${d.customerName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  channel == 'call' ? loc.logCallHint : loc.logSmsHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in [
                      ('no_answer', loc.outcomeNoAnswer, Icons.phone_missed_outlined),
                      ('unreachable', loc.outcomeUnreachable, Icons.signal_wifi_off_outlined),
                      ('busy', loc.outcomeBusy, Icons.phone_locked_outlined),
                      ('spoke', loc.outcomeSpoke, Icons.phone_in_talk_outlined),
                      ('promised_tomorrow', loc.outcomePromisedTomorrow, Icons.event_available_outlined),
                      ('promised_friday', loc.outcomePromisedFriday, Icons.event_outlined),
                      ('will_pay_later', loc.outcomeWillPayLater, Icons.schedule_outlined),
                      ('paid_partial', loc.outcomePaidPartial, Icons.payments_outlined),
                      ('wrong_number', loc.outcomeWrongNumber, Icons.phonelink_erase_outlined),
                      ('skip', loc.skip, Icons.close),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged: $result')),
    );
    await _load();
  }

  Future<void> _call(DebtorSummary d) async {
    final raw = d.phone?.trim() ?? '';
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localeController.s.noPhoneNumber)),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeController.s.couldNotOpenDialer)),
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
        SnackBar(content: Text(localeController.s.noPhoneNumber)),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    final promiseIds = _dueToday.map((pr) => pr.customerId).toSet();
    final body = _smsBody(d, promiseReminder: promiseIds.contains(d.customerId));
    final uri =
        Uri(scheme: 'sms', path: digits, queryParameters: {'body': body});
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        await Clipboard.setData(ClipboardData(text: body));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeController.s.copyMessage)),
        );
      }
      await _afterContact(d: d, channel: 'sms');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localeController.s.copyMessage)),
      );
      await _afterContact(d: d, channel: 'sms');
    }
  }

  Future<void> _copyMessage(DebtorSummary d) async {
    final promiseIds = _dueToday.map((pr) => pr.customerId).toSet();
    final body = _smsBody(d, promiseReminder: promiseIds.contains(d.customerId));
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localeController.s.copyMessage)),
    );
  }

  Future<void> _setPromise(DebtorSummary d) async {
    final s = localeController.s;
    DateTime date = DateTime.now().add(const Duration(days: 1));
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('${s.promiseToPay} — ${d.customerName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.promisedDate),
                      subtitle: Text(date.toIso8601String().substring(0, 10)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setLocal(() => date = picked);
                      },
                    ),
                    TextField(
                      controller: amountCtrl,
                      decoration: InputDecoration(labelText: s.amount),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(labelText: s.noteOptional),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(s.save),
                ),
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
        SnackBar(content: Text(s.setPromise)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _resolvePromise(PromiseToPay pr, {String status = 'kept'}) async {
    try {
      await _collection.resolvePromise(pr.id, status: status);
      await _load();
      if (!mounted) return;
      final sw = localeController.isSwahili;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'kept'
                ? (sw ? 'Ahadi imefungwa (amelipa)' : 'Promise marked kept')
                : (sw ? 'Ahadi imevunjwa' : 'Promise marked broken'),
          ),
        ),
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
                  '${localeController.s.contactLog} — ${d.customerName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                if (mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(localeController.s.noCallsLogged),
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
    final s = localeController.s;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.whoOwes),
        actions: [
          if (_dueToday.isNotEmpty)
            IconButton(
              tooltip: localeController.isSwahili
                  ? 'Ahadi za leo (${_dueToday.length})'
                  : 'Promises today (${_dueToday.length})',
              icon: Badge(
                isLabelVisible: true,
                label: Text('${_dueToday.length}'),
                child: Icon(
                  Icons.event_available_outlined,
                  color: _filterMode == 2 ? scheme.primary : null,
                ),
              ),
              onPressed: () => setState(() {
                _filterMode = _filterMode == 2 ? 0 : 2;
                _overdueOnly = false;
              }),
            ),
          IconButton(
            tooltip: _filterMode == 1 ? s.showAll : s.overdueOnly,
            icon: Icon(
              _filterMode == 1 ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _filterMode == 1 ? scheme.error : null,
            ),
            onPressed: () => setState(() {
              if (_filterMode == 1) {
                _filterMode = 0;
                _overdueOnly = false;
              } else {
                _filterMode = 1;
                _overdueOnly = true;
              }
            }),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(scheme, s),
    );
  }

  Widget _buildBody(ColorScheme scheme, dynamic s) {
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
              FilledButton(onPressed: _load, child: Text(s.retry)),
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
                          s.totalOutstanding,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          Money.format(_total),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  if (_overdueCount > 0)
                    Chip(
                      avatar: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: scheme.error,
                      ),
                      label: Text('$_overdueCount'),
                      side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_dueToday.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Material(
              color: scheme.tertiaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localeController.isSwahili
                          ? 'Ahadi za leo (${_dueToday.length})'
                          : 'Promises due today (${_dueToday.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localeController.isSwahili
                          ? 'Wateja walioahidi kulipa leo — piga simu au tuma SMS.'
                          : 'Customers who promised to pay today — call or SMS.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final pr in _dueToday.take(5))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(pr.customerName ?? pr.customerId),
                        subtitle: Text(
                          pr.amount != null
                              ? Money.format(pr.amount!)
                              : (localeController.isSwahili
                                  ? 'Kiasi hakijawekwa'
                                  : 'Amount not set'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.sms_outlined),
                              tooltip: s.sms,
                              onPressed: () {
                                final match = _rows
                                    .where((d) => d.customerId == pr.customerId)
                                    .toList();
                                if (match.isEmpty) return;
                                _sms(match.first);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              tooltip: localeController.isSwahili
                                  ? 'Amelipa'
                                  : 'Kept',
                              onPressed: () =>
                                  _resolvePromise(pr, status: 'kept'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined),
                              tooltip: localeController.isSwahili
                                  ? 'Hakulipa'
                                  : 'Broken',
                              onPressed: () =>
                                  _resolvePromise(pr, status: 'broken'),
                            ),
                          ],
                        ),
                        onTap: () {
                          final match = _rows
                              .where((d) => d.customerId == pr.customerId)
                              .toList();
                          if (match.isEmpty) return;
                          _openStatement(match.first);
                        },
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _filterMode = 2;
                          _overdueOnly = false;
                        }),
                        child: Text(
                          localeController.isSwahili
                              ? 'Onyesha orodha'
                              : 'Show list',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: s.searchNamePhone,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _filterMode == 2
                        ? (localeController.isSwahili
                            ? 'Hakuna ahadi za leo'
                            : 'No promises due today')
                        : s.noOpenBalances,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = visible[index];
                    final promise = _promises[d.customerId];
                    return ListTile(
                      title: Text(
                        d.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          Money.format(d.balance),
                          if (d.isOverdue)
                            (localeController.isSwahili ? 'Imechelewa' : 'Overdue'),
                          if (promise != null)
                            (localeController.isSwahili
                                ? 'Ahadi ${promise.promisedDate.toIso8601String().substring(0, 10)}'
                                : 'Promise ${promise.promisedDate.toIso8601String().substring(0, 10)}'),
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.call,
                            icon: const Icon(Icons.call_outlined),
                            onPressed: () => _call(d),
                          ),
                          IconButton(
                            tooltip: s.sms,
                            icon: const Icon(Icons.sms_outlined),
                            onPressed: () => _sms(d),
                          ),
                          PopupMenuButton<String>(
                            tooltip: s.more,
                            onSelected: (v) async {
                              if (v == 'call') await _call(d);
                              if (v == 'sms') await _sms(d);
                              if (v == 'copy') await _copyMessage(d);
                              if (v == 'promise') await _setPromise(d);
                              if (v == 'kept' || v == 'broken') {
                                final pr = _promises[d.customerId];
                                if (pr != null) {
                                  await _resolvePromise(pr, status: v);
                                }
                              }
                              if (v == 'log') await _showCommLog(d);
                              if (v == 'statement') await _openStatement(d);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'call', child: Text(s.call)),
                              PopupMenuItem(value: 'sms', child: Text(s.sms)),
                              PopupMenuItem(
                                  value: 'copy', child: Text(s.copyMessage)),
                              PopupMenuItem(
                                  value: 'promise',
                                  child: Text(s.promiseToPay)),
                              if (_promises[d.customerId] != null) ...[
                                PopupMenuItem(
                                  value: 'kept',
                                  child: Text(
                                    localeController.isSwahili
                                        ? 'Ahadi imelipwa'
                                        : 'Promise kept',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'broken',
                                  child: Text(
                                    localeController.isSwahili
                                        ? 'Ahadi imevunjwa'
                                        : 'Promise broken',
                                  ),
                                ),
                              ],
                              PopupMenuItem(
                                  value: 'log', child: Text(s.contactLog)),
                              PopupMenuItem(
                                  value: 'statement',
                                  child: Text(s.statementRepay)),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _openStatement(d),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
