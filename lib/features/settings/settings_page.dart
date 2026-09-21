import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/business_profile_service.dart';
import '../../services/theme_service.dart';
import 'business_profile_page.dart';
import 'security_settings_page.dart';

/// Hub for profile, security, appearance — reachable from Home.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profiles = BusinessProfileService.instance;
  String _shopName = 'Mercate';
  String _profileLabel = '';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _profiles.getBusinessName();
    final profile = await _profiles.getProfile();
    final mode = await ThemeService().getThemeMode();
    if (!mounted) return;
    setState(() {
      _shopName = name;
      _profileLabel = profile.label;
      _themeMode = mode;
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await ThemeService().setThemeMode(mode);
    // Notify app-wide controller if present via Inherited — ThemeController in main listens meta; force reload
    try {
      // ThemeController is owned in main; settings write meta DB which load reads on next cold start.
      // Also try to poke ThemeController via root if registered.
    } catch (_) {}
    setState(() => _themeMode = mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == ThemeMode.light
              ? 'Light mode saved'
              : mode == ThemeMode.dark
                  ? 'Dark mode saved'
                  : 'System theme saved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GlassPanel(
            borderRadius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileLabel.isEmpty ? 'Shop profile' : _profileLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Business',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Shop profile'),
                  subtitle: const Text('Mama mboga, duka, mini-market…'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BusinessProfilePage(),
                      ),
                    );
                    _load();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('PIN & biometrics'),
                  subtitle: const Text('Lock sensitive actions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SecuritySettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          GlassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.phone_android)),
              ],
              selected: {_themeMode},
              onSelectionChanged: (s) => _setTheme(s.first),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mercate · offline POS',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
