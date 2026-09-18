class Product {
  final String id;
  final String name;
  final String? alternativeName;
  final String? sku;
  final String? barcode;
  final String? categoryId;
  final String? brand;
  final String unit;
  final double sellingPrice;
  final double? costPrice;
  final double? wholesalePrice;
  final double minimumStock;
  final double reorderQuantity;
  final String? supplierId;
  final String? imagePath;
  final String? notes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.alternativeName,
    this.sku,
    this.barcode,
    this.categoryId,
    this.brand,
    this.unit = 'piece',
    this.sellingPrice = 0,
    this.costPrice,
    this.wholesalePrice,
    this.minimumStock = 0,
    this.reorderQuantity = 0,
    this.supplierId,
    this.imagePath,
    this.notes,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'alternative_name': alternativeName,
      'sku': sku,
      'barcode': barcode,
      'category_id': categoryId,
      'brand': brand,
      'unit': unit,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'wholesale_price': wholesalePrice,
      'minimum_stock': minimumStock,
      'reorder_quantity': reorderQuantity,
      'supplier_id': supplierId,
      'image_path': imagePath,
      'notes': notes,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      alternativeName: map['alternative_name'] as String?,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      categoryId: map['category_id'] as String?,
      brand: map['brand'] as String?,
      unit: map['unit'] as String? ?? 'piece',
      sellingPrice: (map['selling_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble(),
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
      minimumStock: (map['minimum_stock'] as num).toDouble(),
      reorderQuantity: (map['reorder_quantity'] as num).toDouble(),
      supplierId: map['supplier_id'] as String?,
      imagePath: map['image_path'] as String?,
      notes: map['notes'] as String?,
      active: (map['active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
