import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'features/security/lock_screen.dart';
import 'features/settings/settings_page.dart';
import 'features/suppliers/suppliers_page.dart';
import 'services/alert_scanner_service.dart';
import 'services/backup_service.dart';
import 'services/business_profile_service.dart';
import 'services/locale_service.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/system_notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\\n$stack');
    return true;
  };
  try {
    await AppDatabase.instance.metaDatabase;
    final profiles = BusinessProfileService.instance;
    if (await profiles.hasCompletedOnboarding()) {
      // Backfill legacy installations without touching their business DBs.
      await profiles.ensureBusinessId();
      final id = await profiles.getProfileId();
      await AppDatabase.instance.useProfile(id);
    }
  } catch (error, stack) {
    debugPrint('Business identity bootstrap deferred: $error\\n$stack');
  }
  await themeController.load();
  await localeController.load();
  try {
    await SystemNotificationService.instance.init();
  } catch (_) {}
  try {
    final profiles = BusinessProfileService.instance;
    if (await profiles.hasCompletedOnboarding()) {
      await BackupService().runDailyIfNeeded();
    }
  } catch (_) {}
  runApp(const MercateApp());
}

class MercateApp extends StatelessWidget {
  const MercateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) {
        final s = localeController.s;
        return MaterialApp(
          title: s.appName,
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
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
  final _security = SecurityService();
  bool _loading = true;
  bool _needsOnboarding = false;
  bool _needsUnlock = false;
  bool _startupFailed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _retryStartup() async {
    setState(() {
      _startupFailed = false;
      _loading = true;
    });
    await _check();
  }

  Future<void> _check() async {
    try {
      final done = await _profiles.hasCompletedOnboarding();
      if (!mounted) return;
      if (done) {
        // Keep identity creation independent of PIN/biometric security.
        await _profiles.ensureBusinessId();
        final id = await _profiles.getProfileId();
        await AppDatabase.instance.useProfile(id);
        final lockOn = await _security.isLockEnabled();
        final hasPin = await _security.hasPin();
        setState(() {
          _needsOnboarding = false;
          _needsUnlock = lockOn && hasPin;
          _loading = false;
        });
      } else {
        setState(() {
          _needsOnboarding = true;
          _needsUnlock = false;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint('Startup gate check failed: $error');
      setState(() {
        // Never send an existing customer through onboarding after a storage
        // or identity error; show a retry path instead.
        _startupFailed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_startupFailed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 12),
                const Text('Mercate could not open your business data.'),
                const SizedBox(height: 8),
                const Text('Your records have not been changed. Check storage and retry.'),
                const SizedBox(height: 16),
                FilledButton(onPressed: _retryStartup, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    if (_needsOnboarding) {
      return OnboardingPage(
        onCompleted: () {
          setState(() {
            _needsOnboarding = false;
            _needsUnlock = false;
          });
        },
      );
    }
    if (_needsUnlock) {
      return LockScreen(
        onUnlocked: () {
          setState(() => _needsUnlock = false);
        },
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
    localeController.addListener(_onLocaleChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _profiles.removeListener(_onProfileChanged);
    localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _onProfileChanged() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final profile = await _profiles.getProfile();
      final unread = await _notifications.unreadCount();
      await _scanner.scan();
      final unread2 = await _notifications.unreadCount();
      if (!mounted) return;
      setState(() {
        _features = profile.features;
        _profileId = profile.id.name;
        _dbGeneration++;
        _unread = unread2 > 0 ? unread2 : unread;
        selectedIndex = 0;
      });
    } catch (_) {}
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => const NotificationsPage(),
        ))
        .then((_) async {
      final n = await _notifications.unreadCount();
      if (mounted) setState(() => _unread = n);
    });
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()))
        .then((_) => _bootstrap());
  }

  void _openAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AssistantPage()),
    );
  }

  List<_NavItem> _items() {
    final s = localeController.s;
    return [
      _NavItem(
        id: 'home',
        page: DashboardPage(
          unreadCount: _unread,
          onOpenNotifications: _openNotifications,
          onOpenAssistant: _openAssistant,
          onOpenSettings: _openSettings,
          onRefreshShell: _bootstrap,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: s.home,
        ),
        visible: (_) => true,
      ),
      _NavItem(
        id: 'pos',
        page: const PosPage(),
        destination: NavigationDestination(
          icon: const Icon(Icons.point_of_sale_outlined),
          selectedIcon: const Icon(Icons.point_of_sale),
          label: s.sell,
        ),
        visible: (f) => f.sales,
      ),
      _NavItem(
        id: 'stock',
        page: InventoryPage(
          unreadCount: _unread,
          onOpenNotifications: _openNotifications,
        ),
        destination: NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: s.stock,
        ),
        visible: (f) => f.stock,
      ),
      _NavItem(
        id: 'customers',
        page: const CustomersPage(),
        destination: NavigationDestination(
          icon: const Icon(Icons.people_outline),
          selectedIcon: const Icon(Icons.people),
          label: s.customers,
        ),
        visible: (f) => f.customers,
      ),
      _NavItem(
        id: 'suppliers',
        page: const SuppliersPage(),
        destination: NavigationDestination(
          icon: const Icon(Icons.local_shipping_outlined),
          selectedIcon: const Icon(Icons.local_shipping),
          label: s.suppliers,
        ),
        visible: (f) => f.suppliers,
      ),
      _NavItem(
        id: 'reports',
        page: const ReportsPage(),
        destination: NavigationDestination(
          icon: const Icon(Icons.bar_chart_outlined),
          selectedIcon: const Icon(Icons.bar_chart),
          label: s.reports,
        ),
        visible: (f) => f.reports,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = _items();
    final visible = all.where((i) => i.visible(_features)).toList();
    if (selectedIndex >= visible.length) selectedIndex = 0;
    final currentId = visible.isEmpty ? 'home' : visible[selectedIndex].id;
    final showAssistantFab = currentId != 'pos';
    final s = localeController.s;

    return Scaffold(
      extendBody: true,
      body: GlassScaffoldBody(
        child: KeyedSubtree(
          key: ValueKey('profile-$_profileId-$_dbGeneration'),
          child: visible.isEmpty
              ? const Center(child: Text('No tabs for this profile'))
              : visible[selectedIndex].page,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: showAssistantFab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton(
                heroTag: 'assistant_fab',
                onPressed: _openAssistant,
                tooltip: s.assistant,
                child: const Icon(Icons.auto_awesome),
              ),
            )
          : null,
      bottomNavigationBar: visible.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: [for (final item in visible) item.destination],
            ),
    );
  }
}
