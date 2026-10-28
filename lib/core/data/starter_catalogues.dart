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

  /// Fresh produce stall — Wakulima/Marikiti style.
  static const List<StarterProduct> mamaMboga = [
    StarterProduct(
      name: 'Sukuma wiki',
      unit: 'bunch',
      sellingPrice: 20,
      costPrice: 10,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Tomato',
      unit: 'kg',
      sellingPrice: 80,
      costPrice: 50,
      minimumStock: 3,
    ),
    StarterProduct(
      name: 'Onion',
      unit: 'kg',
      sellingPrice: 100,
      costPrice: 60,
      minimumStock: 3,
    ),
    StarterProduct(
      name: 'Dhania',
      unit: 'bunch',
      sellingPrice: 10,
      costPrice: 5,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Cabbage',
      unit: 'head',
      sellingPrice: 50,
      costPrice: 30,
      minimumStock: 2,
    ),
    StarterProduct(
      name: 'Potato',
      unit: 'kg',
      sellingPrice: 60,
      costPrice: 35,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Spinach',
      unit: 'bunch',
      sellingPrice: 20,
      costPrice: 10,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Carrot',
      unit: 'kg',
      sellingPrice: 80,
      costPrice: 45,
      minimumStock: 2,
    ),
    StarterProduct(
      name: 'Green maize',
      unit: 'piece',
      sellingPrice: 20,
      costPrice: 10,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Avocado',
      unit: 'piece',
      sellingPrice: 30,
      costPrice: 15,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Banana',
      unit: 'kg',
      sellingPrice: 50,
      costPrice: 30,
      minimumStock: 3,
    ),
    StarterProduct(
      name: 'Capsicum',
      unit: 'kg',
      sellingPrice: 150,
      costPrice: 90,
      minimumStock: 1,
    ),
    StarterProduct(
      name: 'Eggs',
      unit: 'piece',
      sellingPrice: 20,
      costPrice: 14,
      minimumStock: 12,
    ),
    StarterProduct(
      name: 'Cooking oil (sachet)',
      unit: 'piece',
      sellingPrice: 30,
      costPrice: 22,
      minimumStock: 6,
    ),
  ];

  static const List<StarterProduct> dukaBasics = [
    StarterProduct(
      name: 'Sugar 1kg',
      unit: 'pack',
      sellingPrice: 180,
      costPrice: 150,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Maize flour 2kg',
      unit: 'pack',
      sellingPrice: 200,
      costPrice: 170,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Salt',
      unit: 'pack',
      sellingPrice: 30,
      costPrice: 20,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Cooking oil 1L',
      unit: 'piece',
      sellingPrice: 350,
      costPrice: 300,
      minimumStock: 3,
    ),
    StarterProduct(
      name: 'Bread',
      unit: 'piece',
      sellingPrice: 60,
      costPrice: 45,
      minimumStock: 5,
    ),
    StarterProduct(
      name: 'Milk 500ml',
      unit: 'piece',
      sellingPrice: 70,
      costPrice: 55,
      minimumStock: 6,
    ),
    StarterProduct(
      name: 'Eggs',
      unit: 'piece',
      sellingPrice: 20,
      costPrice: 14,
      minimumStock: 12,
    ),
    StarterProduct(
      name: 'Soap bar',
      unit: 'piece',
      sellingPrice: 50,
      costPrice: 35,
      minimumStock: 5,
    ),
  ];
}
