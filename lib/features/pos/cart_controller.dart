import 'package:flutter/foundation.dart';

import '../../core/models/product.dart';
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

  void addProduct(Product product, {double quantity = 1}) {
    final index = _lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0) {
      final existing = _lines[index];
      _lines[index] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _lines.add(
        CartLine(
          product: product,
          quantity: quantity,
          unitPrice: product.sellingPrice,
        ),
      );
    }
    notifyListeners();
  }

  void setQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }
    final index = _lines.indexWhere((l) => l.product.id == productId);
    if (index < 0) return;
    _lines[index] = _lines[index].copyWith(quantity: quantity);
    notifyListeners();
  }

  void removeProduct(String productId) {
    _lines.removeWhere((l) => l.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
