import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/supplier.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';
import '../../services/purchase_service.dart';
import '../../services/supplier_service.dart';

class _DraftLine {
  Product product;
  double quantity;
  double unitCost;

  _DraftLine({
    required this.product,
    required this.quantity,
    required this.unitCost,
  });

  double get total => Money.round(quantity * unitCost);
}

class ReceivePurchasePage extends StatefulWidget {
  const ReceivePurchasePage({super.key});

  @override
  State<ReceivePurchasePage> createState() => _ReceivePurchasePageState();
}

class _ReceivePurchasePageState extends State<ReceivePurchasePage> {
  final _suppliers = SupplierService();
  final _inventory = InventoryService();
  final _purchases = PurchaseService();

  List<Supplier> _supplierList = [];
  List<Product> _products = [];
  Supplier? _supplier;
  final List<_DraftLine> _lines = [];
  final _paidCtrl = TextEditingController(text: '0');
  final _refCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  double get _subtotal =>
      Money.round(_lines.fold<double>(0, (s, l) => s + l.total));

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final s = await _suppliers.getAllSuppliers();
      final p = await _inventory.getAllProducts();
      if (!mounted) return;
      setState(() {
        _supplierList = s;
        _products = p;
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

  Future<void> _addLine() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products under Stock first')),
      );
      return;
    }

    Product? selected = _products.first;
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(
      text: selected.costPrice?.toStringAsFixed(2) ?? '0',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add line'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: selected,
                      items: _products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p == null) return;
                        setLocal(() {
                          selected = p;
                          costCtrl.text =
                              p.costPrice?.toStringAsFixed(2) ?? '0';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Product'),
                    ),
                    TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    TextField(
                      controller: costCtrl,
                      decoration: const InputDecoration(labelText: 'Unit cost'),
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
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || selected == null) return;

    setState(() {
      _lines.add(
        _DraftLine(
          product: selected!,
          quantity: Money.parse(qtyCtrl.text),
          unitCost: Money.parse(costCtrl.text),
        ),
      );
    });
  }

  Future<void> _save() async {
    if (_supplier == null) {
      setState(() => _error = 'Select a supplier');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one product line');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _purchases.createPurchase(
        supplierId: _supplier!.id,
        items: _lines
            .map(
              (l) => PurchaseLineInput(
                productId: l.product.id,
                productName: l.product.name,
                quantity: l.quantity,
                unitCost: l.unitCost,
              ),
            )
            .toList(),
        paidAmount: Money.parse(_paidCtrl.text),
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase recorded · stock updated')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive goods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_supplierList.isEmpty)
                  const Text('Add a supplier first from the Suppliers tab.')
                else
                  DropdownButtonFormField<Supplier>(
                    value: _supplier,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      border: OutlineInputBorder(),
                    ),
                    items: _supplierList
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (s) => setState(() => _supplier = s),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Lines',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                for (var i = 0; i < _lines.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_lines[i].product.name),
                    subtitle: Text(
                      '${_lines[i].quantity} × ${Money.format(_lines[i].unitCost)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Money.format(_lines[i].total)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _lines.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Text(
                  'Total ${Money.format(_subtotal)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount paid now',
                    helperText: 'Leave 0 if buying on credit',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm receive'),
                ),
              ],
            ),
    );
  }
}
