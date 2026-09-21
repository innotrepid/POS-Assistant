import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';
import 'checkout_sheet.dart';
import 'receipt_page.dart';

class PosPage extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onSaleCompleted;

  const PosPage({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
    this.onOpenAssistant,
    this.onSaleCompleted,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _inventory = InventoryService();
  final _sales = SalesService();
  final _cart = CartController();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  Map<String, double> _stock = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cart.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({String query = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = query.trim().isEmpty
          ? await _inventory.getAllProducts()
          : await _inventory.searchProducts(query);
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

  Future<void> _quickSale() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quick sale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
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
              child: const Text('Add to cart'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final price = Money.parse(priceCtrl.text);
    final qty = Money.parse(qtyCtrl.text);
    if (name.isEmpty || price <= 0 || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name, price, and quantity')),
      );
      return;
    }
    _cart.addAdhoc(name: name, unitPrice: price, quantity: qty);
    setState(() {});
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    final result = await showModalBottomSheet<CheckoutResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CheckoutSheet(
        cart: _cart,
        salesService: _sales,
      ),
    );

    if (result == null || !mounted) return;

    _cart.clear();
    await _loadProducts(query: _searchController.text);
    widget.onSaleCompleted?.call();

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
        duration: const Duration(seconds: 8),
        content: Text(
          'Sale complete · ${Money.format(result.total)} · ${result.paymentType}'
          '${result.changeGiven > 0 ? ' · change ${Money.format(result.changeGiven)}' : ''}',
        ),
        action: SnackBarAction(
          label: 'Receipt',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => ReceiptPage(saleId: result.saleId),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'POS',
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
          IconButton(
            tooltip: 'Quick sale',
            onPressed: _quickSale,
            icon: const Icon(Icons.bolt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: GlassPanel(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (q) => _loadProducts(query: q),
              ),
            ),
          ),
          Expanded(child: _buildCatalogue()),
          _buildCartBar(),
        ],
      ),
    );
  }

  Widget _buildCatalogue() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_products.isEmpty) {
      return const Center(child: Text('No products. Add stock first.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        final qty = _stock[p.id] ?? 0;
        return GlassPanel(
          margin: const EdgeInsets.only(bottom: 8),
          borderRadius: 16,
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${Money.format(p.sellingPrice)} · stock ${Money.format(qty)} ${p.unit}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: qty <= 0
                  ? null
                  : () {
                      _cart.addProduct(p, quantity: 1);
                      setState(() {});
                    },
            ),
            onTap: qty <= 0
                ? null
                : () {
                    _cart.addProduct(p, quantity: 1);
                    setState(() {});
                  },
          ),
        );
      },
    );
  }

  Widget _buildCartBar() {
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        if (_cart.isEmpty) return const SizedBox.shrink();
        return GlassPanel(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          borderRadius: 18,
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_cart.lineCount} item${_cart.lineCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      Money.format(_cart.total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  _cart.clear();
                  setState(() {});
                },
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: _checkout,
                child: const Text('Pay'),
              ),
            ],
          ),
        );
      },
    );
  }
}
