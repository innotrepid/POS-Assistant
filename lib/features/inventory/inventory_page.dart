import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';
import '../../services/starter_catalogue_service.dart';
import '../suppliers/receive_purchase_page.dart';

class InventoryPage extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;

  const InventoryPage({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _inventory = InventoryService();
  final _profiles = BusinessProfileService.instance;
  final _starter = StarterCatalogueService();

  List<Product> _products = [];
  Map<String, double> _stock = {};
  bool _loading = true;
  bool _suppliersEnabled = false;
  String? _error;

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
      final profile = await _profiles.getProfile();
      final products = await _inventory.getAllProducts();
      final stock = <String, double>{};
      for (final p in products) {
        stock[p.id] = await _inventory.getStock(p.id);
      }
      if (!mounted) return;
      setState(() {
        _suppliersEnabled = profile.features.suppliers;
        _products = products;
        _stock = stock;
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

  List<String> _unitsFor(dynamic profile, {String? current}) {
    final units = profile.suggestedUnits.isEmpty
        ? <String>[profile.defaultUnit as String]
        : List<String>.from(profile.suggestedUnits as List);
    for (final extra in ['debe', 'gorogoro', 'kg', 'bunch', 'piece', 'head', 'pack', 'tray']) {
      if (!units.contains(extra)) units.add(extra);
    }
    if (current != null && current.isNotEmpty && !units.contains(current)) {
      units.insert(0, current);
    }
    return units;
  }

  Future<void> _editProduct(Product product) async {
    final profile = await _profiles.getProfile();
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.sellingPrice.toString());
    final costCtrl = TextEditingController(text: product.costPrice?.toString() ?? '');
    final units = _unitsFor(profile, current: product.unit);
    var selectedUnit = product.unit;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Edit product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Selling price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      decoration: const InputDecoration(labelText: 'Cost (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    Text('Unit (kg, debe/gorogoro, bunch…)', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final u in units)
                          ChoiceChip(
                            label: Text(u),
                            selected: selectedUnit == u,
                            onSelected: (_) => setLocal(() => selectedUnit = u),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await _inventory.updateProduct(product.copyWith(
        name: nameCtrl.text.trim(),
        sellingPrice: Money.parse(priceCtrl.text),
        costPrice: costCtrl.text.trim().isEmpty ? null : Money.parse(costCtrl.text),
        unit: selectedUnit,
        updatedAt: DateTime.now(),
      ));
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _seedStarter() async {
    try {
      final n = await _starter.seedIfEmpty();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'All starter items are already in stock (no duplicates added).'
                : 'Added $n new starter products. Existing names were skipped.',
          ),
        ),
      );
      if (n > 0) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _spoilage(Product product) async {
    final qtyCtrl = TextEditingController();
    var reason = kSpoilageReasons.first;
    final otherCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Spoilage · ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: qtyCtrl,
                  decoration: InputDecoration(labelText: 'Quantity (${product.unit})'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Text('Reason', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in kSpoilageReasons)
                      ChoiceChip(
                        label: Text(r),
                        selected: reason == r,
                        onSelected: (_) => setLocal(() => reason = r),
                      ),
                  ],
                ),
                if (reason == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(controller: otherCtrl, decoration: const InputDecoration(labelText: 'Describe')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final why = reason == 'Other' ? otherCtrl.text.trim() : reason;
      await _inventory.recordSpoilage(
        productId: product.id,
        quantity: Money.parse(qtyCtrl.text),
        reason: why.isEmpty ? 'Other' : why,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Spoilage recorded for ${product.name}')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openReceiveGoods() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReceivePurchasePage()));
    _load();
  }

  Future<void> _showAddProduct() async {
    final profile = await _profiles.getProfile();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final units = _unitsFor(profile);
    var selectedUnit = profile.defaultUnit;
    if (!units.contains(selectedUnit)) selectedUnit = units.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Selling price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      decoration: const InputDecoration(labelText: 'Cost (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    Text('Unit', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final u in units)
                          ChoiceChip(
                            label: Text(u),
                            selected: selectedUnit == u,
                            onSelected: (_) => setLocal(() => selectedUnit = u),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Opening quantity (optional)',
                        helperText: 'e.g. 2 $selectedUnit',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      final product = await _inventory.createProduct(
        name: nameCtrl.text.trim(),
        sellingPrice: Money.parse(priceCtrl.text),
        costPrice: costCtrl.text.trim().isEmpty ? null : Money.parse(costCtrl.text),
        unit: selectedUnit,
      );
      final opening = Money.parse(qtyCtrl.text);
      if (opening > 0) {
        await _inventory.addStock(
          productId: product.id,
          quantity: opening,
          unitCost: costCtrl.text.trim().isEmpty ? null : Money.parse(costCtrl.text),
          movementType: 'opening_stock',
          reason: 'Opening stock on product create',
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _manualAddStock(Product product) async {
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(text: product.costPrice?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bought today · ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: InputDecoration(labelText: 'Quantity (${product.unit})'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              decoration: const InputDecoration(labelText: 'Unit cost (optional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _inventory.restockBoughtToday(
        productId: product.id,
        quantity: Money.parse(qtyController.text),
        unitCost: costController.text.trim().isEmpty ? null : Money.parse(costController.text),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addStockFlow(Product product) async {
    if (!_suppliersEnabled) {
      await _manualAddStock(product);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add stock · ${product.name}'),
        content: const Text('How did the stock arrive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'manual'), child: const Text('Bought today')),
          FilledButton(onPressed: () => Navigator.pop(context, 'supplier'), child: const Text('From supplier')),
        ],
      ),
    );
    if (choice == 'supplier') {
      await _openReceiveGoods();
      return;
    }
    if (choice == 'manual') await _manualAddStock(product);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          if (_suppliersEnabled)
            IconButton(
              tooltip: 'Receive goods',
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: _openReceiveGoods,
            ),
          if (widget.onOpenNotifications != null)
            IconButton(
              onPressed: widget.onOpenNotifications,
              icon: Badge(
                isLabelVisible: widget.unreadCount > 0,
                label: Text('${widget.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          IconButton(
            tooltip: 'Add any missing starter items',
            icon: const Icon(Icons.playlist_add),
            onPressed: _seedStarter,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: _showAddProduct,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No products yet. Tap Add item, or load a starter list for mama mboga.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _seedStarter,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Load starter catalogue'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 160),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _products[index];
                        final qty = _stock[p.id] ?? 0;
                        final low = p.minimumStock > 0 && qty <= p.minimumStock;
                        return ListTile(
                          onTap: () => _editProduct(p),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${Money.format(p.sellingPrice)} · $qty ${p.unit}${low ? ' · LOW' : ''}',
                            style: TextStyle(color: low ? scheme.error : null),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_box_outlined),
                                tooltip: 'Bought today',
                                onPressed: () => _addStockFlow(p),
                              ),
                              if (qty > 0)
                                IconButton(
                                  icon: Icon(Icons.eco_outlined, color: scheme.error),
                                  tooltip: 'Spoilage',
                                  onPressed: () => _spoilage(p),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
