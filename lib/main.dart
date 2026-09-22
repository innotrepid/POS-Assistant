import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'core/models/business_profile.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/assistant_page.dart';
import 'features/customers/customers_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/inventory/inventory_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/pos/pos_page.dart';
import 'features/reports/reports_page.dart';
import 'features/settings/settings_page.dart';
import 'features/suppliers/suppliers_page.dart';
import 'services/alert_scanner_service.dart';
import 'services/business_profile_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

final themeController = ThemeController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppDatabase.instance.metaDatabase;
    final profiles = BusinessProfileService.instance;
    if (await profiles.hasCompletedOnboarding()) {
      final id = await profiles.getProfileId();
      await AppDatabase.instance.useProfile(id);
    }
  } catch (_) {}
  await themeController.load();
  runApp(const MercateApp());
}

class MercateApp extends StatelessWidget {
  const MercateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Mercate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.mode,
          home: const _RootGate(),
        );
      },
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  final _profiles = BusinessProfileService.instance;
  bool _loading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final done = await _profiles.hasCompletedOnboarding();
      if (!mounted) return;
      if (done) {
        final id = await _profiles.getProfileId();
        await AppDatabase.instance.useProfile(id);
        setState(() {
          _needsOnboarding = false;
          _loading = false;
        });
      } else {
        setState(() {
          _needsOnboarding = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _needsOnboarding = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsOnboarding) {
      return OnboardingPage(
        onCompleted: () => setState(() => _needsOnboarding = false),
      );
    }
    return const AppShell();
  }
}

class _NavItem {
  final String id;
  final Widget page;
  final NavigationDestination destination;
  final bool Function(ProfileFeatures f) visible;

  const _NavItem({
    required this.id,
    required this.page,
    required this.destination,
    required this.visible,
  });
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  ProfileFeatures _features = ProfileFeatures.simpleCore;
  String _profileId = 'duka';
  int _dbGeneration = 0;
  int _unread = 0;
  final _profiles = BusinessProfileService.instance;
  final _notifications = NotificationService();
  final _scanner = AlertScannerService();

  @override
  void initState() {
    super.initState();
    _profiles.addListener(_onProfileChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _profiles.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final p = await _profiles.getProfile();
      final gen = AppDatabase.instance.generation;
      if (mounted) {
        setState(() {
          _features = p.features;
          _profileId = p.id.name;
          _dbGeneration = gen;
          selectedIndex = 0;
        });
      }
    } catch (_) {}
    try {
      await _scanner.scan();
    } catch (_) {}
    await _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final c = await _notifications.unreadCount();
      if (mounted) setState(() => _unread = c);
    } catch (_) {}
  }

  void _openSettings() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
        )
        .then((_) => _onProfileChanged());
  }

  void _openAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AssistantPage()),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    );
    _refreshUnread();
  }

  List<_NavItem> _items() {
    return [
      _NavItem(
        id: 'home',
        page: DashboardPage(
          unreadCount: _unread,
          onOpenNotifications: _openNotifications,
          onOpenAssistant: _openAssistant,
          onOpenSettings: _openSettings,
        ),
        destination: const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        visible: (_) => true,
      ),
      _NavItem(
        id: 'pos',
        page: PosPage(
          onSaleCompleted: _bootstrap,
          onOpenAssistant: _openAssistant,
          onOpenNotifications: _openNotifications,
          unreadCount: _unread,
        ),
        destination: const NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: 'POS',
        ),
        visible: (f) => f.sales,
      ),
      _NavItem(
        id: 'stock',
        page: InventoryPage(
          unreadCount: _unread,
          onOpenNotifications: _openNotifications,
        ),
        destination: const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Stock',
        ),
        visible: (f) => f.stock,
      ),
      _NavItem(
        id: 'customers',
        page: const CustomersPage(),
        destination: const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Customers',
        ),
        visible: (f) => f.customers,
      ),
      _NavItem(
        id: 'suppliers',
        page: const SuppliersPage(),
        destination: const NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: 'Suppliers',
        ),
        visible: (f) => f.suppliers,
      ),
      _NavItem(
        id: 'reports',
        page: const ReportsPage(),
        destination: const NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        visible: (f) => f.reports,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = _items();
    final visible = all.where((i) => i.visible(_features)).toList();
    if (selectedIndex >= visible.length) {
      selectedIndex = 0;
    }

    final currentId = visible.isEmpty ? 'home' : visible[selectedIndex].id;
    final showAssistantFab = currentId != 'pos';

    return Scaffold(
      extendBody: true,
      body: GlassScaffoldBody(
        // Force full page rebuild when profile/DB switches — prevents stale State
        // showing products from another profile.
        child: KeyedSubtree(
          key: ValueKey('profile-$_profileId-$_dbGeneration'),
          child: visible.isEmpty
              ? const Center(child: Text('No tabs for this profile'))
              : visible[selectedIndex].page,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: showAssistantFab
          ? FloatingActionButton(
              heroTag: 'assistant_fab',
              onPressed: _openAssistant,
              tooltip: 'Assistant',
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      bottomNavigationBar: visible.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: [for (final i in visible) i.destination],
            ),
    );
  }
}
