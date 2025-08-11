import 'package:flutter/material.dart';
import 'products_page.dart';
import 'customers_page.dart';
import 'sales_page.dart';
import 'reports_page.dart';
import 'sales_history_page.dart';
import 'top_customers_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PoppersCUV2 — Inventario & Ventas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
                    const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.leaderboard),
            label: const Text('Top clientes'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TopCustomersPage()),
            ),
          ),
ElevatedButton.icon(
            icon: const Icon(Icons.inventory_2),
            label: const Text('Inventario'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsPage())),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.people_alt),
            label: const Text('Clientes'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersPage())),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Ventas (POS)'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesPage())),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('Historial de ventas'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryPage())),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('Reportes / CSV'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
          ),
        ],
      ),
    );
  }
}
