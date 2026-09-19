import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';

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
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'Cost price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      decoration: const InputDecoration(labelText: 'Opening stock'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minController,
                      decoration: const InputDecoration(
                        labelText: 'Minimum stock (alert below this)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                decoration: InputDecoration(labelText: 'Quantity (${product.unit})'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                decoration: const InputDecoration(labelText: 'Unit cost'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Stock',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
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
        child: FloatingActionButton(
          heroTag: 'inventory_add_fab',
          onPressed: _showAddProduct,
          child: const Icon(Icons.add),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
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
          accent: out || low,
          glowColor: out ? scheme.error : (low ? Colors.orange : null),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Money.format(product.sellingPrice)} · ${product.unit}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stock ${_fmt(qty)} ${product.unit}'
                      '${product.minimumStock > 0 ? ' · min ${_fmt(product.minimumStock)}' : ''}'
                      '${out ? '  OUT' : low ? '  LOW' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: out
                            ? scheme.error
                            : low
                                ? Colors.orange
                                : scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _addStock(product),
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'Add stock',
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
