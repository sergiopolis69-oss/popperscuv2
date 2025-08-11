import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';
import '../models/customer.dart';

class CustomerRepository {
  final _uuid = const Uuid();

  Future<List<Customer>> all() async {
    final db = await AppDatabase().database;
    final rows = await db.query('customers', orderBy: 'name ASC');
    return rows.map((e) => Customer.fromMap(e)).toList();
  }

  Future<void> create(Customer c) async {
    final db = await AppDatabase().database;
    await db.insert('customers', c.toMap());
  }

  Future<void> update(Customer c) async {
    final db = await AppDatabase().database;
    await db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase().database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Customer newEmpty() {
    return Customer(id: _uuid.v4(), name: '');
  }
}
