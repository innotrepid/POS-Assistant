import '../../core/models/product.dart';
import '../../core/models/product_unit.dart';
import '../../core/utils/money.dart';

/// One line in the POS cart (catalogue product or quick sale).
class CartLine {
  final Product? product;
  final String name;
  /// Quantity in the chosen selling unit.
  final double quantity;
  final double unitPrice;
  final double discount;
  final bool isQuickSale;

  /// Selling unit name (e.g. piece, kg). Null for quick sales.
  final String? unitName;

  /// How many base units = 1 of [unitName]. Defaults to 1.
  final double conversionToBase;

  const CartLine({
    this.product,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.isQuickSale = false,
    this.unitName,
    this.conversionToBase = 1.0,
  });

  /// Catalogue line using product default price/unit (no ProductUnit loaded).
  factory CartLine.fromProduct(Product product, {double quantity = 1}) {
    return CartLine(
      product: product,
      name: product.name,
      quantity: quantity,
      unitPrice: product.sellingPrice,
      isQuickSale: false,
      unitName: product.unit,
      conversionToBase: 1.0,
    );
  }

  /// Catalogue line with an explicit selling unit (multi-UoM).
  factory CartLine.fromProductUnit({
    required Product product,
    required ProductUnit unit,
    double quantity = 1,
  }) {
    return CartLine(
      product: product,
      name: product.name,
      quantity: quantity,
      unitPrice: unit.sellingPrice,
      isQuickSale: false,
      unitName: unit.unitName,
      conversionToBase: unit.conversionToBase,
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
      unitName: null,
      conversionToBase: 1.0,
    );
  }

  /// Quantity to deduct from stock (always in product base unit).
  double get baseQuantity => quantity * conversionToBase;

  /// Unique cart key: product + unit so piece and kg are separate lines.
  String get lineKey {
    if (isQuickSale) {
      return 'quick:${name.toLowerCase()}:$unitPrice';
    }
    final u = (unitName ?? product?.unit ?? 'piece').toLowerCase();
    return '${product!.id}::$u';
  }

  double get lineTotal => Money.round((quantity * unitPrice) - discount);

  String get displayUnit => unitName ?? product?.unit ?? '';

  CartLine copyWith({
    double? quantity,
    double? unitPrice,
    double? discount,
    String? unitName,
    double? conversionToBase,
  }) {
    return CartLine(
      product: product,
      name: name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      isQuickSale: isQuickSale,
      unitName: unitName ?? this.unitName,
      conversionToBase: conversionToBase ?? this.conversionToBase,
    );
  }
}
