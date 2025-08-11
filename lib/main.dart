import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0D6B5E),
      brightness: Brightness.light,
      textTheme: const TextTheme().apply(bodyColor: const Color(0xFF222222)),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ventas',
      theme: theme,
      home: const HomeScreen(),
    );
  }
}

/// MODELOS
class Product {
  final int? id;
  final String nombre;
  final double costo;
  final double precio;
  final int stock;

  Product({this.id, required this.nombre, required this.costo, required this.precio, required this.stock});

  Product copyWith({int? id, String? nombre, double? costo, double? precio, int? stock}) {
    return Product(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      costo: costo ?? this.costo,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'costo': costo,
        'precio': precio,
        'stock': stock,
      };

  static Product fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        costo: (m['costo'] as num).toDouble(),
        precio: (m['precio'] as num).toDouble(),
        stock: m['stock'] as int,
      );
}

class Sale {
  final int? id;
  final int productoId;
  final int cantidad;
  final double precioUnit;
  final double costoUnit;
  final DateTime fecha;

  Sale({
    this.id,
    required this.productoId,
    required this.cantidad,
    required this.precioUnit,
    required this.costoUnit,
    required this.fecha,
  });

  double get ingreso => cantidad * precioUnit;
  double get costo => cantidad * costoUnit;
  double get utilidad => ingreso - costo;

  Map<String, dynamic> toMap() => {
        'id': id,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio_unit': precioUnit,
        'costo_unit': costoUnit,
        'fecha': fecha.toIso8601String(),
      };

  static Sale fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as int?,
        productoId: m['producto_id'] as int,
        cantidad: m['cantidad'] as int,
        precioUnit: (m['precio_unit'] as num).toDouble(),
        costoUnit: (m['costo_unit'] as num).toDouble(),
        fecha: DateTime.parse(m['fecha'] as String),
      );
}

/// DB
class Db {
  static final Db _i = Db._();
  Db._();
  factory Db() => _i;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'app.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL UNIQUE,
            costo REAL NOT NULL,
            precio REAL NOT NULL,
            stock INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            producto_id INTEGER NOT NULL,
            cantidad INTEGER NOT NULL,
            precio_unit REAL NOT NULL,
            costo_unit REAL NOT NULL,
            fecha TEXT NOT NULL,
            FOREIGN KEY(producto_id) REFERENCES products(id) ON DELETE CASCADE
          );
        ''');
      },
    );
    return _db!;
  }

  // products
  Future<int> upsertProduct(Product p0) async {
    final db = await database;
    if (p0.id == null) {
      return await db.insert('products', p0.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    } else {
      await db.update('products', p0.toMap(), where: 'id = ?', whereArgs: [p0.id]);
      return p0.id!;
    }
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'nombre ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ventas
  Future<int> addSale(Sale s) async {
    final db = await database;
    // baja de inventario
    await db.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [s.cantidad, s.productoId]);
    return await db.insert('sales', s.toMap());
  }

  Future<List<Sale>> getSales() async {
    final db = await database;
    final rows = await db.query('sales', orderBy: 'fecha DESC'); // recientes arriba
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> utilidadPorProducto() async {
    final db = await database;
    // agregados por producto
    final rows = await db.rawQuery('''
      SELECT p.id as producto_id, p.nombre,
             SUM(s.cantidad) as unidades,
             SUM(s.cantidad*s.precio_unit) as ingreso,
             SUM(s.cantidad*s.costo_unit) as costo,
             SUM(s.cantidad*s.precio_unit) - SUM(s.cantidad*s.costo_unit) as utilidad
      FROM sales s
      JOIN products p ON p.id = s.producto_id
      GROUP BY p.id, p.nombre
      ORDER BY utilidad DESC
    ''');
    return rows;
  }

  Future<Map<String, double>> totales() async {
    final db = await database;
    final r = await db.rawQuery('''
      SELECT 
        IFNULL(SUM(cantidad*precio_unit),0) as ingreso,
        IFNULL(SUM(cantidad*costo_unit),0) as costo
      FROM sales
    ''');
    final m = r.first;
    final ingreso = (m['ingreso'] as num).toDouble();
    final costo = (m['costo'] as num).toDouble();
    return {'ingreso': ingreso, 'costo': costo, 'utilidad': ingreso - costo};
  }
}

/// UI
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const InventoryScreen(),
      const SalesScreen(),
      const ReportsScreen(),
    ];
    final titles = ['inventario', 'ventas', 'reportes'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'inventario'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'ventas'),
          NavigationDestination(icon: Icon(Icons.summarize_outlined), label: 'reportes'),
        ],
      ),
    );
  }
}

/// inventario
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
    _future = Db().getProducts();
  }

  Future<void> _reload() async {
    setState(() => _future = Db().getProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final theme = Theme.of(context);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data as List<Product>;
          if (items.isEmpty) {
            return const Center(child: Text('sin productos'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p0 = items[i];
              return Card(
                child: ListTile(
                  title: Text(p0.nombre),
                  subtitle: Text('costo: ${p0.costo.toStringAsFixed(2)}  |  precio: ${p0.precio.toStringAsFixed(2)}\nstock: ${p0.stock}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'editar') {
                        final edited = await showDialog<Product?>(
                          context: context,
                          builder: (_) => ProductDialog(existing: p0),
                        );
                        if (edited != null) {
                          await Db().upsertProduct(edited);
                          _reload();
                        }
                      } else if (v == 'borrar') {
                        await Db().deleteProduct(p0.id!);
                        _reload();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('editar')),
                      const PopupMenuItem(value: 'borrar', child: Text('borrar')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<Product?>(
            context: context,
            builder: (_) => const ProductDialog(),
          );
          if (created != null) {
            await Db().upsertProduct(created);
            _reload();
          }
        },
        label: const Text('agregar'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class ProductDialog extends StatefulWidget {
  final Product? existing;
  const ProductDialog({super.key, this.existing});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _costo = TextEditingController();
  final _precio = TextEditingController();
  final _stock = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nombre.text = e.nombre;
      _costo.text = e.costo.toString();
      _precio.text = e.precio.toString();
      _stock.text = e.stock.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'nuevo producto' : 'editar producto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'nombre'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'requerido' : null,
            ),
            TextFormField(
              controller: _costo,
              decoration: const InputDecoration(labelText: 'costo'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'número' : null,
            ),
            TextFormField(
              controller: _precio,
              decoration: const InputDecoration(labelText: 'precio'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'número' : null,
            ),
            TextFormField(
              controller: _stock,
              decoration: const InputDecoration(labelText: 'stock'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || int.tryParse(v) == null) ? 'entero' : null,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final p0 = Product(
                id: widget.existing?.id,
                nombre: _nombre.text.trim(),
                costo: double.parse(_costo.text),
                precio: double.parse(_precio.text),
                stock: int.parse(_stock.text),
              );
              Navigator.pop(context, p0);
            }
          },
          child: const Text('guardar'),
        ),
      ],
    );
  }
}

/// ventas
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late Future<List<Sale>> _futureSales;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _futureSales = Db().getSales();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    _products = await Db().getProducts();
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    setState(() => _futureSales = Db().getSales());
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      body: FutureBuilder(
        future: _futureSales,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final ventas = snap.data as List<Sale>;
          if (ventas.isEmpty) return const Center(child: Text('sin ventas'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: ventas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final s = ventas[i];
              final prod = _products.firstWhere((p) => p.id == s.productoId, orElse: () => Product(id: null, nombre: 'producto', costo: 0, precio: 0, stock: 0));
              return Card(
                child: ListTile(
                  title: Text('${prod.nombre}  x${s.cantidad}'),
                  subtitle: Text('${dateFmt.format(s.fecha)}\ningreso: ${s.ingreso.toStringAsFixed(2)}   costo: ${s.costo.toStringAsFixed(2)}   utilidad: ${s.utilidad.toStringAsFixed(2)}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _products.isEmpty
            ? null
            : () async {
                final sale = await showDialog<Sale?>(
                  context: context,
                  builder: (_) => SaleDialog(products: _products),
                );
                if (sale != null) {
                  await Db().addSale(sale);
                  _reload();
                }
              },
        label: const Text('vender'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}

class SaleDialog extends StatefulWidget {
  final List<Product> products;
  const SaleDialog({super.key, required this.products});

  @override
  State<SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<SaleDialog> {
  final _formKey = GlobalKey<FormState>();
  Product? _selected;
  final _cantidad = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('nueva venta'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Product>(
            value: _selected,
            items: widget.products
                .map((p) => DropdownMenuItem(value: p, child: Text('${p.nombre} (stock ${p.stock})')))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
            decoration: const InputDecoration(labelText: 'producto'),
            validator: (v) => v == null ? 'elige producto' : null,
          ),
          TextFormField(
            controller: _cantidad,
            decoration: const InputDecoration(labelText: 'cantidad'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n <= 0) return 'entero > 0';
              if (_selected != null && n > _selected!.stock) return 'stock insuficiente';
              return null;
            },
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final p0 = _selected!;
              final qty = int.parse(_cantidad.text);
              final sale = Sale(
                productoId: p0.id!,
                cantidad: qty,
                precioUnit: p0.precio,
                costoUnit: p0.costo,
                fecha: DateTime.now(),
              );
              Navigator.pop(context, sale);
            }
          },
          child: const Text('registrar'),
        ),
      ],
    );
  }
}

/// reportes + exportación csv
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, double>? _totales;
  List<Map<String, dynamic>> _uti = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await Db().totales();
    final u = await Db().utilidadPorProducto();
    setState(() {
      _totales = t;
      _uti = u;
    });
  }

  Future<void> _exportCsv(BuildContext context) async {
    final db = Db();

    // productos
    final products = await db.getProducts();
    final productosCsv = [
      ['id', 'nombre', 'costo', 'precio', 'stock'],
      ...products.map((p) => [p.id, p.nombre, p.costo, p.precio, p.stock]),
    ];

    // ventas
    final sales = await db.getSales();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final ventasCsv = [
      ['id', 'producto_id', 'cantidad', 'precio_unit', 'costo_unit', 'fecha', 'ingreso', 'costo', 'utilidad'],
      ...sales.map((s) => [
            s.id,
            s.productoId,
            s.cantidad,
            s.precioUnit,
            s.costoUnit,
            dateFmt.format(s.fecha),
            s.ingreso,
            s.costo,
            s.utilidad
          ]),
    ];

    // utilidad por producto
    final utilCsv = [
      ['producto_id', 'nombre', 'unidades', 'ingreso', 'costo', 'utilidad'],
      ..._uti.map((m) => [m['producto_id'], m['nombre'], m['unidades'], m['ingreso'], m['costo'], m['utilidad']]),
    ];

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final f1 = File(p.join(dir.path, 'productos_$ts.csv'));
    final f2 = File(p.join(dir.path, 'ventas_$ts.csv'));
    final f3 = File(p.join(dir.path, 'utilidad_por_producto_$ts.csv'));

    await f1.writeAsString(const ListToCsvConverter().convert(productosCsv));
    await f2.writeAsString(const ListToCsvConverter().convert(ventasCsv));
    await f3.writeAsString(const ListToCsvConverter().convert(utilCsv));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('csv guardados en: ${dir.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _totales;
    return Scaffold(
      body: t == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('resumen'),
                      subtitle: Text('ingreso: ${t['ingreso']!.toStringAsFixed(2)}   costo: ${t['costo']!.toStringAsFixed(2)}   utilidad: ${t['utilidad']!.toStringAsFixed(2)}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: Text('utilidad por producto', style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _uti.isEmpty
                        ? const Center(child: Text('sin datos'))
                        : ListView.separated(
                            itemCount: _uti.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final m = _uti[i];
                              return Card(
                                child: ListTile(
                                  title: Text(m['nombre'].toString()),
                                  subtitle: Text('unidades: ${m['unidades']}  ingreso: ${_f(m['ingreso'])}  costo: ${_f(m['costo'])}  utilidad: ${_f(m['utilidad'])}'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _exportCsv(context);
        },
        label: const Text('exportar csv'),
        icon: const Icon(Icons.file_download),
      ),
    );
  }

  String _f(Object? n) {
    if (n == null) return '0.00';
    return (n as num).toStringAsFixed(2);
    }
}
