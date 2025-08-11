import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/inventory_movement.dart';

class SaleRepository {
  final _uuid = const Uuid();

  Future<void> createSale({
    String? customerId,
    required List<SaleItem> items,
    required double discount,
    required String paymentMethod,
  }) async {
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      // Calculate totals
      double subtotal = 0;
      for (final item in items) {
        subtotal += item.subtotal; // already includes line_discount
      }
      double total = subtotal - discount;
      if (total < 0) total = 0;

      final saleId = _uuid.v4();
      final sale = Sale(
        id: saleId,
        customerId: customerId,
        total: total,
        discount: discount,
        paymentMethod: paymentMethod,
      );
      await txn.insert('sales', sale.toMap());

      for (final item in items) {
        final itemWithId = SaleItem(
          id: _uuid.v4(),
          saleId: saleId,
          productId: item.productId,
          quantity: item.quantity,
          price: item.price,
          lineDiscount: item.lineDiscount,
        );
        await txn.insert('sale_items', itemWithId.toMap());
        await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [item.quantity, item.productId]);
        final mov = InventoryMovement(
          id: _uuid.v4(),
          productId: item.productId,
          type: 'out',
          quantity: item.quantity,
          refSaleId: saleId,
        );
        await txn.insert('inventory_movements', mov.toMap());
      }
    });
  }

  Future<List<Map<String, dynamic>>> history({
    String? customerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await AppDatabase().database;
    final where = <String>[];
    final args = <dynamic>[];

    if (customerId != null && customerId.isNotEmpty) {
      where.add('s.customer_id = ?');
      args.add(customerId);
    }
    if (from != null) {
      where.add('s.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('s.created_at <= ?');
      args.add(to.toIso8601String());
    }

    final sql = '''
      SELECT s.id, s.created_at, s.total, s.discount, s.payment_method,
             c.name as customer_name
      FROM sales s
      LEFT JOIN customers c ON c.id = s.customer_id
      ${where.isEmpty ? '' : 'WHERE ' + where.join(' AND ')}
      ORDER BY s.created_at DESC
    ''';
    return db.rawQuery(sql, args);
  }
}
