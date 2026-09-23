import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/product_unit.dart';
import '../../core/utils/money.dart';
import '../../services/inventory_service.dart';
import '../../services/policy_service.dart';

/// Result of picking a selling unit for a catalogue product.
class UnitPickResult {
  final Product product;
  final ProductUnit unit;

  const UnitPickResult({required this.product, required this.unit});
}

/// Shows selling units for [product].
///
/// - 0–1 units (and policy off) → returns the only/default unit without a sheet
/// - 2+ units, or policy requireUnitPick → bottom sheet for piece / kg / heap / etc.
Future<UnitPickResult?> showUnitPicker(
  BuildContext context, {
  required Product product,
  InventoryService? inventory,
}) async {
  final inv = inventory ?? InventoryService();
  var units = await inv.getUnits(product.id);
  if (units.isEmpty) {
    await inv.ensureDefaultUnit(product.id);
    units = await inv.getUnits(product.id);
  }

  if (units.isEmpty) {
    final fallback = ProductUnit(
      id: '${product.id}_default',
      productId: product.id,
      unitName: product.unit,
      conversionToBase: 1,
      sellingPrice: product.sellingPrice,
      isDefault: true,
      createdAt: DateTime.now(),
    );
    return UnitPickResult(product: product, unit: fallback);
  }

  final forcePick = await PolicyService().getRequireUnitPick();
  if (units.length == 1 && !forcePick) {
    return UnitPickResult(product: product, unit: units.first);
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<UnitPickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product.name,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose unit',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final unit in units)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    unit.unitName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    unit.conversionToBase == 1
                        ? 'Base unit'
                        : '1 ${unit.unitName} = ${_fmt(unit.conversionToBase)} ${product.unit}',
                  ),
                  trailing: Text(
                    Money.format(unit.sellingPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop(
                      UnitPickResult(product: product, unit: unit),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

String _fmt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}
