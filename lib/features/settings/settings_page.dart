import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/business_profile_service.dart';
import '../../services/locale_service.dart';
import '../../services/theme_service.dart';
import 'backup_settings_page.dart';
import 'business_profile_page.dart';
import 'security_settings_page.dart';
import 'license_settings_page.dart';

/// Hub for profile, security, backup, appearance, language.
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
  String _lang = 'en';

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
      _lang = localeController.code;
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await themeController.setMode(mode);
    setState(() => _themeMode = mode);
    if (!mounted) return;
    final s = localeController.s;
    final label = mode == ThemeMode.light
        ? s.themeLight
        : mode == ThemeMode.dark
            ? s.themeDark
            : s.themeSystem;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label · ${s.save}')),
    );
  }

  Future<void> _setLanguage(String code) async {
    await localeController.setLanguageCode(code);
    setState(() => _lang = localeController.code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          code == 'sw' ? 'Lugha: Kiswahili' : 'Language: English',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = localeController.s;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(s.settings)),
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
                  _profileLabel.isEmpty ? s.businessProfile : _profileLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(s.businessProfile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BusinessProfilePage(),
                      ),
                    )
                        .then((_) => _load());
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Mercate licence'),
                  subtitle: const Text('Activate, check status or renew'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LicenseSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(s.security),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SecuritySettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(s.backup),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BackupSettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.language,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            s.languageHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          GlassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'en',
                  label: Text(s.languageEnglish),
                  icon: const Icon(Icons.language),
                ),
                ButtonSegment(
                  value: 'sw',
                  label: Text(s.languageSwahili),
                  icon: const Icon(Icons.translate),
                ),
              ],
              selected: {_lang},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) _setLanguage(set.first);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.appearance,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          GlassPanel(
            borderRadius: 16,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(s.themeLight),
                  icon: const Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(s.themeDark),
                  icon: const Icon(Icons.dark_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(s.themeSystem),
                  icon: const Icon(Icons.phone_android),
                ),
              ],
              selected: {_themeMode},
              onSelectionChanged: (sel) => _setTheme(sel.first),
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
