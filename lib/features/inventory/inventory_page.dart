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

  Future<void> _deleteProduct(Product product) async {
    final qty = _stock[product.id] ?? 0;
    final buffer = StringBuffer()
      ..writeln('Remove "${product.name}" from stock and sales?')
      ..writeln()
      ..writeln('• It will no longer appear in Stock or POS')
      ..writeln('• Past sales and reports stay for history');
    if (qty > 0) {
      buffer.writeln(
        '• Current quantity on hand: ${_fmtQty(qty)} ${product.unit}',
      );
    }
    buffer
      ..writeln()
      ..write('You can add it again later (including from the starter list).');

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
          size: 36,
        ),
        title: const Text('Delete this product?'),
        content: Text(buffer.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep product'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _inventory.deleteProduct(
        product.id,
        reason: 'Removed from stock list by user',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  // PARTIAL - will complete in next push if needed
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Loading stock…')));
  }
}
