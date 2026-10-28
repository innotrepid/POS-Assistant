import 'package:flutter/material.dart';

import '../../core/models/business_profile.dart';
import '../../services/business_profile_service.dart';
import '../../services/security_service.dart';
import '../assistant/assistant_page.dart';
import '../security/lock_screen.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key});

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _service = BusinessProfileService.instance;
  final _security = SecurityService();
  final _nameCtrl = TextEditingController();
  BusinessProfile? _current;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _service.getProfile();
      final name = await _service.getBusinessName();
      if (!mounted) return;
      setState(() {
        _current = profile;
        _nameCtrl.text = name;
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

  Future<void> _saveName() async {
    try {
      await _service.setBusinessName(_nameCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _select(BusinessProfile profile) async {
    if (!profile.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${profile.label} is not available yet. '
            'We are finishing Mama mboga first.',
          ),
        ),
      );
      return;
    }
    if (_current?.id == profile.id) return;

    final unlocked = await _security.requireUnlock(
      biometricReason: 'Confirm profile change',
      promptPin: () => promptPinDialog(context, title: 'PIN to change profile'),
    );
    if (!unlocked || !mounted) return;

    try {
      await _service.setProfile(profile.id);
      setState(() => _current = profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using ${profile.label}.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop profile'),
        actions: [
          IconButton(
            tooltip: 'Ask assistant about profiles',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AssistantPage(
                    initialQuestion: 'Explain business profiles',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shop name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saveName,
                        child: const Text('Save name'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Business type',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Right now only Mama mboga is available. '
                      'Other shop types will unlock later. '
                      'Each profile keeps its own stock and sales.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final p in BusinessProfile.all)
                      ListTile(
                        title: Text(
                          p.label,
                          style: TextStyle(
                            color: p.enabled
                                ? null
                                : scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        subtitle: Text(
                          p.enabled
                              ? 'Available · units ${p.suggestedUnits.take(4).join(', ')}…'
                              : 'Unavailable — coming later',
                        ),
                        enabled: p.enabled,
                        selected: _current?.id == p.id,
                        trailing: _current?.id == p.id
                            ? Icon(Icons.check_circle, color: scheme.primary)
                            : (p.enabled
                                ? null
                                : Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  )),
                        onTap: p.enabled ? () => _select(p) : () => _select(p),
                      ),
                  ],
                ),
    );
  }
}
