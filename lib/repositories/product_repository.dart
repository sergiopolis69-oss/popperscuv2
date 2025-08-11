import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';
import '../models/product.dart';

class ProductRepository {
  final _uuid = const Uuid();

  Future<List<Product>> all() async {
    final db = await AppDatabase().database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<void> create(Product p) async {
    final db = await AppDatabase().database;
    await db.insert('products', p.toMap());
  }

  Future<void> update(Product p) async {
    final db = await AppDatabase().database;
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase().database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Product newEmpty() {
    return Product(id: _uuid.v4(), name: '', price: 0, stock: 0);
  }
}
