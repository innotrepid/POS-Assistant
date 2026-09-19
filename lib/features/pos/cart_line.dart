import '../../core/models/product.dart';
import '../../core/utils/money.dart';

/// One line in the POS cart (catalogue product or quick sale).
class CartLine {
  final Product? product;
  final String name;
  final double quantity;
  final double unitPrice;
  final double discount;
  final bool isQuickSale;

  const CartLine({
    this.product,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.isQuickSale = false,
  });

  factory CartLine.fromProduct(Product product, {double quantity = 1}) {
    return CartLine(
      product: product,
      name: product.name,
      quantity: quantity,
      unitPrice: product.sellingPrice,
      isQuickSale: false,
    );
  }

  factory CartLine.quickSale({
    required String name,
    required double unitPrice,
    double quantity = 1,
  }) {
    return CartLine(
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      isQuickSale: true,
    );
  }

  String get lineKey =>
      isQuickSale ? 'quick:${name.toLowerCase()}:$unitPrice' : product!.id;

  double get lineTotal => Money.round((quantity * unitPrice) - discount);

  CartLine copyWith({
    double? quantity,
    double? unitPrice,
    double? discount,
  }) {
    return CartLine(
      product: product,
      name: name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      isQuickSale: isQuickSale,
    );
  }
}
