import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';
import 'checkout_sheet.dart';
import 'sales_history_page.dart';

class PosPage extends StatefulWidget {
  final VoidCallback? onSaleCompleted;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onOpenNotifications;
  final int unreadCount;

  const PosPage({
    super.key,
    this.onSaleCompleted,
    this.onOpenAssistant,
    this.onOpenNotifications,
    this.unreadCount = 0,
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
    widget.onSaleCompleted?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sale complete · ${Money.format(result.total)} · ${result.paymentType}'
          '${result.changeGiven > 0 ? ' · change ${Money.format(result.changeGiven)}' : ''}',
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'POS',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
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
          if (widget.onOpenAssistant != null)
            IconButton(
              tooltip: 'Assistant',
              icon: const Icon(Icons.auto_awesome),
              onPressed: widget.onOpenAssistant,
            ),
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: GlassPanel(
              borderRadius: 16,
              padding: EdgeInsets.zero,
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
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => _loadProducts(query: value),
                onSubmitted: (value) => _loadProducts(query: value),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildProductList(),
          ),
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
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
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
      return Center(
        child: GlassPanel(
          margin: const EdgeInsets.all(24),
          child: Text(
            'No products yet.\nAdd stock under the Stock tab,\nor use the flash icon for a quick sale.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final stock = _stockByProduct[product.id] ?? 0;
        final outOfStock = stock <= 0;

        return GlassPanel(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: 16,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${Money.format(product.sellingPrice)} · Stock: ${_fmtQty(stock)}',
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.add_shopping_cart,
                color: outOfStock
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
              onPressed: outOfStock ? null : () => _cart.addProduct(product),
            ),
            onTap: outOfStock ? null : () => _cart.addProduct(product),
          ),
        );
      },
    );
  }

  Widget _buildCartPanel() {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      borderRadius: 24,
      accent: !_cart.isEmpty,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'CART',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (!_cart.isEmpty)
                TextButton(
                  onPressed: _cart.clear,
                  child: const Text('Clear'),
                ),
            ],
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Text(
                      'Tap products or use Quick sale',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _cart.lines.length,
                    itemBuilder: (context, index) {
                      final line = _cart.lines[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          line.isQuickSale
                              ? '${line.name} (quick)'
                              : line.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                            Text(
                              _fmtQty(line.quantity),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                _cart.setQuantity(
                                  line.lineKey,
                                  line.quantity + 1,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Money.format(line.lineTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Money.format(_cart.subtotal),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
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
        ],
      ),
    );
  }

  String _fmtQty(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
