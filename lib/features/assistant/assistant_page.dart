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
          'Hi — I am your Mercate business partner (offline).\n'
          'Ask how you did today, who is overdue, best sellers, '
          'or what is not moving. I can offer Call / SMS — you always confirm.',
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
    final phone = action.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on this contact')),
      );
      return;
    }

    if (action.kind == AssistantActionKind.call) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open phone dialer?'),
          content: Text(
            'Mercate will open the dialer for ${action.customerName ?? phone}.\n'
            'Number: $phone\n\n'
            'The call is not placed until you press Call in the dialer.',
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
      final uri = Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer')),
        );
      }
      return;
    }

    // SMS — show body, then open composer
    final body = action.smsBody ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open SMS?'),
        content: SingleChildScrollView(
          child: Text(
            'To: ${action.customerName ?? phone}\n'
            'Number: $phone\n\n'
            'Message:\n$body\n\n'
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
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: body.isEmpty ? null : {'body': body},
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messages')),
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
                                  onPressed: () => _runAction(a),
                                  icon: Icon(
                                    a.kind == AssistantActionKind.call
                                        ? Icons.call
                                        : Icons.sms_outlined,
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
                        hintText: 'Ask about sales, debt, stock…',
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
