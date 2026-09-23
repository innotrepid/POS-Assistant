import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/product_unit.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';
import '../suppliers/receive_purchase_page.dart';
import 'product_units_page.dart';

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

  List<Product> _products = [];
  Map<String, double> _stock = {};
  Map<String, List<ProductUnit>> _unitsByProduct = {};
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
      final unitsMap = <String, List<ProductUnit>>{};
      for (final p in products) {
        stock[p.id] = await _inventory.getStock(p.id);
        try {
          unitsMap[p.id] = await _inventory.getUnits(p.id);
        } catch (_) {
          unitsMap[p.id] = [];
        }
      }
      if (!mounted) return;
      setState(() {
        _suppliersEnabled = profile.features.suppliers;
        _products = products;
        _stock = stock;
        _unitsByProduct = unitsMap;
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

  Future<void> _openProductUnits(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductUnitsPage(product: product),
      ),
    );
    _load();
  }

  Future<void> _openReceiveGoods() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReceivePurchasePage(),
      ),
    );
    _load();
  }

  Future<void> _showAddProduct() async {
    final profile = await _profiles.getProfile();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final units = profile.suggestedUnits.isEmpty
        ? <String>[profile.defaultUnit]
        : List<String>.from(profile.suggestedUnits);
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
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Selling price'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Cost (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                            onSelected: (_) =>
                                setLocal(() => selectedUnit = u),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Opening quantity (optional)',
                        helperText: 'e.g. 30 $selectedUnit',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
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
      },
    );
    if (ok != true || !mounted) return;
    try {
      final product = await _inventory.createProduct(
        name: nameCtrl.text.trim(),
        sellingPrice: Money.parse(priceCtrl.text),
        costPrice:
            costCtrl.text.trim().isEmpty ? null : Money.parse(costCtrl.text),
        unit: selectedUnit,
      );
      final opening = Money.parse(qtyCtrl.text);
      if (opening > 0) {
        await _inventory.addStock(
          productId: product.id,
          quantity: opening,
          unitCost: costCtrl.text.trim().isEmpty
              ? null
              : Money.parse(costCtrl.text),
          movementType: 'opening_stock',
          reason: 'Opening stock on product create',
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _manualAddStock(Product product) async {
    var units = await _inventory.getUnits(product.id);
    if (units.isEmpty) {
      await _inventory.ensureDefaultUnit(product.id);
      units = await _inventory.getUnits(product.id);
    }
    ProductUnit? selected = units.isEmpty
        ? null
        : units.firstWhere((u) => u.isDefault, orElse: () => units.first);

    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(
      text: product.costPrice != null ? product.costPrice!.toString() : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Add stock · ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (units.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final u in units)
                          ChoiceChip(
                            label: Text(u.unitName),
                            selected: selected?.id == u.id,
                            onSelected: (_) => setLocal(() => selected = u),
                          ),
                      ],
                    ),
                  if (selected != null && selected!.conversionToBase != 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Text(
                        '1 ${selected!.unitName} = ${_fmtQty(selected!.conversionToBase)} ${product.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  TextField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      labelText: selected == null
                          ? 'Quantity'
                          : 'Quantity (${selected!.unitName})',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costController,
                    decoration: InputDecoration(
                      labelText: selected == null
                          ? 'Unit cost (optional)'
                          : 'Cost per ${selected!.unitName} (optional)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      final qty = Money.parse(qtyController.text);
      final conv = selected?.conversionToBase ?? 1.0;
      final baseQty = qty * conv;
      double? unitCost;
      if (costController.text.trim().isNotEmpty) {
        final costPerReceived = Money.parse(costController.text);
        unitCost =
            conv == 0 ? costPerReceived : Money.round(costPerReceived / conv);
      }
      await _inventory.addStock(
        productId: product.id,
        quantity: baseQty,
        unitCost: unitCost,
        movementType: 'purchase_received',
        reason: selected == null || conv == 1
            ? 'Manual stock in'
            : 'Manual stock in: $qty ${selected!.unitName}',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
          TextButton(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: const Text('Manual'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'supplier'),
            child: const Text('From supplier'),
          ),
        ],
      ),
    );
    if (choice == 'supplier') {
      await _openReceiveGoods();
      return;
    }
    if (choice == 'manual') {
      await _manualAddStock(product);
    }
  }

  String _stockSubtitle(Product p, double qty, bool low) {
    final parts = <String>[
      Money.format(p.sellingPrice),
      '${_fmtQty(qty)} ${p.unit}',
    ];
    final units = _unitsByProduct[p.id] ?? const <ProductUnit>[];
    for (final u in units) {
      if (u.conversionToBase <= 1) continue;
      final alt = qty / u.conversionToBase;
      parts.add('≈ ${_fmtQty(alt)} ${u.unitName}');
      break;
    }
    if (low) parts.add('LOW');
    parts.add('tap for units');
    return parts.join(' · ');
  }

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      // AppShell uses extendBody: true + bottom NavigationBar — lift FAB so it stays tappable.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          heroTag: 'inventory_add_product',
          onPressed: _showAddProduct,
          tooltip: 'Add product',
          child: const Icon(Icons.add),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: GlassPanel(
                    margin: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : _products.isEmpty
                  ? const Center(
                      child: Text('No products yet. Tap + to add.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 140),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final p = _products[index];
                        final qty = _stock[p.id] ?? 0;
                        final low =
                            p.minimumStock > 0 && qty <= p.minimumStock;
                        return GlassPanel(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(_stockSubtitle(p, qty, low)),
                            onTap: () => _openProductUnits(p),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_box_outlined),
                              tooltip: 'Add stock',
                              onPressed: () => _addStockFlow(p),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
