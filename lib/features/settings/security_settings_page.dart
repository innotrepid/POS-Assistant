import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart' show themeController;
import '../../services/policy_service.dart';
import '../../services/security_service.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _security = SecurityService();
  final _policies = PolicyService();

  bool _loading = true;
  bool _lockEnabled = false;
  bool _hasPin = false;
  bool _bioPreferred = true;
  bool _bioAvailable = false;
  bool _allowNegativeStock = false;
  bool _requireUnitPick = false;
  double _largeDiscountPct = 20;
  int _overdueDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lock = await _security.isLockEnabled();
    final pin = await _security.hasPin();
    final bioPref = await _security.isBiometricPreferred();
    final bioAvail = await _security.canCheckBiometrics();
    final neg = await _policies.getAllowNegativeStock();
    final requirePick = await _policies.getRequireUnitPick();
    final disc = await _policies.getLargeDiscountPercent();
    final overdue = await _policies.getOverdueDebtDays();
    if (!mounted) return;
    setState(() {
      _lockEnabled = lock;
      _hasPin = pin;
      _bioPreferred = bioPref;
      _bioAvailable = bioAvail;
      _allowNegativeStock = neg;
      _requireUnitPick = requirePick;
      _largeDiscountPct = disc;
      _overdueDays = overdue;
      _loading = false;
    });
  }

  Future<void> _setPin() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN (min 4 digits)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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

    if (ok != true) return;

    try {
      if (pinCtrl.text != confirmCtrl.text) {
        throw ArgumentError('PINs do not match.');
      }
      await _security.setPin(pinCtrl.text);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const ListTile(
                  title: Text('Appearance'),
                  subtitle: Text('Glass UI · teal accent'),
                ),
                ListenableBuilder(
                  listenable: themeController,
                  builder: (context, _) {
                    final mode = themeController.mode;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto, size: 18),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode, size: 18),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode, size: 18),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (set) {
                          themeController.setMode(set.first);
                        },
                      ),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: themeController,
                  builder: (context, _) {
                    return ListTile(
                      title: const Text('Theme'),
                      subtitle: Text(_themeLabel(themeController.mode)),
                      trailing: Icon(
                        themeController.mode == ThemeMode.dark
                            ? Icons.dark_mode
                            : themeController.mode == ThemeMode.light
                                ? Icons.light_mode
                                : Icons.brightness_auto,
                      ),
                    );
                  },
                ),
                const Divider(),
                const ListTile(
                  title: Text('App lock'),
                  subtitle: Text(
                    'PIN and biometrics protect the app and sensitive actions '
                    '(day close, shop profile, void).',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Require unlock'),
                  subtitle: Text(
                    _hasPin ? 'Lock screen on open' : 'Set a PIN first',
                  ),
                  value: _lockEnabled,
                  onChanged: !_hasPin
                      ? null
                      : (v) async {
                          try {
                            await _security.setLockEnabled(v);
                            await _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                ),
                ListTile(
                  title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
                  trailing: const Icon(Icons.pin),
                  onTap: _setPin,
                ),
                SwitchListTile(
                  title: const Text('Prefer biometrics'),
                  subtitle: Text(
                    _bioAvailable
                        ? 'Fingerprint / face when available'
                        : 'No biometrics on this device',
                  ),
                  value: _bioPreferred && _bioAvailable,
                  onChanged: !_bioAvailable
                      ? null
                      : (v) async {
                          await _security.setBiometricPreferred(v);
                          await _load();
                        },
                ),
                const Divider(),
                const ListTile(
                  title: Text('Sales & debt policies'),
                  subtitle: Text('Safety thresholds'),
                ),
                SwitchListTile(
                  title: const Text('Allow negative stock'),
                  subtitle: const Text(
                    'If off, sales cannot exceed recorded stock',
                  ),
                  value: _allowNegativeStock,
                  onChanged: (v) async {
                    await _policies.setAllowNegativeStock(v);
                    await _load();
                  },
                ),
                SwitchListTile(
                  title: const Text('Always pick unit at POS'),
                  subtitle: const Text(
                    'Show unit chooser even when a product has only one unit',
                  ),
                  value: _requireUnitPick,
                  onChanged: (v) async {
                    await _policies.setRequireUnitPick(v);
                    await _load();
                  },
                ),
                ListTile(
                  title: const Text('Large discount warning'),
                  subtitle: Text(
                    'Warn at ${_largeDiscountPct.toStringAsFixed(0)}% or more',
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _largeDiscountPct.toStringAsFixed(0),
                      ),
                      onSubmitted: (v) async {
                        final n = double.tryParse(v) ?? 20;
                        await _policies.setLargeDiscountPercent(n);
                        await _load();
                      },
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Overdue debt after'),
                  subtitle: Text(
                    '$_overdueDays days from oldest unpaid credit sale',
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(
                        suffixText: 'days',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: '$_overdueDays',
                      ),
                      onSubmitted: (v) async {
                        final n = int.tryParse(v) ?? 30;
                        await _policies.setOverdueDebtDays(n);
                        await _load();
                      },
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('View licenses'),
                  subtitle: const Text('Open-source software notices'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Mercate',
                      applicationVersion: '0.1.0',
                    );
                  },
                ),
              ],
            ),
    );
  }
}
