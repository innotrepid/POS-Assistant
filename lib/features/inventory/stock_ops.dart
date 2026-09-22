import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';

/// Single-product adjust dialog (reason required).
Future<void> showAdjustStockDialog({
  required BuildContext context,
  required InventoryService inventory,
  required Product product,
  required double currentStock,
  required Future<void> Function() onDone,
}) async {
  final qtyCtrl = TextEditingController(
    text: currentStock == currentStock.truncateToDouble()
        ? currentStock.toInt().toString()
        : currentStock.toStringAsFixed(2),
  );
  var reasonKey = 'count_fix';
  final noteCtrl = TextEditingController();
  const reasons = <String, String>{
    'count_fix': 'Count correction',
    'damage': 'Damage / spoilage',
    'wastage': 'Wastage',
    'theft': 'Theft / loss',
    'other': 'Other',
  };

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text('Adjust · ${product.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('System stock: $currentStock ${product.unit}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Actual quantity (${product.unit})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  Text('Reason', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in reasons.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: reasonKey == e.key,
                          onSelected: (_) => setLocal(() => reasonKey = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
  if (ok != true || !context.mounted) return;
  try {
    final counted = Money.parse(qtyCtrl.text);
    final note = noteCtrl.text.trim();
    final reason = note.isEmpty ? reasons[reasonKey]! : '${reasons[reasonKey]}: $note';
    await inventory.adjustStock(
      productId: product.id,
      newQuantity: counted,
      reason: reason,
    );
    await onDone();
    if (!context.mounted) return;
    final diff = Money.round(counted - currentStock);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          diff == 0
              ? 'No change'
              : diff > 0
                  ? 'Adjusted +$diff ${product.unit}'
                  : 'Adjusted $diff ${product.unit}',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Full stocktake bottom sheet.
Future<void> showStocktakeSheet({
  required BuildContext context,
  required InventoryService inventory,
  required List<Product> products,
  required Map<String, double> stockById,
  required Future<void> Function() onDone,
}) async {
  if (products.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add products first')),
    );
    return;
  }

  final ctrls = <String, TextEditingController>{};
  for (final p in products) {
    final q = stockById[p.id] ?? 0;
    ctrls[p.id] = TextEditingController(
      text: q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2),
    );
  }

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Stocktake', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Enter what you actually have. Differences become adjustments with audit.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final system = stockById[p.id] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('System: $system ${p.unit}'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: ctrls[p.id],
                                decoration: InputDecoration(
                                  labelText: 'Counted (${p.unit})',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm stocktake'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (ok != true || !context.mounted) {
    for (final c in ctrls.values) {
      c.dispose();
    }
    return;
  }

  final counted = <String, double>{};
  for (final p in products) {
    counted[p.id] = Money.parse(ctrls[p.id]!.text);
  }
  for (final c in ctrls.values) {
    c.dispose();
  }

  try {
    final changed = await inventory.applyStocktake(
      countedByProductId: counted,
      reason: 'Stocktake ${DateTime.now().toIso8601String().substring(0, 10)}',
    );
    await onDone();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed == 0
              ? 'Stocktake done · everything matched'
              : 'Stocktake done · $changed product${changed == 1 ? '' : 's'} adjusted',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
