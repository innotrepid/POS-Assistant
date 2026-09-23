import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/product_unit.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';

/// Manage selling units for one product (piece, kg, heap, gorogoro, …).
class ProductUnitsPage extends StatefulWidget {
  final Product product;

  const ProductUnitsPage({super.key, required this.product});

  @override
  State<ProductUnitsPage> createState() => _ProductUnitsPageState();
}

class _ProductUnitsPageState extends State<ProductUnitsPage> {
  final _inventory = InventoryService();
  final _profiles = BusinessProfileService.instance;

  List<ProductUnit> _units = [];
  List<String> _suggestions = const [];
  bool _loading = true;
  String? _error;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _inventory.ensureDefaultUnit(product.id);
      final units = await _inventory.getUnits(product.id);
      final profile = await _profiles.getProfile();
      final suggestions = profile.suggestedUnits.isEmpty
          ? <String>[profile.defaultUnit]
          : List<String>.from(profile.suggestedUnits);
      if (!mounted) return;
      setState(() {
        _units = units;
        _suggestions = suggestions;
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

  Future<void> _addOrEdit({ProductUnit? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.unitName ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null
          ? existing.sellingPrice.toStringAsFixed(2)
          : product.sellingPrice.toStringAsFixed(2),
    );
    final convCtrl = TextEditingController(
      text: existing != null
          ? _fmt(existing.conversionToBase)
          : '1',
    );
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    var isDefault = existing?.isDefault ?? false;

    final existingNames =
        _units.map((u) => u.unitName.toLowerCase()).toSet();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Add unit' : 'Edit unit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Base stock unit: ${product.unit}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (_suggestions.isNotEmpty) ...[
                      Text(
                        'Suggested',
                        style: Theme.of(ctx).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in _suggestions)
                            ActionChip(
                              label: Text(s),
                              onPressed: () {
                                nameCtrl.text = s;
                                setLocal(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit name',
                        hintText: 'piece, kg, heap, gorogoro…',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: convCtrl,
                      decoration: InputDecoration(
                        labelText: 'How many ${product.unit} in 1 of this unit',
                        helperText:
                            'e.g. 1 kg ≈ 10 ${product.unit} → enter 10',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Selling price (this unit)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: barcodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Barcode (optional)',
                        hintText: 'EAN / pack code for this unit',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Default unit'),
                      subtitle: const Text('Used when adding without a pick'),
                      value: isDefault,
                      onChanged: existing != null && existing.isDefault
                          ? null
                          : (v) => setLocal(() => isDefault = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    final name = nameCtrl.text.trim();
    final conv = double.tryParse(convCtrl.text.trim()) ?? 0;
    final price = Money.parse(priceCtrl.text);

    if (name.isEmpty) {
      _snack('Unit name is required');
      return;
    }
    if (conv <= 0) {
      _snack('Conversion must be greater than zero');
      return;
    }
    if (price < 0) {
      _snack('Price cannot be negative');
      return;
    }

    try {
      if (existing == null) {
        if (existingNames.contains(name.toLowerCase())) {
          _snack('Unit "$name" already exists');
          return;
        }
        await _inventory.addUnit(
          productId: product.id,
          unitName: name,
          conversionToBase: conv,
          sellingPrice: price,
          isDefault: isDefault,
          barcode: barcodeCtrl.text.trim().isEmpty
              ? null
              : barcodeCtrl.text.trim(),
        );
      } else {
        await _inventory.updateUnit(
          existing.copyWith(
            unitName: name,
            conversionToBase: conv,
            sellingPrice: price,
            isDefault: isDefault || existing.isDefault,
            barcode: barcodeCtrl.text.trim().isEmpty
                ? null
                : barcodeCtrl.text.trim(),
          ),
        );
      }
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _setDefault(ProductUnit unit) async {
    try {
      await _inventory.setDefaultUnit(unit.id);
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _delete(ProductUnit unit) async {
    if (unit.isDefault) {
      _snack('Set another unit as default before deleting this one');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete unit?'),
        content: Text('Remove "${unit.unitName}" from ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _inventory.deleteUnit(unit.id);
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${product.name} · units'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Stock is always counted in ${product.unit} (base). '
                          'Add selling units like piece, kg, or heap with a '
                          'conversion and price.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final u in _units)
                      Card(
                        child: ListTile(
                          title: Text(
                            u.unitName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (u.conversionToBase == 1)
                                'Base unit · ${Money.format(u.sellingPrice)}'
                              else
                                '1 ${u.unitName} = ${_fmt(u.conversionToBase)} ${product.unit} · ${Money.format(u.sellingPrice)}',
                              if (u.barcode != null && u.barcode!.isNotEmpty)
                                'code ${u.barcode}',
                            ].join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (u.isDefault)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text('Default'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                              else
                                IconButton(
                                  tooltip: 'Make default',
                                  icon: const Icon(Icons.star_outline),
                                  onPressed: () => _setDefault(u),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _addOrEdit(existing: u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: u.isDefault ? null : () => _delete(u),
                              ),
                            ],
                          ),
                          onTap: () => _addOrEdit(existing: u),
                        ),
                      ),
                  ],
                ),
    );
  }
}
