import '../core/data/starter_catalogues.dart';
import '../core/models/business_profile.dart';
import 'business_profile_service.dart';
import 'inventory_service.dart';

/// Seeds starter products for the active profile without duplicating names.
class StarterCatalogueService {
  StarterCatalogueService({
    InventoryService? inventory,
    BusinessProfileService? profiles,
  })  : _inventory = inventory ?? InventoryService(),
        _profiles = profiles ?? BusinessProfileService.instance;

  final InventoryService _inventory;
  final BusinessProfileService _profiles;

  Future<int> availableCount() async {
    final profile = await _profiles.getProfile();
    return StarterCatalogues.forProfile(profile.id).length;
  }

  /// Adds any starter items that are not already in stock (by name).
  /// Safe to run more than once — never creates a duplicate name.
  Future<int> seedIfEmpty({BusinessProfileId? profileId}) async {
    final id = profileId ?? (await _profiles.getProfile()).id;
    final seeds = StarterCatalogues.forProfile(id);
    if (seeds.isEmpty) return 0;

    final existing = await _inventory.getAllProducts(activeOnly: false);
    final existingNames = {
      for (final p in existing) p.name.trim().toLowerCase(),
    };

    var count = 0;
    for (final s in seeds) {
      final key = s.name.trim().toLowerCase();
      if (existingNames.contains(key)) continue;
      try {
        await _inventory.createProduct(
          name: s.name,
          unit: s.unit,
          sellingPrice: s.sellingPrice,
          costPrice: s.costPrice,
          minimumStock: s.minimumStock,
        );
        existingNames.add(key);
        count++;
      } catch (_) {
        // Race or concurrent create — skip
      }
    }
    return count;
  }

  /// How many starter items are still missing from inventory.
  Future<int> missingCount({BusinessProfileId? profileId}) async {
    final id = profileId ?? (await _profiles.getProfile()).id;
    final seeds = StarterCatalogues.forProfile(id);
    if (seeds.isEmpty) return 0;
    final existing = await _inventory.getAllProducts(activeOnly: false);
    final existingNames = {
      for (final p in existing) p.name.trim().toLowerCase(),
    };
    return seeds
        .where((s) => !existingNames.contains(s.name.trim().toLowerCase()))
        .length;
  }
}
