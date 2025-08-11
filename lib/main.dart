import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.instance.init();
  runApp(MyApp(db: db));
}

class MyApp extends StatelessWidget {
  final Database db;
  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ventas e Inventario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: HomeScreen(db: db),
    );
  }
}

/* =========================
   MODELOS Y DB
========================= */

class Product {
  final int? id;
  final String name;
  final double cost;
  final double price;
  final int stock;

  Product({this.id, required this.name, required this.cost, required this.price, required this.stock});

  Product copyWith({int? id, String? name, double? cost, double? price, int? stock}) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    cost: cost ?? this.cost,
    price: price ?? this.price,
    stock: stock ?? this.stock,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'cost': cost,
    'price': price,
    'stock': stock,
  };

  static Product fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] as int?,
    name: m['name'] as String,
    cost: (m['cost'] as num).toDouble(),
    price: (m['price'] as num).toDouble(),
    stock: m['stock'] as int,
  );
}

class Sale {
  final int? id;
  final int productId;
  final int qty;
  final DateTime createdAt;
  final double priceAtSale; // precio unitario usado
  final double costAtSale;  // costo unitario usado

  Sale({
    this.id,
    required this.productId,
    required this.qty,
    required this.createdAt,
    required this.priceAtSale,
    required this.costAtSale,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'qty': qty,
    'created_at': createdAt.toIso8601String(),
    'price_at_sale': priceAtSale,
    'cost_at_sale': costAtSale,
  };

  static Sale fromMap(Map<String, dynamic> m) => Sale(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    qty: m['qty'] as int,
    createdAt: DateTime.parse(m['created_at'] as String),
    priceAtSale: (m['price_at_sale'] as num).toDouble(),
    costAtSale: (m['cost_at_sale'] as num).toDouble(),
  );
}

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;

  Future<Database> init() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ventas.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cost REAL NOT NULL,
            price REAL NOT NULL,
            stock INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            qty INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            price_at_sale REAL NOT NULL,
            cost_at_sale REAL NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id)
          )
        ''');
      },
    );
    return _db!;
  }

  Database get db => _db!;

  // Productos
  Future<List<Product>> getProducts({String q = ''}) async {
    final where = q.isEmpty ? '' : 'WHERE name LIKE ?';
    final args = q.isEmpty ? [] : ['%$q%'];
    final rows = await db.rawQuery('SELECT * FROM products $where ORDER BY name ASC', args);
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product p) =>
      db.insert('products', p.toMap()..remove('id'));

  Future<int> updateProduct(Product p) =>
      db.update('products', p.toMap()..remove('id'), where: 'id=?', whereArgs: [p.id]);

  Future<int> deleteProduct(int id) =>
      db.delete('products', where: 'id=?', whereArgs: [id]);

  // Ventas
  Future<void> sell({required Product product, required int qty}) async {
    await db.transaction((txn) async {
      // stock
      if (product.stock < qty) throw Exception('Stock insuficiente');
      await txn.update(
        'products',
        {'stock': product.stock - qty},
        where: 'id=?',
        whereArgs: [product.id],
      );
      // venta
      final sale = Sale(
        productId: product.id!,
        qty: qty,
        createdAt: DateTime.now(),
        priceAtSale: product.price,
        costAtSale: product.cost,
      );
      await txn.insert('sales', sale.toMap()..remove('id'));
    });
  }

  Future<List<Map<String, dynamic>>> salesWithProduct() async {
    return db.rawQuery('''
      SELECT s.id, s.qty, s.created_at, s.price_at_sale, s.cost_at_sale,
             p.name
      FROM sales s
      JOIN products p ON p.id = s.product_id
      ORDER BY datetime(s.created_at) DESC
    ''');
  }

  Future<String> exportCsv() async {
    final prod = await db.rawQuery('SELECT * FROM products ORDER BY name ASC');
    final sales = await salesWithProduct();

    final b = StringBuffer();
    b.writeln('=== Productos ===');
    b.writeln('id,name,cost,price,stock');
    for (final r in prod) {
      b.writeln('${r['id']},${_csv(r['name'])},${r['cost']},${r['price']},${r['stock']}');
    }
    b.writeln('');
    b.writeln('=== Ventas ===');
    b.writeln('id,product,qty,price_unit,cost_unit,profit_unit,profit_total,created_at');
    for (final r in sales) {
      final price = (r['price_at_sale'] as num).toDouble();
      final cost = (r['cost_at_sale'] as num).toDouble();
      final qty = (r['qty'] as num).toInt();
      final pu = price - cost;
      final pt = pu * qty;
      b.writeln('${r['id']},${_csv(r['name'])},$qty,$price,$cost,$pu,$pt,${r['created_at']}');
    }

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'reporte_ventas.csv'));
    await file.writeAsString(b.toString(), flush: true);
    return file.path;
  }
}

String _csv(Object? v) {
  final s = (v ?? '').toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/* =========================
   UI
========================= */

class HomeScreen extends StatefulWidget {
  final Database db;
  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = AppDatabase.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Inventario' : 'Historial de ventas'),
        actions: [
          if (_tab == 0)
            IconButton(
              tooltip: 'Exportar CSV',
              icon: const Icon(Icons.download),
              onPressed: () async {
                final path = await repo.exportCsv();
                await Share.shareXFiles([XFile(path)], text: 'Reporte de ventas');
              },
            ),
        ],
      ),
      body: _tab == 0
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar producto',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                Expanded(child: _InventoryList(query: _query, onSell: _sellDialog, onEdit: _editProduct, onDelete: _deleteProduct)),
              ],
            )
          : const _SalesHistory(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Historial'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _editProduct(context),
              label: const Text('Nuevo'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _sellDialog(BuildContext context, Product p) async {
    final qtyCtrl = TextEditingController(text: '1');
    final ok = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Vender: ${p.name}'),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final q = int.tryParse(qtyCtrl.text) ?? 0;
              Navigator.pop(context, q > 0 ? q : null);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (ok == null) return;
    try {
      await AppDatabase.instance.sell(product: p, qty: ok);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _editProduct(BuildContext context, [Product? p]) async {
    final name = TextEditingController(text: p?.name ?? '');
    final cost = TextEditingController(text: p?.cost.toString() ?? '');
    final price = TextEditingController(text: p?.price.toString() ?? '');
    final stock = TextEditingController(text: p?.stock.toString() ?? '');

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: 'Nombre'), controller: name),
              TextField(decoration: const InputDecoration(labelText: 'Costo unitario'), controller: cost, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Precio unitario'), controller: price, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Stock'), controller: stock, keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (res != true) return;

    final nameV = name.text.trim();
    final costV = double.tryParse(cost.text) ?? 0;
    final priceV = double.tryParse(price.text) ?? 0;
    final stockV = int.tryParse(stock.text) ?? 0;

    if (nameV.isEmpty || costV <= 0 || priceV <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos inválidos')));
      return;
    }

    final repo = AppDatabase.instance;
    if (p == null) {
      await repo.insertProduct(Product(name: nameV, cost: costV, price: priceV, stock: stockV));
    } else {
      await repo.updateProduct(p.copyWith(name: nameV, cost: costV, price: priceV, stock: stockV));
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteProduct(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.instance.deleteProduct(p.id!);
      if (mounted) setState(() {});
    }
  }
}

class _InventoryList extends StatelessWidget {
  final String query;
  final Future<void> Function(BuildContext, Product) onSell;
  final Future<void> Function(BuildContext, [Product?]) onEdit;
  final Future<void> Function(BuildContext, Product) onDelete;

  const _InventoryList({
    required this.query,
    required this.onSell,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final repo = AppDatabase.instance;
    return FutureBuilder<List<Product>>(
      future: repo.getProducts(q: query),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('Sin productos. Toca “Nuevo” para agregar.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = items[i];
            final profit = p.price - p.cost;
            return ListTile(
              title: Text(p.name),
              subtitle: Text('Precio: ${p.price.toStringAsFixed(2)}  •  Costo: ${p.cost.toStringAsFixed(2)}  •  Utilidad u.: ${profit.toStringAsFixed(2)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(label: Text('Stock: ${p.stock}')),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.shopping_cart_outlined), tooltip: 'Vender', onPressed: () => onSell(context, p)),
                  IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: () => onEdit(context, p)),
                  IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar', onPressed: () => onDelete(context, p)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SalesHistory extends StatefulWidget {
  const _SalesHistory();

  @override
  State<_SalesHistory> createState() => _SalesHistoryState();
}

class _SalesHistoryState extends State<_SalesHistory> {
  @override
  Widget build(BuildContext context) {
    final repo = AppDatabase.instance;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.salesWithProduct(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        if (rows.isEmpty) return const Center(child: Text('Aún no hay ventas.'));
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = rows[i];
            final qty = (r['qty'] as num).toInt();
            final price = (r['price_at_sale'] as num).toDouble();
            final cost = (r['cost_at_sale'] as num).toDouble();
            final pu = price - cost;
            final pt = pu * qty;
            final when = DateTime.parse(r['created_at'] as String);
            return ListTile(
              title: Text('${r['name']}  x$qty'),
              subtitle: Text('${when.toLocal()}'),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ingreso: ${(price * qty).toStringAsFixed(2)}'),
                  Text('Utilidad: ${pt.toStringAsFixed(2)}', style: TextStyle(color: pt >= 0 ? Colors.green : Colors.red)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
