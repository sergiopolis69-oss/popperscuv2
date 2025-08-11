// lib/screens/products_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  Database? _db;
  late Future<List<_Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _initAndLoad();
  }

  Future<List<_Product>> _initAndLoad() async {
    _db ??= await _openDb();
    await _ensureSchema(_db!);
    return _loadProducts(_db!);
  }

  Future<Database> _openDb() async {
    final path = p.join(await getDatabasesPath(), 'popperscuv2.db');
    return openDatabase(path, version: 1);
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cost REAL NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        qty INTEGER NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        ts INTEGER NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id)
      );
    ''');

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products'),
    );
    if ((count ?? 0) == 0) {
      await db.insert('products', {'name': 'poppers 10ml', 'cost': 40.0, 'price': 100.0, 'stock': 20});
      await db.insert('products', {'name': 'poppers 30ml', 'cost': 90.0, 'price': 180.0, 'stock': 15});
      await db.insert('products', {'name': 'pack duo', 'cost': 110.0, 'price': 220.0, 'stock': 10});
    }
  }

  Future<List<_Product>> _loadProducts(Database db) async {
    final rows = await db.query('products', orderBy: 'name ASC');
    final list = rows.map((r) => _Product.fromMap(r)).toList();
    for (final p in list) {
      p.profit = await _productProfit(db, p.id!);
    }
    return list;
  }

  Future<double> _productProfit(Database db, int productId) async {
    final rows = await db.query('sales', columns: ['qty', 'price', 'cost'], where: 'product_id = ?', whereArgs: [productId]);
    double total = 0;
    for (final r in rows) {
      total += ((r['price'] as num) - (r['cost'] as num)).toDouble() * (r['qty'] as int);
    }
    return total;
  }

  Future<void> _registerSale(_Product p) async {
    final qty = await showDialog<int>(context: context, builder: (_) => _QtyDialog(title: 'Vender "${p.name}"'));
    if (qty == null || qty <= 0) return;

    final current = Sqflite.firstIntValue(await _db!.rawQuery('SELECT stock FROM products WHERE id=?', [p.id])) ?? p.stock;
    if (qty > current) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock insuficiente')));
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    await _db!.insert('sales', {'product_id': p.id, 'qty': qty, 'price': p.price, 'cost': p.cost, 'ts': ts});
    await _db!.update('products', {'stock': current - qty}, where: 'id=?', whereArgs: [p.id]);

    setState(() => _future = _loadProducts(_db!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Venta registrada: $qty × ${p.name}')));
  }

  Future<void> _exportCsv() async {
    final dir = await getApplicationDocumentsDirectory();
    final invFile = File(p.join(dir.path, 'inventario.csv'));
    final salesFile = File(p.join(dir.path, 'ventas.csv'));

    final invRows = await _db!.rawQuery('SELECT id,name,cost,price,stock FROM products ORDER BY name ASC');
    final invCsv = StringBuffer()..writeln('id,name,cost,price,stock,profit');
    for (final r in invRows) {
      final id = r['id'] as int;
      final profit = await _productProfit(_db!, id);
      invCsv.writeln('${r['id']},${_csv(r['name'])},${r['cost']},${r['price']},${r['stock']},$profit');
    }
    await invFile.writeAsString(invCsv.toString());

    final salesRows = await _db!.rawQuery('''
      SELECT s.id, s.product_id, p.name as product_name, s.qty, s.price, s.cost, s.ts
      FROM sales s JOIN products p ON p.id = s.product_id
      ORDER BY s.ts DESC
    ''');
    final salesCsv = StringBuffer()..writeln('id,product_id,product_name,qty,price,cost,profit,ts,ts_iso');
    for (final r in salesRows) {
      final qty = r['qty'] as int;
      final price = (r['price'] as num).toDouble();
      final cost = (r['cost'] as num).toDouble();
      final profit = (price - cost) * qty;
      final ts = r['ts'] as int;
      final iso = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
      salesCsv.writeln('${r['id']},${r['product_id']},${_csv(r['product_name'])},$qty,$price,$cost,$profit,$ts,$iso');
    }
    await salesFile.writeAsString(salesCsv.toString());

    await Share.shareXFiles([
      XFile(invFile.path, mimeType: 'text/csv', name: 'inventario.csv'),
      XFile(salesFile.path, mimeType: 'text/csv', name: 'ventas.csv'),
    ]);
  }

  String _csv(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (!s.contains(',') && !s.contains('"') && !s.contains('\n')) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  Future<void> _edit({_Product? existing}) async {
    final res = await showModalBottomSheet<_Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductForm(existing: existing),
    );
    if (res == null) return;
    if (existing == null) {
      await _db!.insert('products', res.toMap(withId: false));
    } else {
      await _db!.update('products', res.toMap(withId: false), where: 'id=?', whereArgs: [existing.id]);
    }
    setState(() => _future = _loadProducts(_db!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('inventario'),
        actions: [
          IconButton(onPressed: _exportCsv, tooltip: 'exportar csv', icon: const Icon(Icons.file_download_outlined)),
          IconButton(onPressed: () => _edit(), tooltip: 'agregar producto', icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<_Product>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('error: ${snap.error}'));
          final data = snap.data ?? [];
          if (data.isEmpty) return const Center(child: Text('sin productos'));
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = data[i];
              final utilUnit = p.price - p.cost;
              return ListTile(
                title: Text(p.name),
                subtitle: Text(
                  'costo: ${p.cost.toStringAsFixed(2)}  ·  precio: ${p.price.toStringAsFixed(2)}\n'
                  'stock: ${p.stock}  ·  utilidad unitaria: ${utilUnit.toStringAsFixed(2)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('utilidad total', style: Theme.of(context).textTheme.labelSmall),
                    Text(p.profit.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: OutlinedButton(onPressed: () => _registerSale(p), child: const Text('vender')),
                    ),
                  ],
                ),
                onTap: () => _edit(existing: p),
              );
            },
          );
        },
      ),
    );
  }
}

class _Product {
  final int? id;
  final String name;
  final double cost;
  final double price;
  final int stock;
  double profit;
  _Product({this.id, required this.name, required this.cost, required this.price, required this.stock, this.profit = 0});
  factory _Product.fromMap(Map<String, Object?> m) => _Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        cost: (m['cost'] as num).toDouble(),
        price: (m['price'] as num).toDouble(),
        stock: m['stock'] as int,
      );
  Map<String, Object?> toMap({bool withId = true}) => {
        if (withId) 'id': id,
        'name': name,
        'cost': cost,
        'price': price,
        'stock': stock,
      };
}

class _QtyDialog extends StatefulWidget {
  final String title;
  const _QtyDialog({required this.title, Key? key}) : super(key: key);
  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  final _ctrl = TextEditingController(text: '1');
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: _ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'cantidad')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(int.tryParse(_ctrl.text.trim())),
          child: const Text('vender'),
        ),
      ],
    );
  }
}

class _ProductForm extends StatefulWidget {
  final _Product? existing;
  const _ProductForm({this.existing, Key? key}) : super(key: key);
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _name = TextEditingController();
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _cost.text = e.cost.toString();
      _price.text = e.price.toString();
      _stock.text = e.stock.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose(); _cost.dispose(); _price.dispose(); _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom + 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.existing == null ? 'agregar producto' : 'editar producto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'nombre')),
          const SizedBox(height: 8),
          TextField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'costo')),
          const SizedBox(height: 8),
          TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'precio')),
          const SizedBox(height: 8),
          TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'stock')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop<_Product>(null), child: const Text('cancelar'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final prod = _Product(
                      id: widget.existing?.id,
                      name: _name.text.trim(),
                      cost: double.tryParse(_cost.text.trim()) ?? 0,
                      price: double.tryParse(_price.text.trim()) ?? 0,
                      stock: int.tryParse(_stock.text.trim()) ?? 0,
                    );
                    Navigator.of(context).pop(prod);
                  },
                  child: const Text('guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
