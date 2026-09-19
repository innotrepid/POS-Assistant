import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';
import 'checkout_sheet.dart';
import 'sales_history_page.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _inventory = InventoryService();
  final _sales = SalesService();
  final _cart = CartController();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  Map<String, double> _stockByProduct = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = (query == null || query.trim().isEmpty)
          ? await _inventory.getAllProducts()
          : await _inventory.searchProducts(query.trim());

      final stockMap = <String, double>{};
      for (final p in products) {
        stockMap[p.id] = await _inventory.getStock(p.id);
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _stockByProduct = stockMap;
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

  Future<void> _addQuickSale() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quick sale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Does not affect inventory. Use for items not in the catalogue.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item name'),
                autofocus: true,
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
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
              child: const Text('Add to cart'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final price = Money.parse(priceCtrl.text);
    final qty = Money.parse(qtyCtrl.text);
    if (name.isEmpty || price < 0 || qty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name, price, and quantity')),
      );
      return;
    }

    _cart.addQuickSale(name: name, unitPrice: price, quantity: qty);
  }

  Future<void> _openCheckout() async {
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sale complete · ${Money.format(result.total)} · ${result.paymentType}',
        ),
        action: SnackBarAction(
          label: 'Receipt',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SalesHistoryPage(
                  highlightSaleId: result.saleId,
                ),
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
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(
            tooltip: 'Quick sale',
            icon: const Icon(Icons.flash_on),
            onPressed: _addQuickSale,
          ),
          IconButton(
            tooltip: 'Sales history',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SalesHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, barcode, or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts();
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) => _loadProducts(query: value),
              onSubmitted: (value) => _loadProducts(query: value),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildProductList(),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: _buildCartPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadProducts(query: _searchController.text),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'No products yet.\nAdd stock under the Stock tab,\nor use the flash icon for a quick sale.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = _products[index];
        final stock = _stockByProduct[product.id] ?? 0;
        final outOfStock = stock <= 0;

        return ListTile(
          title: Text(product.name),
          subtitle: Text(
            '${Money.format(product.sellingPrice)} · Stock: ${_fmtQty(stock)}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: outOfStock ? null : () => _cart.addProduct(product),
          ),
          onTap: outOfStock ? null : () => _cart.addProduct(product),
        );
      },
    );
  }

  Widget _buildCartPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                'Cart',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (!_cart.isEmpty)
                TextButton(
                  onPressed: _cart.clear,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Tap products or use Quick sale'))
              : ListView.builder(
                  itemCount: _cart.lines.length,
                  itemBuilder: (context, index) {
                    final line = _cart.lines[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        line.isQuickSale ? '${line.name} (quick)' : line.name,
                      ),
                      subtitle: Text(
                        '${_fmtQty(line.quantity)} × ${Money.format(line.unitPrice)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              _cart.setQuantity(
                                line.lineKey,
                                line.quantity - 1,
                              );
                            },
                          ),
                          Text(_fmtQty(line.quantity)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              _cart.setQuantity(
                                line.lineKey,
                                line.quantity + 1,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Money.format(line.lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total ${Money.format(_cart.subtotal)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _cart.isEmpty ? null : _openCheckout,
                  icon: const Icon(Icons.payments),
                  label: const Text('Pay'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtQty(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
