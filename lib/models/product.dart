class Product {
  final int id;
  final String sku;
  final String name;
  final String brand;
  final String size;
  final String origin;
  final double cost;
  final double price;
  final int quantity;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.brand,
    required this.size,
    required this.origin,
    required this.cost,
    required this.price,
    required this.quantity,
  });

  factory Product.fromMap(Map<String,dynamic> m) => Product(
    id: m['id'] as int,
    sku: (m['sku'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    brand: (m['brand'] ?? '').toString(),
    size: (m['size'] ?? '').toString(),
    origin: (m['origin'] ?? '').toString(),
    cost: (m['cost'] as num).toDouble(),
    price: (m['price'] as num).toDouble(),
    quantity: m['quantity'] as int,
  );
}
