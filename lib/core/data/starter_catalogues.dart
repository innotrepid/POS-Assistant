import '../models/business_profile.dart';

/// Seed product definition for first-run catalogues.
class StarterProduct {
  final String name;
  final String unit;
  final double sellingPrice;
  final double? costPrice;
  final double minimumStock;

  const StarterProduct({
    required this.name,
    required this.unit,
    required this.sellingPrice,
    this.costPrice,
    this.minimumStock = 0,
  });
}

/// Kenya-focused starter lists. Prices are indicative stall defaults (KES).
/// Many stalls sell by debe / gorogoro as well as kg — both units are used.
class StarterCatalogues {
  StarterCatalogues._();

  static List<StarterProduct> forProfile(BusinessProfileId id) {
    switch (id) {
      case BusinessProfileId.mamaMboga:
        return mamaMboga;
      case BusinessProfileId.kiosk:
      case BusinessProfileId.duka:
        return dukaBasics;
      default:
        return const [];
    }
  }

  /// Fresh produce stall — Wakulima / Marikiti / roadside style.
  static const List<StarterProduct> mamaMboga = [
    StarterProduct(name: 'Sukuma wiki', unit: 'bunch', sellingPrice: 20, costPrice: 10, minimumStock: 5),
    StarterProduct(name: 'Spinach', unit: 'bunch', sellingPrice: 20, costPrice: 10, minimumStock: 5),
    StarterProduct(name: 'Managu', unit: 'bunch', sellingPrice: 30, costPrice: 15, minimumStock: 3),
    StarterProduct(name: 'Terere', unit: 'bunch', sellingPrice: 30, costPrice: 15, minimumStock: 3),
    StarterProduct(name: 'Dhania', unit: 'bunch', sellingPrice: 10, costPrice: 5, minimumStock: 5),
    StarterProduct(name: 'Tomato (kg)', unit: 'kg', sellingPrice: 80, costPrice: 50, minimumStock: 3),
    StarterProduct(name: 'Tomato (debe)', unit: 'debe', sellingPrice: 250, costPrice: 180, minimumStock: 1),
    StarterProduct(name: 'Onion (kg)', unit: 'kg', sellingPrice: 100, costPrice: 60, minimumStock: 3),
    StarterProduct(name: 'Onion (debe)', unit: 'debe', sellingPrice: 300, costPrice: 220, minimumStock: 1),
    StarterProduct(name: 'Potato (kg)', unit: 'kg', sellingPrice: 60, costPrice: 35, minimumStock: 5),
    StarterProduct(name: 'Potato (debe)', unit: 'debe', sellingPrice: 200, costPrice: 140, minimumStock: 1),
    StarterProduct(name: 'Carrot (kg)', unit: 'kg', sellingPrice: 80, costPrice: 50, minimumStock: 2),
    StarterProduct(name: 'Carrot (debe)', unit: 'debe', sellingPrice: 220, costPrice: 160, minimumStock: 1),
    StarterProduct(name: 'Cabbage', unit: 'head', sellingPrice: 50, costPrice: 30, minimumStock: 2),
    StarterProduct(name: 'Green maize', unit: 'piece', sellingPrice: 20, costPrice: 10, minimumStock: 10),
    StarterProduct(name: 'Maize grains (debe)', unit: 'debe', sellingPrice: 180, costPrice: 130, minimumStock: 1),
    StarterProduct(name: 'Beans (debe)', unit: 'debe', sellingPrice: 350, costPrice: 280, minimumStock: 1),
    StarterProduct(name: 'Beans (kg)', unit: 'kg', sellingPrice: 150, costPrice: 120, minimumStock: 2),
    StarterProduct(name: 'Ndengu (debe)', unit: 'debe', sellingPrice: 400, costPrice: 320, minimumStock: 1),
    StarterProduct(name: 'Capsicum', unit: 'kg', sellingPrice: 150, costPrice: 100, minimumStock: 1),
    StarterProduct(name: 'Cucumber', unit: 'piece', sellingPrice: 20, costPrice: 10, minimumStock: 5),
    StarterProduct(name: 'Avocado', unit: 'piece', sellingPrice: 30, costPrice: 15, minimumStock: 5),
    StarterProduct(name: 'Banana (ripe)', unit: 'piece', sellingPrice: 10, costPrice: 5, minimumStock: 10),
    StarterProduct(name: 'Banana (cooking)', unit: 'piece', sellingPrice: 15, costPrice: 8, minimumStock: 10),
    StarterProduct(name: 'Orange', unit: 'piece', sellingPrice: 20, costPrice: 10, minimumStock: 8),
    StarterProduct(name: 'Mango', unit: 'piece', sellingPrice: 30, costPrice: 15, minimumStock: 5),
    StarterProduct(name: 'Ginger', unit: 'kg', sellingPrice: 200, costPrice: 120, minimumStock: 1),
    StarterProduct(name: 'Garlic', unit: 'kg', sellingPrice: 250, costPrice: 150, minimumStock: 1),
    StarterProduct(name: 'Sweet potato', unit: 'kg', sellingPrice: 70, costPrice: 40, minimumStock: 3),
    StarterProduct(name: 'Cassava', unit: 'kg', sellingPrice: 50, costPrice: 30, minimumStock: 3),
    StarterProduct(name: 'Eggs', unit: 'piece', sellingPrice: 20, costPrice: 14, minimumStock: 12),
  ];

  static const List<StarterProduct> dukaBasics = [
    StarterProduct(name: 'Sugar 1kg', unit: 'pack', sellingPrice: 180, costPrice: 150, minimumStock: 5),
    StarterProduct(name: 'Maize flour 2kg', unit: 'pack', sellingPrice: 200, costPrice: 170, minimumStock: 5),
    StarterProduct(name: 'Salt', unit: 'pack', sellingPrice: 30, costPrice: 20, minimumStock: 5),
    StarterProduct(name: 'Cooking oil 1L', unit: 'piece', sellingPrice: 350, costPrice: 300, minimumStock: 3),
    StarterProduct(name: 'Bread', unit: 'piece', sellingPrice: 60, costPrice: 45, minimumStock: 5),
    StarterProduct(name: 'Milk 500ml', unit: 'piece', sellingPrice: 70, costPrice: 55, minimumStock: 6),
    StarterProduct(name: 'Eggs', unit: 'piece', sellingPrice: 20, costPrice: 14, minimumStock: 12),
    StarterProduct(name: 'Soap bar', unit: 'piece', sellingPrice: 50, costPrice: 35, minimumStock: 5),
  ];
}
