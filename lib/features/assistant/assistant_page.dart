import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/assistant_service.dart';

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
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Hi — Mercate offline partner.\n'
          'Ask about sales or debt, or say "Record that John paid 500 cash" / '
          '"Add 10 of sugar" / "Mary promised Friday". '
          'Writes only happen after you Confirm.',
      fromUser: false,
    ),
  ];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _runAction(AssistantAction action) async {
    if (action.kind == AssistantActionKind.cancelWrite) {
      setState(() {
        _messages.add(
          const _ChatMessage(text: 'Cancelled — nothing was saved.', fromUser: false),
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
        const SnackBar(content: Text('No phone number')),
      );
      return;
    }

    if (action.kind == AssistantActionKind.call) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open phone dialer?'),
          content: Text(
            'Open dialer for ${action.customerName ?? phone}\n$phone\n\n'
            'Call is not placed until you press Call in the dialer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open dialer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await launchUrl(Uri(scheme: 'tel', path: phone));
      if (action.customerId != null) {
        await _assistant.logCallOrSmsResult(
          customerId: action.customerId!,
          customerName: action.customerName ?? phone,
          channel: 'call',
          result: 'dialer_opened',
        );
      }
      return;
    }

    final body = action.smsBody ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open SMS?'),
        content: SingleChildScrollView(
          child: Text(
            'To: ${action.customerName ?? phone}\n$phone\n\n$body\n\n'
            'Nothing is sent until you press Send in Messages.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Messages'),
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
    if (action.customerId != null) {
      await _assistant.logCallOrSmsResult(
        customerId: action.customerId!,
        customerName: action.customerName ?? phone,
        channel: 'sms',
        result: 'composer_opened',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercate Assistant'),
        actions: [
          IconButton(
            tooltip: 'Daily brief',
            icon: const Icon(Icons.today_outlined),
            onPressed: () => _send('How did I do today?'),
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
                                  onPressed: _busy ? null : () => _runAction(a),
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
                      decoration: const InputDecoration(
                        hintText: 'Ask or record a payment…',
                        border: OutlineInputBorder(),
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
