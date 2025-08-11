class Product {
  final String id;
  final String name;
  final String? sku;
  final double price;
  final int stock;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.sku,
    required this.price,
    required this.stock,
    this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    double? price,
    int? stock,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        name: m['name'] as String,
        sku: m['sku'] as String?,
        price: (m['price'] as num).toDouble(),
        stock: m['stock'] as int,
        category: m['category'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'price': price,
        'stock': stock,
        'category': category,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
