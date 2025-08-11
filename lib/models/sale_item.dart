class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double price;
  final double lineDiscount; // descuento por línea en monto
  final double subtotal;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.lineDiscount = 0,
  }) : subtotal = (price * quantity - lineDiscount) < 0 ? 0 : (price * quantity - lineDiscount);

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        id: m['id'] as String,
        saleId: m['sale_id'] as String,
        productId: m['product_id'] as String,
        quantity: m['quantity'] as int,
        price: (m['price'] as num).toDouble(),
        lineDiscount: (m['line_discount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'price': price,
        'line_discount': lineDiscount,
        'subtotal': subtotal,
      };
}
