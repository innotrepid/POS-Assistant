import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/inventory_service.dart';
import '../../services/locale_service.dart';
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
    for (final extra in [
      'debe',
      'gorogoro',
      'kg',
      'bunch',
      'piece',
      'head',
      'pack',
      'tray',
    ]) {
      if (!units.contains(extra)) units.add(extra);
    }
    if (current != null && current.isNotEmpty && !units.contains(current)) {
      units.insert(0, current);
    }
    return units;
  }

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toStringAsFixed(1);
  }

  Future<void> _deleteProduct(Product product) async {
    final s = localeController.s;
    final qty = _stock[product.id] ?? 0;
    final lines = <String>[
      'Remove "${product.name}" from stock and sales?',
      '',
      '• It will no longer appear in Stock or POS',
      '• Past sales and reports stay for history',
    ];
    if (qty > 0) {
      lines.add(
        '• Current quantity on hand: ${_fmtQty(qty)} ${product.unit}',
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
          size: 36,
        ),
        title: Text(s.deleteProductTitle),
        content: Text(lines.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.keepProduct),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.yesDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _inventory.deleteProduct(
        product.id,
        reason: 'Removed from stock list by user',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.productRemoved(product.name))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _editProduct(Product product) async {
    final s = localeController.s;
    final profile = await _profiles.getProfile();
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl =
        TextEditingController(text: product.sellingPrice.toString());
    final costCtrl =
        TextEditingController(text: product.costPrice?.toString() ?? '');
    final units = _unitsFor(profile, current: product.unit);
    var selectedUnit = product.unit;

    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(s.editProduct),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: s.name),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: InputDecoration(labelText: s.sellingPrice),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      decoration: InputDecoration(labelText: s.costOptional),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(s.unit, style: Theme.of(context).textTheme.labelLarge),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(s.delete),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: Text(s.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == 'delete') {
      await _deleteProduct(product);
      return;
    }
    if (action != 'save' || !mounted) return;

    try {
      await _inventory.updateProduct(
        product.copyWith(
          name: nameCtrl.text.trim(),
          sellingPrice: Money.parse(priceCtrl.text),
          costPrice: costCtrl.text.trim().isEmpty
              ? null
              : Money.parse(costCtrl.text),
          unit: selectedUnit,
          updatedAt: DateTime.now(),
        ),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.productUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
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
                ? 'All starter items are already in stock.'
                : 'Added $n new starter products.',
          ),
        ),
      );
      if (n > 0) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _spoilage(Product product) async {
    final s = localeController.s;
    final qtyCtrl = TextEditingController();
    var reason = kSpoilageReasons.first;
    final otherCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('${s.spoilage} · ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: qtyCtrl,
                  decoration: InputDecoration(
                    labelText: '${s.quantity} (${product.unit})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Text(s.reason, style: Theme.of(context).textTheme.labelLarge),
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
                  TextField(
                    controller: otherCtrl,
                    decoration: InputDecoration(labelText: s.describe),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.record),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.spoilage} · ${product.name}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _openReceiveGoods() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReceivePurchasePage()),
    );
    _load();
  }

  Future<void> _showAddProduct() async {
    final s = localeController.s;
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
              title: Text(s.addProduct),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: s.name),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: InputDecoration(labelText: s.sellingPrice),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      decoration: InputDecoration(labelText: s.costOptional),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(s.unit, style: Theme.of(context).textTheme.labelLarge),
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
                        labelText: s.openingQtyOptional,
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
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(s.save),
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
        costPrice: costCtrl.text.trim().isEmpty
            ? null
            : Money.parse(costCtrl.text),
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
    final s = localeController.s;
    final qtyController = TextEditingController(text: '1');
    final costController =
        TextEditingController(text: product.costPrice?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${s.boughtToday} · ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: '${s.quantity} (${product.unit})',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              decoration: InputDecoration(labelText: s.unitCostOptional),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.add),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _inventory.restockBoughtToday(
        productId: product.id,
        quantity: Money.parse(qtyController.text),
        unitCost: costController.text.trim().isEmpty
            ? null
            : Money.parse(costController.text),
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
    final s = localeController.s;
    if (!_suppliersEnabled) {
      await _manualAddStock(product);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${s.stock} · ${product.name}'),
        content: Text(s.howStockArrived),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: Text(s.boughtToday),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'supplier'),
            child: Text(s.fromSupplier),
          ),
        ],
      ),
    );
    if (choice == 'manual') await _manualAddStock(product);
    if (choice == 'supplier') await _openReceiveGoods();
  }

  @override
  Widget build(BuildContext context) {
    final s = localeController.s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.stock),
        actions: [
          if (_suppliersEnabled)
            IconButton(
              tooltip: s.receiveGoods,
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
            tooltip: s.addMissingStarter,
            icon: const Icon(Icons.playlist_add),
            onPressed: _seedStarter,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: _showAddProduct,
          icon: const Icon(Icons.add),
          label: Text(s.addItem),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.noProductsYet,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: _seedStarter,
                              child: Text(s.loadStarter),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _products[index];
                        final qty = _stock[p.id] ?? 0;
                        final low =
                            p.minimumStock > 0 && qty <= p.minimumStock;
                        return ListTile(
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_fmtQty(qty)} ${p.unit} · ${Money.format(p.sellingPrice)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (low)
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20,
                                ),
                              IconButton(
                                tooltip: s.boughtToday,
                                icon: const Icon(Icons.add_box_outlined),
                                onPressed: () => _addStockFlow(p),
                              ),
                              IconButton(
                                tooltip: s.spoilage,
                                icon: const Icon(Icons.eco_outlined),
                                onPressed: () => _spoilage(p),
                              ),
                              IconButton(
                                tooltip: s.more,
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _editProduct(p),
                              ),
                            ],
                          ),
                          onTap: () => _editProduct(p),
                        );
                      },
                    ),
    );
  }
}
