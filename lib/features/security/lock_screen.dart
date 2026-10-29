import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/security_service.dart';

/// Full-screen gate when app lock is enabled.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _security = SecurityService();
  final _pinCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _bioTried = false;

  @override
  void initState() {
    super.initState();
    _tryBio();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBio() async {
    if (_bioTried) return;
    _bioTried = true;
    try {
      final ok = await _security.tryBiometricUnlock();
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Biometric failed — enter PIN');
      }
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _security.unlockWithPin(_pinCtrl.text);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() {
          _busy = false;
          _error = 'Incorrect PIN';
          _pinCtrl.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
        _pinCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mercate is locked',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your PIN to continue',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 12,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _submitPin(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submitPin,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock with PIN'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _tryBio,
                    child: const Text('Use fingerprint / face'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prompt for PIN (and optional biometric) from settings / sensitive actions.
Future<bool> promptUnlock(
  BuildContext context, {
  String title = 'Enter PIN',
  required SecurityService security,
}) async {
  final ctrl = TextEditingController();
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                  onSubmitted: (_) async {
                    try {
                      final ok = await security.verifyPin(ctrl.text);
                      if (ok) {
                        if (context.mounted) Navigator.pop(context, true);
                      } else {
                        setLocal(() => error = 'Incorrect PIN');
                      }
                    } catch (e) {
                      setLocal(() => error = e.toString());
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    final ok = await security.verifyPin(ctrl.text);
                    if (ok) {
                      if (context.mounted) Navigator.pop(context, true);
                    } else {
                      setLocal(() => error = 'Incorrect PIN');
                    }
                  } catch (e) {
                    setLocal(() => error = e.toString());
                  }
                },
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      );
    },
  );
  return result == true;
}
