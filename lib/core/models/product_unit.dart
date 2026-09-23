/// A selling unit for a product, with conversion to the product's base unit.
///
/// Inventory is always tracked in [Product.unit] (the base unit).
/// When selling in an alternate unit, quantity is converted via
/// [conversionToBase] before stock is deducted.
///
/// Example (tomatoes, base unit = piece):
/// - piece  → conversionToBase 1,  sellingPrice 10
/// - kg     → conversionToBase 10, sellingPrice 80  (approx 10 pieces per kg)
/// - heap   → conversionToBase 5,  sellingPrice 40
class ProductUnit {
  final String id;
  final String productId;
  final String unitName;
  /// How many base units equal 1 of this unit.
  /// Must be > 0. For the base unit itself this is always 1.
  final double conversionToBase;
  final double sellingPrice;
  final bool isDefault;
  final String? barcode;
  final int sortOrder;
  final DateTime createdAt;

  const ProductUnit({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.conversionToBase,
    required this.sellingPrice,
    this.isDefault = false,
    this.barcode,
    this.sortOrder = 0,
    required this.createdAt,
  });

  /// Quantity in base units for a given sold quantity in this unit.
  double toBaseQuantity(double soldQuantity) =>
      soldQuantity * conversionToBase;

  /// Quantity in this unit for a given base quantity.
  double fromBaseQuantity(double baseQuantity) =>
      conversionToBase == 0 ? 0 : baseQuantity / conversionToBase;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'conversion_to_base': conversionToBase,
      'selling_price': sellingPrice,
      'is_default': isDefault ? 1 : 0,
      'barcode': barcode,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      unitName: map['unit_name'] as String,
      conversionToBase: (map['conversion_to_base'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      isDefault: (map['is_default'] as int?) == 1,
      barcode: map['barcode'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  ProductUnit copyWith({
    String? unitName,
    double? conversionToBase,
    double? sellingPrice,
    bool? isDefault,
    String? barcode,
    int? sortOrder,
  }) {
    return ProductUnit(
      id: id,
      productId: productId,
      unitName: unitName ?? this.unitName,
      conversionToBase: conversionToBase ?? this.conversionToBase,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      isDefault: isDefault ?? this.isDefault,
      barcode: barcode ?? this.barcode,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'ProductUnit($unitName, conv=$conversionToBase, price=$sellingPrice, default=$isDefault)';
}
