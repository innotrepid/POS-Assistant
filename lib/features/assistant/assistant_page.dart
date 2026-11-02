import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/assistant_service.dart';
import '../../services/collection_service.dart';
import '../../services/locale_service.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  final List<AssistantAction> actions;

  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.actions = const [],
  });
}

class AssistantPage extends StatefulWidget {
  final String? initialQuestion;

  const AssistantPage({super.key, this.initialQuestion});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _assistant = AssistantService();
  final _collection = CollectionService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _busy = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    if (!_seeded) {
      _seeded = true;
      final welcome = localeController.isSwahili
          ? 'Habari — mshirika wa Mercate bila mtandao.\n'
              'Uliza kuhusu mauzo au deni. Mabadiliko yataandikwa baada ya kuthibitisha.'
          : 'Hi — Mercate offline partner.\n'
              'Ask about sales or debt. Writes only happen after you Confirm.';
      _messages.add(_ChatMessage(text: welcome, fromUser: false));
    }
    final q = widget.initialQuestion;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _busy) return;

    setState(() {
      _messages.add(_ChatMessage(text: q, fromUser: true));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final reply = await _assistant.ask(q);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: reply.text,
            fromUser: false,
            actions: reply.actions,
          ),
        );
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: 'Something went wrong: $e', fromUser: false),
        );
        _busy = false;
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  DateTime _nextWeekday(int weekday) {
    var d = DateTime.now();
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != weekday);
    return d;
  }

  String _labelResult(String code) {
    final s = localeController.s;
    return switch (code) {
      'no_answer' => s.outcomeNoAnswer,
      'spoke' => s.outcomeSpoke,
      'busy' => s.outcomeBusy,
      'wrong_number' => s.outcomeWrongNumber,
      'promised_tomorrow' => s.outcomePromisedTomorrow,
      'promised_friday' => s.outcomePromisedFriday,
      'will_pay_later' => s.outcomeWillPayLater,
      'paid_partial' => s.outcomePaidPartial,
      _ => code,
    };
  }

  Future<void> _promptContactResult({
    required String channel,
    required String? customerId,
    required String customerName,
  }) async {
    if (customerId == null || !mounted) return;
    final loc = localeController.s;
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
                  '${loc.howDidItGo} $customerName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in [
                      ('no_answer', loc.outcomeNoAnswer),
                      ('spoke', loc.outcomeSpoke),
                      ('busy', loc.outcomeBusy),
                      ('wrong_number', loc.outcomeWrongNumber),
                      ('promised_tomorrow', loc.outcomePromisedTomorrow),
                      ('promised_friday', loc.outcomePromisedFriday),
                      ('will_pay_later', loc.outcomeWillPayLater),
                      ('paid_partial', loc.outcomePaidPartial),
                      ('skip', loc.skipLog),
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
      partyId: customerId,
      partyName: customerName,
      channel: channel,
      result: result,
    );

    if (result == 'promised_tomorrow' || result == 'promised_friday') {
      final when = result == 'promised_tomorrow'
          ? DateTime.now().add(const Duration(days: 1))
          : _nextWeekday(DateTime.friday);
      await _collection.recordPromise(
        customerId: customerId,
        promisedDate: when,
        notes: 'From Assistant $channel',
      );
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: 'Logged ${_labelResult(result)} for $customerName.',
          fromUser: false,
        ),
      );
    });
    _scrollToEnd();
  }

  Future<void> _runAction(AssistantAction action) async {
    final loc = localeController.s;
    if (action.kind == AssistantActionKind.cancelWrite) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: localeController.isSwahili
                ? 'Imeghairiwa — hakuna kilichohifadhiwa.'
                : 'Cancelled — nothing was saved.',
            fromUser: false,
          ),
        );
      });
      _scrollToEnd();
      return;
    }

    if (action.kind == AssistantActionKind.confirmWrite) {
      final kind = action.writeKind;
      final payload = action.writePayload;
      if (kind == null || payload == null) return;
      setState(() => _busy = true);
      try {
        final result = await _assistant.executeWrite(kind, payload);
        if (!mounted) return;
        setState(() {
          _messages.add(_ChatMessage(text: result, fromUser: false));
          _busy = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _messages.add(
            _ChatMessage(text: 'Could not save: $e', fromUser: false),
          );
          _busy = false;
        });
      }
      _scrollToEnd();
      return;
    }

    final phone = action.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.noPhoneNumber)),
      );
      return;
    }

    if (action.kind == AssistantActionKind.call) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.openDialer),
          content: Text(
            '${action.customerName ?? phone}\n$phone\n\n${loc.callNotUntilDialer}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.openDialer),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await launchUrl(Uri(scheme: 'tel', path: phone));
      await _promptContactResult(
        channel: 'call',
        customerId: action.customerId,
        customerName: action.customerName ?? phone,
      );
      return;
    }

    final body = action.smsBody ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.openSms),
        content: SingleChildScrollView(
          child: Text(
            '${action.customerName ?? phone}\n$phone\n\n$body\n\n${loc.smsNotUntilSend}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.openMessages),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await launchUrl(
      Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: body.isEmpty ? null : {'body': body},
      ),
    );
    await _promptContactResult(
      channel: 'sms',
      customerId: action.customerId,
      customerName: action.customerName ?? phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = localeController.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.mercateAssistant),
        actions: [
          IconButton(
            tooltip: loc.dailyBrief,
            icon: const Icon(Icons.today_outlined),
            onPressed: () => _send(
              localeController.isSwahili
                  ? 'Nimefanyaje leo?'
                  : 'How did I do today?',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final s in AssistantService.suggestions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: _busy ? null : () => _send(s),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final align =
                    m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
                final color = m.fromUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest;
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(m.text),
                        if (m.actions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final a in m.actions)
                                FilledButton.tonalIcon(
                                  onPressed:
                                      _busy ? null : () => _runAction(a),
                                  icon: Icon(
                                    a.kind == AssistantActionKind.call
                                        ? Icons.call
                                        : a.kind == AssistantActionKind.sms
                                            ? Icons.sms_outlined
                                            : a.kind ==
                                                    AssistantActionKind
                                                        .confirmWrite
                                                ? Icons.check
                                                : Icons.close,
                                    size: 18,
                                  ),
                                  label: Text(a.label),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: loc.askOrRecordPayment,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(_controller.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
