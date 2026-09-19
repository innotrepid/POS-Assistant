import '../../core/models/product.dart';
import '../../core/utils/money.dart';

/// One line in the POS cart.
class CartLine {
  final Product product;
  final double quantity;
  final double unitPrice;
  final double discount;

  const CartLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
  });

  double get lineTotal => Money.round((quantity * unitPrice) - discount);

  CartLine copyWith({
    double? quantity,
    double? unitPrice,
    double? discount,
  }) {
    return CartLine(
      product: product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
    );
  }
}
