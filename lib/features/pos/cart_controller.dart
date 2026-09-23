import 'package:flutter/foundation.dart';

import '../../core/models/product.dart';
import '../../core/models/product_unit.dart';
import '../../core/utils/money.dart';
import 'cart_line.dart';

/// In-memory cart for the POS screen.
class CartController extends ChangeNotifier {
  final List<CartLine> _lines = [];

  List<CartLine> get lines => List.unmodifiable(_lines);

  int get itemCount => _lines.fold<int>(
        0,
        (sum, line) => sum + line.quantity.round(),
      );

  double get subtotal => Money.round(
        _lines.fold<double>(0, (sum, line) => sum + line.lineTotal),
      );

  bool get isEmpty => _lines.isEmpty;

  /// Add catalogue product. Pass [unit] for multi-UoM; otherwise uses product defaults.
  void addProduct(
    Product product, {
    double quantity = 1,
    ProductUnit? unit,
  }) {
    final line = unit != null
        ? CartLine.fromProductUnit(
            product: product,
            unit: unit,
            quantity: quantity,
          )
        : CartLine.fromProduct(product, quantity: quantity);

    final index = _lines.indexWhere(
      (l) => !l.isQuickSale && l.lineKey == line.lineKey,
    );
    if (index >= 0) {
      final existing = _lines[index];
      _lines[index] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _lines.add(line);
    }
    notifyListeners();
  }

  void addQuickSale({
    required String name,
    required double unitPrice,
    double quantity = 1,
  }) {
    _lines.add(
      CartLine.quickSale(
        name: name,
        unitPrice: unitPrice,
        quantity: quantity,
      ),
    );
    notifyListeners();
  }

  void setQuantity(String lineKey, double quantity) {
    if (quantity <= 0) {
      removeLine(lineKey);
      return;
    }
    final index = _lines.indexWhere((l) => l.lineKey == lineKey);
    if (index < 0) return;
    _lines[index] = _lines[index].copyWith(quantity: quantity);
    notifyListeners();
  }

  void removeLine(String lineKey) {
    _lines.removeWhere((l) => l.lineKey == lineKey);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
