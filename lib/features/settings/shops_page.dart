import 'package:flutter/material.dart';

import '../../core/models/shop.dart';
import '../../services/shop_service.dart';

/// Manage isolated shops (each has its own local database).
class ShopsPage extends StatefulWidget {
  /// Called after switching or creating a shop so the app shell can rebuild.
  final VoidCallback? onShopChanged;

  const ShopsPage({super.key, this.onShopChanged});

  @override
  State<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage> {
  final _shops = ShopService();
  List<Shop> _list = [];
  String? _activeId;
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
      final list = await _shops.listShops();
      final active = await _shops.getActiveShop();
      if (!mounted) return;
      setState(() {
        _list = list;
        _activeId = active?.id;
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

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New shop'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Shop name',
              hintText: 'e.g. Mama Njeri produce',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    try {
      await _shops.createShop(name: ctrl.text);
      widget.onShopChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop created and opened')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _switchTo(Shop shop) async {
    if (shop.id == _activeId) return;
    try {
      await _shops.switchToShop(shop.id);
      widget.onShopChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${shop.name}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _rename(Shop shop) async {
    final ctrl = TextEditingController(text: shop.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename shop'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Shop name'),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
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
    if (ok != true) return;

    try {
      await _shops.renameShop(shop.id, ctrl.text);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _delete(Shop shop) async {
    if (_list.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the only shop')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete shop?'),
          content: Text(
            'Delete "${shop.name}"?\n\n'
            'All sales, stock, and customers for this shop will be removed '
            'from this phone. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    try {
      final wasActive = shop.id == _activeId;
      await _shops.deleteShop(shop.id);
      if (wasActive) widget.onShopChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${shop.name}')),
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
        title: const Text('Shops'),
        actions: [
          IconButton(
            tooltip: 'Add shop',
            icon: const Icon(Icons.add),
            onPressed: _create,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Each shop keeps its own sales, stock, and customers '
                      'in a separate offline database on this phone.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    for (final shop in _list)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            shop.id == _activeId
                                ? Icons.store
                                : Icons.store_outlined,
                            color: shop.id == _activeId
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(shop.name),
                          subtitle: Text(
                            shop.id == _activeId
                                ? 'Active now'
                                : 'Tap to open',
                          ),
                          selected: shop.id == _activeId,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'rename':
                                  _rename(shop);
                                case 'delete':
                                  _delete(shop);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              if (_list.length > 1)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                            ],
                          ),
                          onTap: () => _switchTo(shop),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Add another shop'),
                    ),
                  ],
                ),
    );
  }
}
