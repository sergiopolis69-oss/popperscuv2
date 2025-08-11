import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'popperscuv2.db');
    _db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT,
        price_buy REAL NOT NULL,
        price_sell REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price_buy REAL NOT NULL,
        price_sell REAL NOT NULL,
        discount_percent REAL NOT NULL DEFAULT 0,
        payment TEXT NOT NULL,
        total REAL NOT NULL,
        utility REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id)
      );
    ''');
  }

  // PRODUCTS
  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return db.query('products', orderBy: 'id DESC');
  }

  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('products', data);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('products', data, where: 'id=?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id=?', whereArgs: [id]);
  }

  // SALES
  Future<int> createSale({
    required int productId,
    required int quantity,
    required double discountPercent,
    required String paymentMethod,
  }) async {
    final db = await database;
    final prod = (await db.query('products', where: 'id=?', whereArgs: [productId])).first;
    final priceBuy = (prod['price_buy'] as num).toDouble();
    final priceSell = (prod['price_sell'] as num).toDouble();

    final subtotal = priceSell * quantity;
    final discount = subtotal * (discountPercent / 100.0);
    final afterDiscount = subtotal - discount;
    final commission = (paymentMethod == 'tarjeta') ? afterDiscount * 0.032 : 0.0;
    final total = afterDiscount - commission;
    final utilityUnit = priceSell - priceBuy;
    final utility = utilityUnit * quantity - commission;

    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final data = {
      'product_id': productId,
      'product_name': prod['name'],
      'quantity': quantity,
      'price_buy': priceBuy,
      'price_sell': priceSell,
      'discount_percent': discountPercent,
      'payment': paymentMethod,
      'total': total,
      'utility': utility,
      'created_at': now,
    };
    final id = await db.insert('sales', data);

    final currentStock = (prod['stock'] as num).toInt();
    final newStock = currentStock - quantity;
    await db.update('products', {'stock': newStock}, where: 'id=?', whereArgs: [productId]);

    return id;
  }

  Future<List<Map<String, dynamic>>> getSales({bool orderDesc = true}) async {
    final db = await database;
    return db.query('sales', orderBy: 'created_at ${orderDesc ? 'DESC' : 'ASC'}');
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    return db.delete('sales', where: 'id=?', whereArgs: [id]);
  }
}
