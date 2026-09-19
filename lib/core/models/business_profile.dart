/// Business profiles = UX configuration over one shared engine.
/// More capable profiles expose more of the same underlying system.

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

/// Feature flags — engine always has the capability; UI decides visibility.
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
  });

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
    splitPayments: false,
    barcodes: false,
    categories: false,
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
    batchesExpiry: true,
    variants: true,
    serialTracking: true,
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
    required this.interfaceLevel,
    required this.features,
    this.defaultTrackBatches = false,
    this.defaultHasExpiry = false,
    this.enabled = true,
  });

  /// Progressive capability ladder — same engine, different exposure.
  static const List<BusinessProfile> all = [
    BusinessProfile(
      id: BusinessProfileId.mamaMboga,
      label: 'Mama mboga / fresh produce',
      description:
          'Focused shop tools: sell, stock, prices, customers, cash/M-Pesa, '
          'debts, discounts, daily sales, low-stock alerts.',
      defaultUnit: 'kg',
      interfaceLevel: InterfaceLevel.simple,
      features: ProfileFeatures.simpleCore,
    ),
    BusinessProfile(
      id: BusinessProfileId.duka,
      label: 'Small shop / duka',
      description:
          'Everything in simple, plus categories, barcodes, suppliers, '
          'basic profit, stock adjustments, customer accounts.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.simplePlus,
      features: ProfileFeatures.simplePlus,
    ),
    BusinessProfile(
      id: BusinessProfileId.kiosk,
      label: 'Kiosk / convenience',
      description:
          'Fast checkout, common products, stock alerts, M-Pesa, credit, '
          'daily summaries, reorder reminders.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.simplePlus,
      features: ProfileFeatures.simplePlus,
    ),
    BusinessProfile(
      id: BusinessProfileId.butchery,
      label: 'Butchery',
      description:
          'Weight-based sales, portions, wastage, purchase cost, margins, '
          'suppliers and customer debt.',
      defaultUnit: 'kg',
      interfaceLevel: InterfaceLevel.operational,
      features: ProfileFeatures.operational,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.restaurant,
      label: 'Restaurant / food',
      description:
          'Menu items, modifiers, kitchen flow — coming in stages. '
          'Operational stock and sales available now.',
      defaultUnit: 'portion',
      interfaceLevel: InterfaceLevel.operational,
      features: ProfileFeatures.operational,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.pharmacy,
      label: 'Pharmacy / health retail',
      description:
          'Batch and expiry tracking, controlled adjustments, detailed audit.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.controlled,
      features: ProfileFeatures.controlled,
      defaultTrackBatches: true,
      defaultHasExpiry: true,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.hardware,
      label: 'Hardware / building supplies',
      description:
          'Units, bulk quantities, quotations (later), credit limits, margins.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.operationalPlus,
      features: ProfileFeatures.advanced,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.clothing,
      label: 'Boutique / clothing',
      description:
          'Sizes and colours (variants later), SKU/barcode, discounts, history.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.operational,
      features: ProfileFeatures.advanced,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.electronics,
      label: 'Electronics / phone shop',
      description:
          'Serial/IMEI and warranties later; full inventory and margins now.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.advanced,
      features: ProfileFeatures.advanced,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.wholesale,
      label: 'Wholesale / distributor',
      description:
          'Bulk pricing, customer tiers, credit limits, purchase orders (later).',
      defaultUnit: 'carton',
      interfaceLevel: InterfaceLevel.advanced,
      features: ProfileFeatures.advanced,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.supermarket,
      label: 'Supermarket / large retail',
      description:
          'Multi-user, promotions, advanced purchasing — staged rollout.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.advanced,
      features: ProfileFeatures.full,
      enabled: true,
    ),
    BusinessProfile(
      id: BusinessProfileId.multiBranch,
      label: 'Multi-branch business',
      description:
          'Branches, transfers, consolidated reporting — management layer later.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.management,
      features: ProfileFeatures.full,
      enabled: false,
    ),
    BusinessProfile(
      id: BusinessProfileId.administrator,
      label: 'Business owner / administrator',
      description:
          'Full configuration, permissions, financial controls, audit, analytics.',
      defaultUnit: 'piece',
      interfaceLevel: InterfaceLevel.full,
      features: ProfileFeatures.full,
      enabled: true,
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
    // Legacy id from earlier versions
    if (raw == 'miniMarket') {
      return byId(BusinessProfileId.kiosk);
    }
    return null;
  }
}

/// Actionable copy — translate engine facts into operator language.
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
