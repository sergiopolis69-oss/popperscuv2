import 'package:flutter/material.dart';
import '../utils/csv_io.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes / CSV')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exportar'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () async {
                final p = await CsvIO.exportTable('products'); setState(()=> status='Exportado: $p');
              }, child: const Text('products.csv')),
              ElevatedButton(onPressed: () async {
                final p = await CsvIO.exportTable('customers'); setState(()=> status='Exportado: $p');
              }, child: const Text('customers.csv')),
              ElevatedButton(onPressed: () async {
                final p = await CsvIO.exportTable('sales'); setState(()=> status='Exportado: $p');
              }, child: const Text('sales.csv')),
            ]),
            const Divider(height: 32),
            const Text('Importar'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () async {
                final n = await CsvIO.importProductsFromCsv();
                setState(()=> status='Productos importados: $n');
              }, child: const Text('Importar productos.csv')),
              ElevatedButton(onPressed: () async {
                final n = await CsvIO.importCustomersFromCsv();
                setState(()=> status='Clientes importados: $n');
              }, child: const Text('Importar customers.csv')),
            ]),
            const SizedBox(height: 16),
            if (status != null) Text(status!),
          ],
        ),
      ),
    );
  }
}
