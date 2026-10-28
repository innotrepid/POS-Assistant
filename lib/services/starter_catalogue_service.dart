import '../core/data/starter_catalogues.dart';
import '../core/models/business_profile.dart';
import 'business_profile_service.dart';
import 'inventory_service.dart';

/// Seeds common products for the active business profile when stock is empty.
class StarterCatalogueService {
  StarterCatalogueService({
    InventoryService? inventory,
    BusinessProfileService? profiles,
  })  : _inventory = inventory ?? InventoryService(),
        _profiles = profiles ?? BusinessProfileService.instance;

  final InventoryService _inventory;
  final BusinessProfileService _profiles;

  /// How many starter lines the current profile would add (0 if unsupported).
  Future<int> availableCount() async {
    final profile = await _profiles.getProfile();
    return StarterCatalogues.forProfile(profile.id).length;
  }

  /// Insert starter products only when the product table is empty.
  /// Returns the number of products created.
  Future<int> seedIfEmpty({BusinessProfileId? profileId}) async {
    final existing = await _inventory.getAllProducts(activeOnly: false);
    if (existing.isNotEmpty) return 0;

    final id = profileId ?? (await _profiles.getProfile()).id;
    final seeds = StarterCatalogues.forProfile(id);
    if (seeds.isEmpty) return 0;

    var count = 0;
    for (final s in seeds) {
      await _inventory.createProduct(
        name: s.name,
        unit: s.unit,
        sellingPrice: s.sellingPrice,
        costPrice: s.costPrice,
        minimumStock: s.minimumStock,
      );
      count++;
    }
    return count;
  }
}
