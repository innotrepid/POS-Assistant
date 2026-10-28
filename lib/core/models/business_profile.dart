/// Business profiles = UX configuration over one shared engine.

enum BusinessProfileId {
  mamaMboga,
  duka,
  kiosk,
  butchery,
  restaurant,
  pharmacy,
  hardware,
  clothing,
  electronics,
  wholesale,
  supermarket,
  multiBranch,
  administrator,
}

enum InterfaceLevel {
  simple,
  simplePlus,
  operational,
  operationalPlus,
  controlled,
  advanced,
  management,
  full,
}

class ProfileFeatures {
  final bool sales;
  final bool stock;
  final bool customers;
  final bool suppliers;
  final bool reports;
  final bool expenses;
  final bool dayClose;
  final bool discounts;
  final bool creditSales;
  final bool mpesa;
  final bool splitPayments;
  final bool barcodes;
  final bool categories;
  final bool weightSales;
  final bool batchesExpiry;
  final bool variants;
  final bool serialTracking;
  final bool quotations;
  final bool multiUser;
  final bool branches;
  final bool advancedAudit;
  final bool produceUnits;
  final bool spoilage;
  final bool marketRestock;

  const ProfileFeatures({
    this.sales = true,
    this.stock = true,
    this.customers = true,
    this.suppliers = false,
    this.reports = true,
    this.expenses = true,
    this.dayClose = true,
    this.discounts = true,
    this.creditSales = true,
    this.mpesa = true,
    this.splitPayments = false,
    this.barcodes = false,
    this.categories = false,
    this.weightSales = false,
    this.batchesExpiry = false,
    this.variants = false,
    this.serialTracking = false,
    this.quotations = false,
    this.multiUser = false,
    this.branches = false,
    this.advancedAudit = false,
    this.produceUnits = false,
    this.spoilage = false,
    this.marketRestock = false,
  });

  /// Focus profile for Kenyan fresh-produce stalls.
  static const mamaMboga = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: false,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
    splitPayments: true,
    barcodes: false,
    categories: false,
    weightSales: true,
    produceUnits: true,
    spoilage: true,
    marketRestock: true,
  );

  static const simpleCore = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: false,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
  );

  static const simplePlus = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: true,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
    splitPayments: true,
    barcodes: true,
    categories: true,
  );

  static const operational = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: true,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
    splitPayments: true,
    barcodes: true,
    categories: true,
    weightSales: true,
  );

  static const controlled = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: true,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
    splitPayments: true,
    barcodes: true,
    categories: true,
    batchesExpiry: true,
    advancedAudit: true,
  );

  static const advanced = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: true,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
    splitPayments: true,
    barcodes: true,
    categories: true,
    weightSales: true,
    variants: true,
    quotations: true,
    advancedAudit: true,
  );

  static const full = ProfileFeatures(
    sales: true,
    stock: true,
    customers: true,
    suppliers: true,
    reports: true,
    expenses: true,
    dayClose: true,
    discounts: true,
    creditSales: true,
    mpesa: true,
    splitPayments: true,
    barcodes: true,
    categories: true,
    weightSales: true,
    batchesExpiry: true,
    variants: true,
    serialTracking: true,
    quotations: true,
    multiUser: true,
    branches: true,
    advancedAudit: true,
  );
}

class BusinessProfile {
  final BusinessProfileId id;
  final String label;
  final String description;
  final String defaultUnit;
  final List<String> suggestedUnits;
  final InterfaceLevel interfaceLevel;
  final ProfileFeatures features;
  final bool defaultTrackBatches;
  final bool defaultHasExpiry;
  final bool enabled;

  const BusinessProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.defaultUnit,
    this.suggestedUnits = const ['piece'],
    required this.interfaceLevel,
    required this.features,
    this.defaultTrackBatches = false,
    this.defaultHasExpiry = false,
    this.enabled = true,
  });

  static const List<BusinessProfile> all = [
    BusinessProfile(
      id: BusinessProfileId.mamaMboga,
      label: 'Mama mboga / fresh produce',
      description:
          'Sell by kg, bunch, heap or piece. Own stock only — no Suppliers tab. '
          'Cash, M-Pesa, split pay, customer credit, spoilage and day close.',
      defaultUnit: 'kg',
      suggestedUnits: [
        'kg',
        'g',
        'bunch',
        'heap',
        'piece',
        'bag',
        'debe',
        'gorogoro',
        'dozen',
        'crate',
        'sachet',
        'litre',
      ],
      interfaceLevel: InterfaceLevel.simple,
      features: ProfileFeatures.mamaMboga,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.duka,
      label: 'Small shop / duka',
      description: 'Coming later — focusing on Mama mboga first.',
      defaultUnit: 'piece',
      suggestedUnits: ['piece', 'pack', 'dozen'],
      interfaceLevel: InterfaceLevel.simplePlus,
      features: ProfileFeatures.simplePlus,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.kiosk,
      label: 'Kiosk / convenience',
      description: 'Coming later — focusing on Mama mboga first.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.simplePlus,
      features: ProfileFeatures.simplePlus,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.butchery,
      label: 'Butchery',
      description: 'Coming later — focusing on Mama mboga first.',
      defaultUnit: 'kg',
      suggestedUnits: ['kg', 'piece', 'portion'],
      interfaceLevel: InterfaceLevel.operational,
      features: ProfileFeatures.operational,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.restaurant,
      label: 'Restaurant / food',
      description: 'Coming later.',
      defaultUnit: 'portion',
      interfaceLevel: InterfaceLevel.operational,
      features: ProfileFeatures.operational,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.pharmacy,
      label: 'Pharmacy / health retail',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.controlled,
      features: ProfileFeatures.controlled,
      defaultTrackBatches: true,
      defaultHasExpiry: true,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.hardware,
      label: 'Hardware / building supplies',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.operationalPlus,
      features: ProfileFeatures.advanced,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.clothing,
      label: 'Boutique / clothing',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.operational,
      features: ProfileFeatures.advanced,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.electronics,
      label: 'Electronics / phone shop',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.advanced,
      features: ProfileFeatures.advanced,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.wholesale,
      label: 'Wholesale / distributor',
      description: 'Coming later.',
      defaultUnit: 'carton',
      suggestedUnits: ['carton', 'dozen', 'piece', 'bag'],
      interfaceLevel: InterfaceLevel.advanced,
      features: ProfileFeatures.advanced,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.supermarket,
      label: 'Supermarket / large retail',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.advanced,
      features: ProfileFeatures.full,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.multiBranch,
      label: 'Multi-branch business',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.management,
      features: ProfileFeatures.full,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.administrator,
      label: 'Business owner / administrator',
      description: 'Coming later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.full,
      features: ProfileFeatures.full,
      enabled: false,
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
    if (raw == 'miniMarket') {
      return byId(BusinessProfileId.kiosk);
    }
    return null;
  }
}

class ProfileCopy {
  static String stockLeft(String name, double qty, String unit) {
    final q = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
    return 'You have $q $unit of $name left.';
  }

  static String belowCost(String name, double cost, double sell) {
    return 'You bought $name at ${_m(cost)} and are selling at ${_m(sell)}.';
  }

  static String customerOwes(String name, double amount) {
    return '$name owes you ${_m(amount)}.';
  }

  static String mpesaRefNeeded() {
    return 'M-Pesa reference is needed to finish this sale.';
  }

  static String discountCutsProfit() {
    return 'This discount will reduce your profit.';
  }

  static String _m(double v) {
    return 'KSh ${v.toStringAsFixed(2)}';
  }
}
