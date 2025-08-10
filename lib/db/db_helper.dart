import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  late Database db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'popperscuv2.db');
    db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sku TEXT UNIQUE,
          name TEXT,
          brand TEXT,
          size TEXT,
          origin TEXT,
          cost REAL,
          price REAL,
          quantity INTEGER
        );
      ''');
      await db.execute('''
        CREATE TABLE clients(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE,
          phone TEXT,
          email TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER,
          quantity INTEGER,
          client_id INTEGER,
          payment TEXT,
          discount_percent REAL,
          created_at TEXT,
          utility REAL
        );
      ''');
      // Semillas iniciales (costos 300, origen USA)
      await db.insert('products', {
        'sku':'SKU-10-001','name':'Esencia A 10ml','brand':'MarcaX','size':'10ml','origin':'USA','cost':300.0,'price':500.0,'quantity':15
      });
      await db.insert('products', {
        'sku':'SKU-30-001','name':'Esencia B 30ml','brand':'MarcaY','size':'30ml','origin':'USA','cost':300.0,'price':900.0,'quantity':8
      });
      await db.insert('clients', {'name':'Mostrador'});
    });
  }

  // Productos
  Future<List<Map<String,dynamic>>> getProducts() async =>
    await db.query('products', orderBy: 'name ASC');

  Future<int> upsertProductBySku(Map<String,dynamic> p) async {
    final rows = await db.query('products', where: 'sku=?', whereArgs: [p['sku']], limit: 1);
    if (rows.isEmpty) {
      return await db.insert('products', p, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      return await db.update('products', p, where: 'sku=?', whereArgs: [p['sku']]);
    }
  }

  // Clientes
  Future<List<Map<String,dynamic>>> getClients() async =>
    await db.query('clients', orderBy: 'name ASC');

  Future<int> upsertClient(String name, {String? phone, String? email}) async {
    final rows = await db.query('clients', where: 'name=?', whereArgs: [name], limit: 1);
    if (rows.isEmpty) {
      return await db.insert('clients', {'name':name,'phone':phone,'email':email});
    } else {
      return await db.update('clients', {'name':name,'phone':phone,'email':email}, where:'name=?', whereArgs:[name]);
    }
  }

  // Utilidad
  double _afterDiscount(double amount, double discountPercent) =>
      amount * (1 - (discountPercent/100.0));

  double calcUtility({
    required double price,
    required int quantity,
    required double cost,
    required String payment,
    required double discountPercent,
  }) {
    final gross = price * quantity;
    final netAfterDiscount = _afterDiscount(gross, discountPercent);
    final commission = (payment == 'Tarjeta') ? netAfterDiscount * 0.032 : 0.0;
    final revenue = netAfterDiscount - commission;
    final totalCost = cost * quantity;
    return revenue - totalCost;
  }

  Future<Map<String,dynamic>?> getProduct(int id) async {
    final r = await db.query('products', where:'id=?', whereArgs:[id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<int> createSale({
    required int productId,
    required int quantity,
    required int? clientId,
    required String payment,
    required double discountPercent,
  }) async {
    final p = await getProduct(productId);
    if (p == null) { throw Exception('Producto no encontrado'); }
    if ((p['quantity'] as int) < quantity) { throw Exception('Stock insuficiente'); }

    final utility = calcUtility(
      price: (p['price'] as num).toDouble(),
      quantity: quantity,
      cost: (p['cost'] as num).toDouble(),
      payment: payment,
      discountPercent: discountPercent,
    );

    final id = await db.insert('sales', {
      'product_id': productId,
      'quantity': quantity,
      'client_id': clientId,
      'payment': payment,
      'discount_percent': discountPercent,
      'created_at': DateTime.now().toIso8601String(),
      'utility': utility,
    });

    // Actualiza stock
    await db.update('products', {'quantity': (p['quantity'] as int) - quantity}, where:'id=?', whereArgs:[productId]);
    return id;
  }

  Future<List<Map<String,dynamic>>> getSalesWithDetails() async {
    return await db.rawQuery('''
      SELECT s.id, s.quantity, s.payment, s.discount_percent, s.created_at, s.utility,
             p.id AS product_id, p.name AS product_name, p.sku, p.brand, p.size, p.origin, p.price, p.cost,
             c.id AS client_id, c.name AS client
      FROM sales s
      LEFT JOIN products p ON p.id = s.product_id
      LEFT JOIN clients c ON c.id = s.client_id
      ORDER BY s.created_at DESC
    ''');
  }

  Future<String> exportSalesCsv() async {
    final rows = await getSalesWithDetails();
    final headers = ['id','product_name','quantity','client','payment','discount_percent','created_at','utility'];
    final b = StringBuffer()..writeln(headers.join(','));
    for (final r in rows) {
      final product = (r['product_name'] ?? '').toString().replaceAll(',', ' ');
      final client = (r['client'] ?? '').toString().replaceAll(',', ' ');
      b.writeln('${r['id']},${product},${r['quantity']},${client},${r['payment']},${r['discount_percent']},${r['created_at']},${r['utility']}');
    }
    final dir = await getDatabasesPath();
    final path = join(dir, 'ventas_export.csv');
    final file = await File(path).writeAsString(b.toString());
    return file.path;
  }

  Future<String> exportInventoryCsv() async {
    final rows = await getProducts();
    final headers = ['sku','name','brand','size','origin','cost','price','quantity'];
    final b = StringBuffer()..writeln(headers.join(','));
    for (final m in rows) {
      final name = (m['name'] ?? '').toString().replaceAll(',', ' ');
      b.writeln('${m['sku']},${name},${m['brand']},${m['size']},${m['origin']},${m['cost']},${m['price']},${m['quantity']}');
    }
    final dir = await getDatabasesPath();
    final path = join(dir, 'inventario_export.csv');
    final file = await File(path).writeAsString(b.toString());
    return file.path;
  }
}
