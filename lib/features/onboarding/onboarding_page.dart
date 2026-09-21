import 'package:flutter/material.dart';

import '../../core/models/business_profile.dart';
import '../../core/theme/app_theme.dart';
import '../../services/business_profile_service.dart';

/// First launch: must pick a profile and shop name before using the app.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingPage({super.key, required this.onCompleted});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameCtrl = TextEditingController();
  final _service = BusinessProfileService.instance;
  BusinessProfileId? _selected;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_selected == null) {
      setState(() => _error = 'Choose the type of shop you run.');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your shop name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.completeOnboarding(
        profileId: _selected!,
        shopName: _nameCtrl.text,
      );
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = BusinessProfile.all.where((p) => p.enabled).toList();

    return Scaffold(
      body: GlassScaffoldBody(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: Image.asset(
                  'assets/images/mercate_logo.png',
                  height: 72,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.storefront,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Welcome to Mercate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you sell. Each profile keeps its own stock, '
                'customers and sales — they do not mix.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  hintText: 'e.g. Mama Njeri vegetables',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              Text(
                'What kind of business?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              for (final p in enabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassPanel(
                    accent: _selected == p.id,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(
                        p.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: _selected == p.id,
                      trailing: _selected == p.id
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => setState(() => _selected = p.id),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _continue,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start using Mercate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
