class Product {
  final String id, name; final String? sku, category;
  final double cost;   // compra
  final double price;  // venta
  final int stock;
  final DateTime createdAt, updatedAt;
  ...
  factory Product.fromMap(Map<String,dynamic> m)=>Product(
    id:m['id'], name:m['name'], sku:m['sku'],
    cost:(m['cost_price'] as num?)?.toDouble()??0,
    price:(m['sale_price'] as num?)?.toDouble() ??
          (m['price'] as num).toDouble(), // compatibilidad
    stock:m['stock'], category:m['category'],
    createdAt:DateTime.parse(m['created_at']),
    updatedAt:DateTime.parse(m['updated_at']),
  );
  Map<String,dynamic> toMap()=> {
    'id':id,'name':name,'sku':sku,'cost_price':cost,'sale_price':price,
    'stock':stock,'category':category,
    'created_at':createdAt.toIso8601String(),
    'updated_at':updatedAt.toIso8601String(),
  };
}
