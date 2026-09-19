import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';

/// Minimal product + stock management so POS has catalogue data.
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _inventory = InventoryService();
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
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final stockController = TextEditingController(text: '0');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
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

      final product = await _inventory.createProduct(
        name: name,
        sellingPrice: price,
        costPrice: cost,
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
      floatingActionButton: FloatingActionButton(
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
        return ListTile(
          title: Text(product.name),
          subtitle: Text(
            '${Money.format(product.sellingPrice)} · Stock: $qty'
            '${product.active ? '' : ' · inactive'}',
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
