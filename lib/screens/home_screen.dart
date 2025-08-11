import 'package:flutter/material.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [
    InventoryScreen(),
    SalesScreen(),
    ReportsScreen(),
  ];

  final _titles = const [
    'Inventario',
    'Ventas',
    'Reportes',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'Ventas'),
          NavigationDestination(icon: Icon(Icons.summarize_outlined), label: 'Reportes'),
        ],
      ),
    );
  }
}