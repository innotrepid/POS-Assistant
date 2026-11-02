import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';
import '../../services/locale_service.dart';
import 'cart_controller.dart';
import 'checkout_sheet.dart';
import 'sales_history_page.dart';

class PosPage extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;

  const PosPage({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _inventory = InventoryService();
  final _cart = CartController();
  final _searchCtrl = TextEditingController();

  List<Product> _products = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCart);
    _load();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCart);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _inventory.getAllProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        _applyFilter();
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

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.of(_products);
    } else {
      _filtered = _products
          .where((p) => p.name.toLowerCase().contains(q))
          .toList();
    }
  }

  Future<void> _quickSale() async {
    final s = localeController.s;
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.quickSale),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: s.itemName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(labelText: s.price),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              decoration: InputDecoration(labelText: s.quantity),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            child: Text(s.addToCart),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final price = Money.parse(priceCtrl.text);
    final qty = Money.parse(qtyCtrl.text);
    if (name.isEmpty || price <= 0 || qty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.invalidQuickSale)),
      );
      return;
    }
    _cart.addCustom(name: name, unitPrice: price, quantity: qty);
  }

  Future<void> _checkout() async {
    if (_cart.lines.isEmpty) return;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CheckoutSheet(cart: _cart),
    );
    if (done == true) {
      _cart.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = localeController.s;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          s.pos,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
        actions: [
          if (widget.onOpenNotifications != null)
            IconButton(
              tooltip: s.notifications,
              onPressed: widget.onOpenNotifications,
              icon: Badge(
                isLabelVisible: widget.unreadCount > 0,
                label: Text('${widget.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          IconButton(
            tooltip: s.quickSale,
            onPressed: _quickSale,
            icon: const Icon(Icons.bolt_outlined),
          ),
          IconButton(
            tooltip: s.history,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SalesHistoryPage(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: s.searchProducts,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(_applyFilter),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: _load,
                              child: Text(s.retry),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                s.noProductsPos,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = _filtered[index];
                              return ListTile(
                                title: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  Money.format(product.sellingPrice),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _cart.addProduct(product),
                                ),
                                onTap: () => _cart.addProduct(product),
                              );
                            },
                          ),
          ),
          Material(
            elevation: 8,
            color: scheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_cart.lines.isEmpty)
                      Text(
                        s.cartEmpty,
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_cart.lines.length} · ${Money.format(_cart.total)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            s.total,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_cart.lines.isNotEmpty)
                          TextButton(
                            onPressed: _cart.clear,
                            child: Text(s.clear),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed:
                              _cart.lines.isEmpty ? null : _checkout,
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(s.pay),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
