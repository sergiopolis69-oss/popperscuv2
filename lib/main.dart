import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const MyApp());
}

/// base de datos (sqlite) — una sola instancia
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'pos_local.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        // productos
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sku TEXT,
            stock INTEGER NOT NULL DEFAULT 0,
            cost REAL NOT NULL DEFAULT 0,
            price REAL NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');

        // ventas (historial en una sola tabla)
        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            qty INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            unit_cost REAL NOT NULL,
            total REAL NOT NULL,
            profit REAL NOT NULL,
            ts INTEGER NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
          );
        ''');
      },
    );
  }

  Database get db => _db!;

  // productos
  Future<int> insertProduct(Product p) async {
    return await db.insert('products', p.toMap());
  }

  Future<int> updateProduct(Product p) async {
    return await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deleteProduct(int id) async {
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getAllProducts() async {
    final rows = await db.query('products', orderBy: 'created_at DESC');
    return rows.map(Product.fromMap).toList();
  }

  // ventas
  Future<int> insertSale(Sale s) async {
    final batch = db.batch();
    // 1) inserta venta
    batch.insert('sales', s.toMap());
    // 2) descuenta inventario
    batch.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [s.qty, s.productId]);
    final res = await batch.commit();
    return (res.first as int);
  }

  Future<List<SaleWithProduct>> getAllSales() async {
    final rows = await db.rawQuery('''
      SELECT s.id, s.product_id, s.qty, s.unit_price, s.unit_cost, s.total, s.profit, s.ts,
             p.name as product_name, p.sku as product_sku
      FROM sales s
      JOIN products p ON p.id = s.product_id
      ORDER BY s.ts DESC
    ''');
    return rows.map((m) => SaleWithProduct.fromJoinedMap(m)).toList();
  }
}

/// modelo: producto
class Product {
  final int? id;
  final String name;
  final String? sku;
  final int stock;
  final double cost;
  final double price;
  final int createdAtMillis;

  Product({
    this.id,
    required this.name,
    this.sku,
    required this.stock,
    required this.cost,
    required this.price,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'stock': stock,
        'cost': cost,
        'price': price,
        'created_at': createdAtMillis,
      };

  static Product fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        sku: m['sku'] as String?,
        stock: (m['stock'] as num).toInt(),
        cost: (m['cost'] as num).toDouble(),
        price: (m['price'] as num).toDouble(),
        createdAtMillis: (m['created_at'] as num).toInt(),
      );
}

/// modelo: venta
class Sale {
  final int? id;
  final int productId;
  final int qty;
  final double unitPrice;
  final double unitCost;
  final double total;
  final double profit;
  final int tsMillis;

  Sale({
    this.id,
    required this.productId,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
    required this.total,
    required this.profit,
    required this.tsMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'qty': qty,
        'unit_price': unitPrice,
        'unit_cost': unitCost,
        'total': total,
        'profit': profit,
        'ts': tsMillis,
      };

  static Sale fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as int?,
        productId: (m['product_id'] as num).toInt(),
        qty: (m['qty'] as num).toInt(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
        tsMillis: (m['ts'] as num).toInt(),
      );
}

/// proyección: venta + datos del producto (para la lista y csv)
class SaleWithProduct {
  final Sale sale;
  final String productName;
  final String? productSku;

  SaleWithProduct({
    required this.sale,
    required this.productName,
    this.productSku,
  });

  static SaleWithProduct fromJoinedMap(Map<String, Object?> m) {
    return SaleWithProduct(
      sale: Sale(
        id: (m['id'] as num?)?.toInt(),
        productId: (m['product_id'] as num).toInt(),
        qty: (m['qty'] as num).toInt(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
        tsMillis: (m['ts'] as num).toInt(),
      ),
      productName: (m['product_name'] as String?) ?? '',
      productSku: m['product_sku'] as String?,
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'popperscuv2',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF222222)),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('inventario y ventas', style: TextStyle(fontWeight: FontWeight.w500)),
          centerTitle: true,
        ),
        body: _tab == 0 ? const InventoryScreen() : const SalesScreen(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'inventario'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'ventas'),
          ],
          onDestinationSelected: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

/// pantalla inventario
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppDb.instance.getAllProducts();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AppDb.instance.getAllProducts();
    });
  }

  Future<void> _showAddOrEdit({Product? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final skuCtrl = TextEditingController(text: editing?.sku ?? '');
    final stockCtrl = TextEditingController(text: editing?.stock.toString() ?? '0');
    final costCtrl = TextEditingController(text: editing?.cost.toString() ?? '0');
    final priceCtrl = TextEditingController(text: editing?.price.toString() ?? '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? 'agregar producto' : 'editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'nombre (obligatorio)')),
              TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'sku (opcional)')),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'existencia'), keyboardType: TextInputType.number),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'costo unitario'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'precio unitario'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('guardar')),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('el nombre es obligatorio')));
      return;
    }

    final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

    final now = DateTime.now().millisecondsSinceEpoch;

    if (editing == null) {
      await AppDb.instance.insertProduct(Product(
        name: name,
        sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
        stock: stock,
        cost: cost,
        price: price,
        createdAtMillis: now,
      ));
    } else {
      await AppDb.instance.updateProduct(Product(
        id: editing.id,
        name: name,
        sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
        stock: stock,
        cost: cost,
        price: price,
        createdAtMillis: editing.createdAtMillis,
      ));
    }

    await _reload();
  }

  Future<void> _sell(Product p) async {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: p.price.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('registrar venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('producto: ${p.name}'),
            const SizedBox(height: 8),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'cantidad'), keyboardType: TextInputType.number),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'precio unitario'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            Text('existencia actual: ${p.stock}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('vender')),
        ],
      ),
    );

    if (ok != true) return;

    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    final unitPrice = double.tryParse(priceCtrl.text.trim()) ?? p.price;

    if (qty <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('la cantidad debe ser mayor a 0')));
      return;
    }
    if (qty > p.stock) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('no hay suficiente inventario')));
      return;
    }

    final total = unitPrice * qty;
    final profit = (unitPrice - p.cost) * qty;

    final sale = Sale(
      productId: p.id!,
      qty: qty,
      unitPrice: unitPrice,
      unitCost: p.cost,
      total: total,
      profit: profit,
      tsMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await AppDb.instance.insertSale(sale);
    await _reload();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('venta registrada')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const <Product>[];
        return Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: Text('inventario (${items.length})', style: Theme.of(context).textTheme.titleMedium)),
                  FilledButton.icon(
                    onPressed: _showAddOrEdit,
                    icon: const Icon(Icons.add),
                    label: const Text('agregar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final marginPct = p.price <= 0 ? 0.0 : ((p.price - p.cost) / p.price) * 100.0;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          'sku: ${p.sku ?? '-'} • stock: ${p.stock} • costo: ${_money(p.cost)} • precio: ${_money(p.price)} • utilidad: ${marginPct.toStringAsFixed(1)}%',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'editar',
                              onPressed: () => _showAddOrEdit(editing: p),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'vender',
                              onPressed: p.id == null ? null : () => _sell(p),
                              icon: const Icon(Icons.point_of_sale_outlined),
                            ),
                            IconButton(
                              tooltip: 'eliminar',
                              onPressed: () async {
                                if (p.id != null) {
                                  await AppDb.instance.deleteProduct(p.id!);
                                  await _reload();
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// pantalla ventas
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late Future<List<SaleWithProduct>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppDb.instance.getAllSales();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AppDb.instance.getAllSales();
    });
  }

  Future<void> _exportCsv() async {
    final rows = await AppDb.instance.getAllSales();

    // encabezados
    final buf = StringBuffer();
    buf.writeln('id,fecha,producto,sku,cantidad,precio_unitario,costo_unitario,total,utilidad');

    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.sale.tsMillis);
      final fecha = '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
      // csv seguro (comillas si hay coma)
      String q(String? s) {
        final v = (s ?? '').replaceAll('"', '""');
        return '"$v"';
      }

      buf.writeln([
        r.sale.id ?? '',
        q(fecha),
        q(r.productName),
        q(r.productSku ?? ''),
        r.sale.qty,
        r.sale.unitPrice.toStringAsFixed(2),
        r.sale.unitCost.toStringAsFixed(2),
        r.sale.total.toStringAsFixed(2),
        r.sale.profit.toStringAsFixed(2),
      ].join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ventas.csv'));
    await file.writeAsString(buf.toString(), flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('csv listo en ${file.path}')));
    await Share.shareXFiles([XFile(file.path)], text: 'ventas (csv)');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaleWithProduct>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const <SaleWithProduct>[];
        final total = items.fold<double>(0, (a, b) => a + b.sale.total);
        final utilidad = items.fold<double>(0, (a, b) => a + b.sale.profit);

        return Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'ventas recientes (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('exportar csv'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(child: Text('total: ${_money(total)}')),
                  Expanded(child: Text('utilidad: ${_money(utilidad)}')),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final d = DateTime.fromMillisecondsSinceEpoch(s.sale.tsMillis);
                    final fecha = '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${s.productName} • x${s.sale.qty}'),
                        subtitle: Text('fecha: $fecha • total: ${_money(s.sale.total)} • utilidad: ${_money(s.sale.profit)}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// helpers
String _money(double v) => '\$${v.toStringAsFixed(2)}';
String _two(int n) => n < 10 ? '0$n' : '$n';
