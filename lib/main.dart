import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'features/customers/customers_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/inventory/inventory_page.dart';
import 'features/pos/pos_page.dart';
import 'features/reports/reports_page.dart';
import 'features/suppliers/suppliers_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppDatabase.instance.database;
  } catch (_) {
    // Ignore database init errors during tests
  }

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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const PosPage(),
      const InventoryPage(),
      const CustomersPage(),
      const SuppliersPage(),
      const ReportsPage(),
      const _PlaceholderPage(
        icon: Icons.auto_awesome_outlined,
        title: 'Assistant',
      ),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
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
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Assistant',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PlaceholderPage({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Module ready for implementation'),
          ],
        ),
      ),
    );
  }
}
