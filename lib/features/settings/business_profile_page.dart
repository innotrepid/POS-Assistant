import 'package:flutter/material.dart';

import '../../core/models/business_profile.dart';
import '../../services/business_profile_service.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key});

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _service = BusinessProfileService();
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
        SnackBar(content: Text('${profile.label} coming later')),
      );
      return;
    }
    try {
      await _service.setProfile(profile.id);
      setState(() => _current = profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${profile.label} · ${profile.interfaceLevel.name} interface. '
            'New products default to ${profile.defaultUnit}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _levelLabel(InterfaceLevel level) {
    switch (level) {
      case InterfaceLevel.simple:
        return 'Simple';
      case InterfaceLevel.simplePlus:
        return 'Simple+';
      case InterfaceLevel.operational:
        return 'Operational';
      case InterfaceLevel.operationalPlus:
        return 'Operational+';
      case InterfaceLevel.controlled:
        return 'Controlled';
      case InterfaceLevel.advanced:
        return 'Advanced';
      case InterfaceLevel.management:
        return 'Management';
      case InterfaceLevel.full:
        return 'Full';
    }
  }

  String _featureSummary(ProfileFeatures f) {
    final parts = <String>[];
    if (f.sales) parts.add('sales');
    if (f.stock) parts.add('stock');
    if (f.customers) parts.add('customers');
    if (f.suppliers) parts.add('suppliers');
    if (f.reports) parts.add('reports');
    if (f.barcodes) parts.add('barcode');
    if (f.batchesExpiry) parts.add('batch/expiry');
    if (f.weightSales) parts.add('weight');
    if (f.splitPayments) parts.add('split pay');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop profile')),
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
                    const Divider(height: 32),
                    Text(
                      'Business type',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profiles focus the interface — not a weaker app. '
                      'The same sales, stock, and debt engine runs underneath.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    for (final p in BusinessProfile.all)
                      Card(
                        child: ListTile(
                          title: Text(p.label),
                          subtitle: Text(
                            '${_levelLabel(p.interfaceLevel)} · '
                            '${_featureSummary(p.features)}\n'
                            '${p.description}'
                            '${p.enabled ? '' : '\n(Coming later)'}',
                          ),
                          isThreeLine: true,
                          enabled: p.enabled,
                          selected: _current?.id == p.id,
                          trailing: _current?.id == p.id
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: p.enabled ? () => _select(p) : null,
                        ),
                      ),
                  ],
                ),
    );
  }
}
