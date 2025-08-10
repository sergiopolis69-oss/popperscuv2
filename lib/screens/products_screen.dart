import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> _future;
  String? _size = 'Todos';
  String? _origin = 'Todos';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Product>> _load() async {
    final rows = await DBHelper.instance.getProducts();
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<void> _importCsv() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return;
    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;
      try {
        final sku = (r[0] ?? '').toString().trim();
        if (sku.isEmpty) continue;
        final map = {
          'sku': sku,
          'name': (r[1] ?? '').toString().trim(),
          'brand': (r[2] ?? '').toString().trim(),
          'size': (r[3] ?? '').toString().trim(),
          'origin': (r[4] ?? '').toString().trim(),
          'cost': (r[5] is num) ? (r[5] as num).toDouble() : double.tryParse(r[5].toString()) ?? 0.0,
          'price': (r[6] is num) ? (r[6] as num).toDouble() : double.tryParse(r[6].toString()) ?? 0.0,
          'quantity': (r[7] is num) ? (r[7] as num).toInt() : int.tryParse(r[7].toString()) ?? 0,
        };
        await DBHelper.instance.upsertProductBySku(map);
        imported++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importados: $imported productos')));
      setState(() { _future = _load(); });
    }
  }

  Future<void> _exportInventory() async {
    final path = await DBHelper.instance.exportInventoryCsv();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inventario exportado: $path')));
  }

  Future<void> _shareInventory() async {
    final path = await DBHelper.instance.exportInventoryCsv();
    await Share.shareXFiles([XFile(path)], text: 'Inventario exportado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(onPressed: _importCsv, icon: const Icon(Icons.upload_file), tooltip: 'Importar CSV'),
          IconButton(onPressed: _exportInventory, icon: const Icon(Icons.download), tooltip: 'Exportar CSV'),
          IconButton(onPressed: _shareInventory, icon: const Icon(Icons.share), tooltip: 'Compartir CSV'),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          var items = snap.data!;
          final sizes = ['Todos', ...{...items.map((e) => e.size)}];
          final origins = ['Todos', ...{...items.map((e) => e.origin)}];

          // Filtrado previo
          if (_size != null && _size != 'Todos') {
            items = items.where((p) => p.size == _size).toList();
          }
          if (_origin != null && _origin != 'Todos') {
            items = items.where((p) => p.origin == _origin).toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Tamaño'),
                        value: _size,
                        items: sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _size = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Origen'),
                        value: _origin,
                        items: origins.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                        onChanged: (v) => setState(() => _origin = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final p = items[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('SKU ${p.sku} · ${p.brand} · ${p.size} · ${p.origin}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${p.price.toStringAsFixed(2)}'),
                          Text('Stock: ${p.quantity}'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
