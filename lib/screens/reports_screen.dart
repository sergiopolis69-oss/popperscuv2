import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Future<Map<String, dynamic>> _load() async {
    final rows = await DBHelper.instance.getSalesWithDetails();
    double utilidad = 0;
    final topProducts = <String, int>{};
    final topClients = <String, int>{};

    for (final r in rows) {
      utilidad += ((r['utility'] as num?) ?? 0).toDouble();
      final pname = (r['product_name'] ?? '').toString();
      final cname = (r['client'] ?? '—').toString();
      topProducts[pname] = (topProducts[pname] ?? 0) + (r['quantity'] as int? ?? 0);
      topClients[cname] = (topClients[cname] ?? 0) + 1;
    }

    List<MapEntry<String,int>> prodSorted = topProducts.entries.toList()
      ..sort((a,b)=> b.value.compareTo(a.value));
    List<MapEntry<String,int>> cliSorted = topClients.entries.toList()
      ..sort((a,b)=> b.value.compareTo(a.value));

    return {
      'utilidad': utilidad,
      'topProducts': prodSorted.take(5).toList(),
      'topClients': cliSorted.take(5).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String,dynamic>>(
        future: _load(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Utilidad total'),
                trailing: Text(d['utilidad'].toStringAsFixed(2)),
              ),
              const Divider(),
              const ListTile(title: Text('Top productos')),
              ...List<Widget>.from((d['topProducts'] as List<MapEntry<String,int>>).map((e) => ListTile(
                title: Text(e.key), trailing: Text('x${e.value}'),
              ))),
              const Divider(),
              const ListTile(title: Text('Mejores clientes')),
              ...List<Widget>.from((d['topClients'] as List<MapEntry<String,int>>).map((e) => ListTile(
                title: Text(e.key), trailing: Text('${e.value} compras'),
              ))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final path = await DBHelper.instance.exportSalesCsv();
                  await Share.shareXFiles([XFile(path)], text: 'Ventas exportadas');
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartir CSV de ventas'),
              ),
            ],
          );
        },
      ),
    );
  }
}
