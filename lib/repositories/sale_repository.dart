Future<void> createSale({
  String? customerId,
  required List<SaleItem> items,
  required double discount,
  required String paymentMethod,
}) async {
  final db = await AppDatabase().database;
  await db.transaction((txn) async {
    double subtotal = 0, costTotal = 0;
    for (final it in items) {
      subtotal += it.subtotal;
      costTotal += it.costAtSale * it.quantity;
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
