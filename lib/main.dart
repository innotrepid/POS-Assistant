import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'features/assistant/assistant_page.dart';
import 'features/customers/customers_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/inventory/inventory_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/pos/pos_page.dart';
import 'features/reports/reports_page.dart';
import 'features/suppliers/suppliers_page.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppDatabase.instance.database;
  } catch (_) {}

  runApp(const POSAssistantApp());
}

class POSAssistantApp extends StatelessWidget {
  const POSAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  int _unread = 0;
  final _notifications = NotificationService();

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final c = await _notifications.unreadCount();
      if (mounted) setState(() => _unread = c);
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const PosPage(),
      const InventoryPage(),
      const CustomersPage(),
      const SuppliersPage(),
      const ReportsPage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          pages[selectedIndex],
          // Bell overlay top-right (does not depend on each page AppBar)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: IconButton(
                  tooltip: 'Notifications',
                  onPressed: _openNotifications,
                  icon: Badge(
                    isLabelVisible: _unread > 0,
                    label: Text('$_unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'assistant_fab',
        onPressed: _openAssistant,
        tooltip: 'Assistant',
        child: const Icon(Icons.auto_awesome),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
          _refreshUnread();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Suppliers',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
