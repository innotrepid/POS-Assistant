import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/mercate_license.dart';
import '../../core/theme/app_theme.dart';
import '../../services/business_profile_service.dart';
import '../../services/license_service.dart';

class LicenseSettingsPage extends StatefulWidget {
  const LicenseSettingsPage({super.key});

  @override
  State<LicenseSettingsPage> createState() => _LicenseSettingsPageState();
}

class _LicenseSettingsPageState extends State<LicenseSettingsPage> {
  final _licenseService = LicenseService.instance;
  final _profiles = BusinessProfileService.instance;
  final _tokenController = TextEditingController();
  LicenseEvaluation? _evaluation;
  String? _businessId;
  bool _loading = true;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final businessId = await _profiles.ensureBusinessId();
      final evaluation = await _licenseService.evaluate();
      if (!mounted) return;
      setState(() {
        _businessId = businessId;
        _evaluation = evaluation;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _evaluation = LicenseEvaluation(
          state: LicenseState.invalid,
          message: error.toString(),
        );
        _loading = false;
      });
    }
  }

  Future<void> _copyBusinessId() async {
    final id = _businessId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business ID copied')),
    );
  }

  Future<void> _activate() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _message('Paste the licence code first.');
      return;
    }
    setState(() => _activating = true);
    try {
      await _licenseService.activate(token);
      _tokenController.clear();
      await _refresh();
      if (!mounted) return;
      _message('Licence code verified and saved on this business.');
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _stateLabel(LicenseState state) {
    switch (state) {
      case LicenseState.unactivated:
        return 'Not activated';
      case LicenseState.notYetValid:
        return 'Not yet valid';
      case LicenseState.active:
        return 'Active';
      case LicenseState.gracePeriod:
        return 'Grace period';
      case LicenseState.expired:
        return 'Expired';
      case LicenseState.invalid:
        return 'Invalid code';
      case LicenseState.clockRollback:
        return 'Device clock warning';
    }
  }

  Color _stateColor(BuildContext context, LicenseState state) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case LicenseState.active:
        return scheme.primary;
      case LicenseState.gracePeriod:
        return Colors.orange.shade800;
      case LicenseState.unactivated:
      case LicenseState.notYetValid:
      case LicenseState.expired:
      case LicenseState.invalid:
      case LicenseState.clockRollback:
        return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = _evaluation;
    final license = evaluation?.license;
    final state = evaluation?.state ?? LicenseState.unactivated;
    final color = _stateColor(context, state);

    return Scaffold(
      appBar: AppBar(title: const Text('Mercate licence')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassPanel(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: color, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _stateLabel(state),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh status',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (evaluation?.message != null) ...[
                        const SizedBox(height: 8),
                        Text(evaluation!.message!),
                      ],
                      if (license != null) ...[
                        const Divider(height: 24),
                        _detail('Licence ID', license.licenseId),
                        _detail('Valid until', _date(license.expiresAt)),
                        _detail('Grace period', '${license.graceDays} days'),
                        _detail(
                          'Device allowance',
                          license.maxDevices == null
                              ? 'Set by your licence issuer'
                              : '${license.maxDevices} device limit (enrolment is a separate step)',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Business identity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                GlassPanel(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send this ID to your Mercate licence issuer. The code they generate must match this business.',
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _businessId ?? 'Unavailable',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _businessId == null ? null : _copyBusinessId,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy business ID'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  license == null ? 'Activate this business' : 'Renew or replace licence',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                GlassPanel(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Paste the signed code supplied by your Mercate licence issuer. Activation works offline after the code has been issued.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tokenController,
                        minLines: 3,
                        maxLines: 6,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Licence code',
                          hintText: 'Paste licence code here',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _activating ? null : _activate,
                        icon: _activating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.key),
                        label: Text(_activating ? 'Verifying…' : 'Verify and activate'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your business records are stored separately from this licence. Entering a renewal replaces the previous code; it does not delete or alter sales, stock, customers or backups. Device limits are carried by the signed code; multi-device enrolment and enforcement will be enabled in a later phase.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
