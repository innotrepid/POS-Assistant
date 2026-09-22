import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/supplier.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/expense_service.dart';
import '../../services/inventory_service.dart';
import '../../services/purchase_service.dart';
import '../../services/supplier_service.dart';

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
  final _purchases = PurchaseService();
  final _expenses = ExpenseService();
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
      final products = await _inventory.getAllProducts();
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
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: profile.defaultUnit);
    final units = profile.suggestedUnits;

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
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
                    const SizedBox(height: 12),
                    TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Selling price'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 12),
                    TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost (optional)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final u in units)
                          ChoiceChip(
                            label: Text(u),
                            selected: unitCtrl.text == u,
                            onSelected: (_) => setLocal(() => unitCtrl.text = u),
                          ),
                      ],
                    ),
                    TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit')),
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
      await _inventory.createProduct(
        name: nameCtrl.text.trim(),
        sellingPrice: Money.parse(priceCtrl.text),
        costPrice: costCtrl.text.trim().isEmpty ? null : Money.parse(costCtrl.text),
        unit: unitCtrl.text.trim().isEmpty ? profile.defaultUnit : unitCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addStockFlow(Product product) async {
    final profile = await _profiles.getProfile();
    if (profile.features.suppliers) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add stock · ${product.name}'),
          content: const Text('How did the stock arrive?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'manual'), child: const Text('Manual')),
            FilledButton(onPressed: () => Navigator.pop(context, 'supplier'), child: const Text('From supplier')),
          ],
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
      builder: (context) => AlertDialog(
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
      ),
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
                subtitle: s.supplies.isEmpty ? const Text('No product list yet') : Text(s.supplies.join(', ')),
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
                    Text('Tick items, enter qty and supplier unit cost.', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    for (final l in lines)
                      CheckboxListTile(
                        value: selected[l.name] ?? false,
                        onChanged: (v) => setLocal(() => selected[l.name] = v ?? false),
                        title: Text(l.name),
                        subtitle: selected[l.name] == true
                            ? Column(
                                children: [
                                  TextField(
                                    controller: qtyCtrls[l.name],
                                    decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                  TextField(
                                    controller: costCtrls[l.name],
                                    decoration: const InputDecoration(labelText: 'Supplier unit cost', isDense: true),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              )
                            : (l.product == null
                                ? const Text('New product will be created', style: TextStyle(fontSize: 11))
                                : null),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Next')),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;

    try {
      final purchaseLines = <PurchaseLineInput>[];
      for (final l in lines) {
        if (selected[l.name] != true) continue;
        final qty = Money.parse(qtyCtrls[l.name]!.text);
        if (qty <= 0) continue;
        final costText = costCtrls[l.name]!.text.trim();
        final unitCost = costText.isEmpty ? 0.0 : Money.parse(costText);

        var product = l.product;
        if (product == null) {
          product = await _inventory.createProduct(
            name: l.name,
            sellingPrice: unitCost > 0 ? unitCost * 1.25 : 0,
            costPrice: unitCost > 0 ? unitCost : null,
            unit: 'piece',
            supplierId: supplier.id,
          );
        }

        purchaseLines.add(PurchaseLineInput(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          unitCost: unitCost,
        ));
      }

      if (purchaseLines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter quantity for at least one item')),
        );
        return;
      }

      final total = purchaseLines.fold<double>(0, (s, l) => s + l.total);
      final paidCtrl = TextEditingController(text: total.toStringAsFixed(0));
      var payMethod = 'cash';
      var payMode = 'paid';

      final payOk = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: const Text('How did you pay the supplier?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Goods total ${Money.format(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Paid now'),
                          selected: payMode == 'paid',
                          onSelected: (_) => setLocal(() {
                            payMode = 'paid';
                            paidCtrl.text = total.toStringAsFixed(0);
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Credit (owe)'),
                          selected: payMode == 'credit',
                          onSelected: (_) => setLocal(() {
                            payMode = 'credit';
                            paidCtrl.text = '0';
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Partial'),
                          selected: payMode == 'partial',
                          onSelected: (_) => setLocal(() => payMode = 'partial'),
                        ),
                      ],
                    ),
                    if (payMode != 'credit') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: paidCtrl,
                        decoration: const InputDecoration(labelText: 'Amount paid now', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final m in ['cash', 'mpesa'])
                            ChoiceChip(
                              label: Text(m.toUpperCase()),
                              selected: payMethod == m,
                              onSelected: (_) => setLocal(() => payMethod = m),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      payMode == 'credit'
                          ? 'Full amount becomes money you owe this supplier.'
                          : 'Paid amount is logged as a stock-purchase expense.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                ],
              );
            },
          );
        },
      );
      if (payOk != true || !mounted) return;

      final paid = payMode == 'credit' ? 0.0 : Money.parse(paidCtrl.text);
      await _purchases.createPurchase(
        supplierId: supplier.id,
        items: purchaseLines,
        paidAmount: paid,
        paymentType: payMethod,
      );

      if (paid > 0) {
        try {
          await _expenses.recordExpense(
            category: 'Stock purchase',
            amount: paid,
            description: 'Paid ${supplier.name} for goods received',
            paymentMethod: payMethod,
          );
        } catch (_) {}
      }

      await _load();
      if (!mounted) return;
      final bal = Money.round(total - paid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bal > 0
                ? 'Stock updated · paid ${Money.format(paid)} · owe ${Money.format(bal)}'
                : 'Stock updated · paid ${Money.format(paid)}',
          ),
        ),
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
                ListTile(
                  title: Text(p.name),
                  onTap: () => Navigator.pop(context, p),
                ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Stock', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'inventory_receive_fab',
              onPressed: _showReceiveEntry,
              icon: const Icon(Icons.move_to_inbox),
              label: const Text('Receive'),
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
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('No products yet. Tap + to add one.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final qty = _stock[product.id] ?? 0;
        return GlassPanel(
          margin: const EdgeInsets.only(bottom: 8),
          borderRadius: 16,
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${Money.format(product.sellingPrice)} · stock $qty ${product.unit}'),
            trailing: IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Add stock',
              onPressed: () => _addStockFlow(product),
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
