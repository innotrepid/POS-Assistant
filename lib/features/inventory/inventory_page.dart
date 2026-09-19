import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _inventory = InventoryService();
  final _profiles = BusinessProfileService();
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
    final unitController = TextEditingController(text: profile.defaultUnit);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Profile defaults: ${profile.label} · unit ${profile.defaultUnit}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Selling price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(labelText: 'Cost price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Opening stock'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: minController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum stock (alert below this)',
                    helperText: '0 = no low-stock alert; out-of-stock still alerts',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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

    if (saved != true) return;

    try {
      final name = nameController.text.trim();
      final price = Money.parse(priceController.text);
      final costText = costController.text.trim();
      final cost = costText.isEmpty ? null : Money.parse(costText);
      final opening = Money.parse(stockController.text);
      final minStock = Money.parse(minController.text);
      final unit = unitController.text.trim().isEmpty
          ? profile.defaultUnit
          : unitController.text.trim();

      final product = await _inventory.createProduct(
        name: name,
        unit: unit,
        sellingPrice: price,
        costPrice: cost,
        minimumStock: minStock < 0 ? 0 : minStock,
        trackBatches: profile.defaultTrackBatches,
        hasExpiry: profile.defaultHasExpiry,
      );

      if (opening > 0) {
        await _inventory.addStock(
          productId: product.id,
          quantity: opening,
          unitCost: cost,
          movementType: 'opening_balance',
          reason: 'Opening stock',
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

  Future<void> _addStock(Product product) async {
    final qtyController = TextEditingController();
    final costController = TextEditingController(
      text: product.costPrice?.toStringAsFixed(2) ?? '',
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
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              TextField(
                controller: costController,
                decoration: const InputDecoration(labelText: 'Unit cost'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory_add_fab',
        onPressed: _showAddProduct,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_products.isEmpty) {
      return const Center(
        child: Text('No products yet. Tap + to add one.'),
      );
    }

    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = _products[index];
        final qty = _stock[product.id] ?? 0;
        final low = product.minimumStock > 0 && qty <= product.minimumStock;
        final out = qty <= 0;
        return ListTile(
          title: Text(product.name),
          subtitle: Text(
            '${Money.format(product.sellingPrice)} · ${product.unit} · Stock: $qty'
            '${product.minimumStock > 0 ? ' · min ${product.minimumStock}' : ''}'
            '${product.active ? '' : ' · inactive'}'
            '${out ? ' · OUT' : low ? ' · LOW' : ''}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add stock',
            onPressed: () => _addStock(product),
          ),
        );
      },
    );
  }
}
