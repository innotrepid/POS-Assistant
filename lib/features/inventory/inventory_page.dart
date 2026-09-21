import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';
import '../../services/supplier_service.dart';
import '../../core/models/supplier.dart';

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
  final _suppliers = SupplierService();
  List<Product> _products = [];
  Map<String, double> _stock = {};
  bool _loading = true;
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
      final products = await _inventory.getAllProducts(activeOnly: false);
      final stock = <String, double>{};
      for (final p in products) {
        stock[p.id] = await _inventory.getStock(p.id);
      }
      if (!mounted) return;
      setState(() {
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

  Future<void> _showAddProduct() async {
    final profile = await _profiles.getProfile();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final minController = TextEditingController(text: '0');
    var selectedUnit = profile.defaultUnit;
    final unitController = TextEditingController(text: profile.defaultUnit);
    final units = profile.suggestedUnits;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    Text('Unit', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final u in units)
                          ChoiceChip(
                            label: Text(u),
                            selected: selectedUnit == u,
                            onSelected: (_) {
                              setLocal(() {
                                selectedUnit = u;
                                unitController.text = u;
                              });
                            },
                          ),
                      ],
                    ),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Or type unit'),
                      onChanged: (v) => setLocal(() => selectedUnit = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Selling price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'Cost (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    TextField(
                      controller: stockController,
                      decoration: const InputDecoration(labelText: 'Opening stock'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    TextField(
                      controller: minController,
                      decoration: const InputDecoration(labelText: 'Minimum stock'),
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

    if (saved != true) return;
    try {
      final product = await _inventory.createProduct(
        name: nameController.text,
        unit: unitController.text.trim().isEmpty ? selectedUnit : unitController.text.trim(),
        sellingPrice: Money.parse(priceController.text),
        costPrice: costController.text.trim().isEmpty ? null : Money.parse(costController.text),
        minimumStock: Money.parse(minController.text),
      );
      final opening = Money.parse(stockController.text);
      if (opening > 0) {
        await _inventory.addStock(
          productId: product.id,
          quantity: opening,
          unitCost: costController.text.trim().isEmpty ? null : Money.parse(costController.text),
          movementType: 'opening_stock',
          reason: 'Opening stock',
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addStock(Product product) async {
    final profile = await _profiles.getProfile();
    if (profile.features.suppliers) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Manual quantity'),
                onTap: () => Navigator.pop(context, 'manual'),
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('From a supplier'),
                subtitle: const Text('Pick what they brought'),
                onTap: () => Navigator.pop(context, 'supplier'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'supplier') {
        await _receiveFromSupplier(preselectedProduct: product);
        return;
      }
      if (choice != 'manual') return;
    }
    await _manualAddStock(product);
  }

  Future<void> _manualAddStock(Product product) async {
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(
      text: product.costPrice != null ? product.costPrice!.toString() : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add stock · ${product.name}'),
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
        );
      },
    );

    if (ok != true) return;
    try {
      final qty = Money.parse(qtyController.text);
      final costText = costController.text.trim();
      await _inventory.addStock(
        productId: product.id,
        quantity: qty,
        unitCost: costText.isEmpty ? null : Money.parse(costText),
        movementType: 'purchase_received',
        reason: 'Manual stock in',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _receiveFromSupplier({Product? preselectedProduct}) async {
    final suppliers = await _suppliers.getAllSuppliers();
    if (!mounted) return;
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No suppliers yet. Add one under Suppliers, or use manual stock.')),
      );
      return;
    }

    final supplier = await showModalBottomSheet<Supplier>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Who brought the goods?')),
            for (final s in suppliers)
              ListTile(
                title: Text(s.name),
                subtitle: s.supplies.isEmpty
                    ? const Text('No product list yet')
                    : Text(s.supplies.join(', ')),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (supplier == null || !mounted) return;

    final products = await _inventory.getAllProducts();
    final lines = <_ReceiveLine>[];
    final supplies = supplier.supplies;
    if (supplies.isEmpty) {
      for (final p in products) {
        lines.add(_ReceiveLine(product: p, name: p.name));
      }
    } else {
      for (final name in supplies) {
        Product? match;
        final lower = name.toLowerCase();
        for (final p in products) {
          if (p.name.toLowerCase() == lower ||
              p.name.toLowerCase().contains(lower) ||
              lower.contains(p.name.toLowerCase())) {
            match = p;
            break;
          }
        }
        lines.add(_ReceiveLine(product: match, name: name));
      }
    }
    if (preselectedProduct != null) {
      final exists = lines.any((l) => l.product?.id == preselectedProduct.id);
      if (!exists) {
        lines.insert(0, _ReceiveLine(product: preselectedProduct, name: preselectedProduct.name));
      }
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to receive. Add products first.')),
      );
      return;
    }

    final qtyCtrls = {for (final l in lines) l.name: TextEditingController()};
    final costCtrls = {
      for (final l in lines)
        l.name: TextEditingController(
          text: l.product?.costPrice != null ? '${l.product!.costPrice}' : '',
        ),
    };
    final selected = {for (final l in lines) l.name: false};
    if (preselectedProduct != null) {
      for (final l in lines) {
        if (l.product?.id == preselectedProduct.id) selected[l.name] = true;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Receive from ${supplier.name}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Tick items and enter quantities. Stock becomes old + new.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final l in lines)
                      CheckboxListTile(
                        value: selected[l.name] ?? false,
                        onChanged: (v) => setLocal(() => selected[l.name] = v ?? false),
                        title: Text(l.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (l.product == null)
                              const Text('New product will be created', style: TextStyle(fontSize: 11)),
                            if (selected[l.name] == true) ...[
                              TextField(
                                controller: qtyCtrls[l.name],
                                decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                              TextField(
                                controller: costCtrls[l.name],
                                decoration: const InputDecoration(labelText: 'Unit cost (optional)', isDense: true),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add stock')),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    var added = 0;
    try {
      for (final l in lines) {
        if (selected[l.name] != true) continue;
        final qty = Money.parse(qtyCtrls[l.name]!.text);
        if (qty <= 0) continue;
        final costText = costCtrls[l.name]!.text.trim();
        final unitCost = costText.isEmpty ? null : Money.parse(costText);

        var product = l.product;
        if (product == null) {
          product = await _inventory.createProduct(
            name: l.name,
            sellingPrice: unitCost != null && unitCost > 0 ? unitCost * 1.25 : 0,
            costPrice: unitCost,
            unit: 'piece',
            supplierId: supplier.id,
          );
        }

        await _inventory.addStock(
          productId: product.id,
          quantity: qty,
          unitCost: unitCost,
          movementType: 'purchase_received',
          reason: 'Received from ${supplier.name}',
          referenceId: supplier.id,
        );
        added++;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added stock for $added item${added == 1 ? '' : 's'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showReceiveEntry() async {
    final profile = await _profiles.getProfile();
    if (!profile.features.suppliers) {
      if (_products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a product first, then add stock on that line.')),
        );
        return;
      }
      final product = await showModalBottomSheet<Product>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Add stock to which product?')),
              for (final p in _products)
                ListTile(title: Text(p.name), onTap: () => Navigator.pop(context, p)),
            ],
          ),
        ),
      );
      if (product != null) await _manualAddStock(product);
      return;
    }
    await _receiveFromSupplier();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Stock', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          if (widget.onOpenNotifications != null)
            IconButton(
              tooltip: 'Notifications',
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: RaisedFab(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'inventory_receive_fab',
              onPressed: _showReceiveEntry,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Add stock'),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'inventory_add_fab',
              onPressed: _showAddProduct,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
          child: Text(
            'No products yet. Tap + to add one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final qty = _stock[product.id] ?? 0;
        final low = product.minimumStock > 0 && qty <= product.minimumStock;
        final out = qty <= 0;
        final scheme = Theme.of(context).colorScheme;

        return GlassPanel(
          margin: const EdgeInsets.only(bottom: 10),
          borderRadius: 18,
          child: ListTile(
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${Money.format(product.sellingPrice)} · stock ${qty} ${product.unit}'
              '${out ? ' · OUT' : (low ? ' · LOW' : '')}',
              style: TextStyle(color: out || low ? scheme.error : null),
            ),
            trailing: IconButton(
              onPressed: () => _addStock(product),
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Add stock',
            ),
          ),
        );
      },
    );
  }
}

class _ReceiveLine {
  final Product? product;
  final String name;
  _ReceiveLine({required this.product, required this.name});
}
