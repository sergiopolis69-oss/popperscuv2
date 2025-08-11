import '../models/inventory_movement.dart';
import '../models/sale_item.dart';
import '../models/sale.dart';
import '../services/db.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
Future<void> createSale({
    String? customerId,
    required List<SaleItem> items,
    required double discount,
    required String paymentMethod,
  }) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      double subtotal = 0; double costTotal = 0;
      for (final it in items) {
        subtotal += it.subtotal;                // price*qty - lineDiscount
        costTotal += (it.costAtSale * it.quantity);
      }
      double total = subtotal - discount;
      if (total < 0) total = 0;
      final profit = total - costTotal;

      final saleId = _uuid.v4();
      final sale = Sale(
        id: saleId,
        customerId: customerId,
        total: total,
        discount: discount,
        paymentMethod: paymentMethod,
        profit: profit,
      );
      await txn.insert('sales', sale.toMap());

      for (final it in items) {
        final row = it.toMap();
        row['id'] = _uuid.v4();
        row['sale_id'] = saleId;
        await txn.insert('sale_items', row);
        await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [it.quantity, it.productId]);
        final mov = InventoryMovement(
          id: _uuid.v4(),
          productId: it.productId,
          type: 'out',
          quantity: it.quantity,
          refSaleId: saleId,
        );
        await txn.insert('inventory_movements', mov.toMap());
      }
    });
  }
    double total = (subtotal - discount); if (total < 0) total = 0;
    final profit = total - costTotal;

    final saleId = const Uuid().v4();
    await txn.insert('sales', Sale(
      id:saleId, customerId:customerId, total:total, discount:discount,
      paymentMethod:paymentMethod, profit:profit,
    ).toMap());

    for (final it in items) {
      await txn.insert('sale_items', SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        productId: it.productId,
        quantity: it.quantity,
        price: it.price,
        costAtSale: it.costAtSale,
        lineDiscount: it.lineDiscount,
      ).toMap());
      await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [it.quantity, it.productId]);
      await txn.insert('inventory_movements', {
        'id': const Uuid().v4(),
        'product_id': it.productId,
        'type': 'out',
        'quantity': it.quantity,
        'ref_sale_id': saleId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  });
}


class SaleRepository {
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> topCustomers(DateTime from, DateTime to, {int limit = 50}) async {
    final db = await AppDatabase().database;
    final sql = '''
      SELECT s.customer_id, COALESCE(c.name, '(sin cliente)') as customer_name,
             COUNT(*) as orders, SUM(s.total) as spent, SUM(s.profit) as profit
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE s.created_at >= ? AND s.created_at <= ?
      GROUP BY s.customer_id, c.name
      ORDER BY spent DESC
      LIMIT ?
    ''';
    return db.rawQuery(sql, [from.toIso8601String(), to.toIso8601String(), limit]);
  }

  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> history({
    String? customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase().database;
    final where = <String>[]; final args = <dynamic>[];
    if (customerId != null && customerId.isNotEmpty) { where.add('s.customer_id = ?'); args.add(customerId); }
    if (from != null) { where.add('s.created_at >= ?'); args.add(from.toIso8601String()); }
    if (to != null)   { where.add('s.created_at <= ?'); args.add(to.toIso8601String()); }
    final sql = '''
      SELECT s.id, s.created_at, s.total, s.discount, s.payment_method, s.profit,
             c.name as customer_name
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      ${where.isEmpty ? '' : 'WHERE ' + where.join(' AND ')}
      ORDER BY s.created_at DESC
    ''';
    return db.rawQuery(sql, args);
  }

  final _uuid = const Uuid();
}
