/// Shop type presets — change defaults, not a separate app.
enum BusinessProfileId {
  duka,
  mamaMboga,
  miniMarket,
  wholesale,
  hardware,
  clothing,
  pharmacy,
  restaurant,
}

class BusinessProfile {
  final BusinessProfileId id;
  final String label;
  final String description;
  final String defaultUnit;
  final bool defaultTrackBatches;
  final bool defaultHasExpiry;
  final bool enabled;

  const BusinessProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.defaultUnit,
    this.defaultTrackBatches = false,
    this.defaultHasExpiry = false,
    this.enabled = true,
  });

  static const List<BusinessProfile> all = [
    BusinessProfile(
      id: BusinessProfileId.duka,
      label: 'Duka / general retail',
      description:
          'Everyday shop: pieces, optional barcode, simple stock. Default profile.',
      defaultUnit: 'piece',
    ),
    BusinessProfile(
      id: BusinessProfileId.mamaMboga,
      label: 'Mama mboga / produce',
      description:
          'Fresh produce: weight-friendly units (kg), less barcode focus.',
      defaultUnit: 'kg',
    ),
    BusinessProfile(
      id: BusinessProfileId.miniMarket,
      label: 'Mini-market',
      description:
          'More categories and stock discipline; still simple units.',
      defaultUnit: 'piece',
    ),
    BusinessProfile(
      id: BusinessProfileId.wholesale,
      label: 'Wholesale shop',
      description:
          'Bulk focus: cartons/bags as default unit (conversions later).',
      defaultUnit: 'carton',
    ),
    BusinessProfile(
      id: BusinessProfileId.hardware,
      label: 'Hardware shop',
      description: 'Sizes and brands; expiry usually off.',
      defaultUnit: 'piece',
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.clothing,
      label: 'Clothing shop',
      description: 'Variants (size/colour) come later; piece units for now.',
      defaultUnit: 'piece',
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.pharmacy,
      label: 'Pharmacy / chemist',
      description:
          'Strict batches and expiry — enable when you are ready for compliance.',
      defaultUnit: 'piece',
      defaultTrackBatches: true,
      defaultHasExpiry: true,
      enabled: false, // later
    ),
    BusinessProfile(
      id: BusinessProfileId.restaurant,
      label: 'Restaurant / café',
      description: 'Recipes and modifiers — later stage.',
      defaultUnit: 'portion',
      enabled: false, // later
    ),
  ];

  static BusinessProfile byId(BusinessProfileId id) {
    return all.firstWhere((p) => p.id == id, orElse: () => all.first);
  }

  static BusinessProfile? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final p in all) {
      if (p.id.name == raw) return p;
    }
    return null;
  }
}
