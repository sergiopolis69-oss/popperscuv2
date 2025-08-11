class Sale {
  final String id;
  final String? customerId;
  final double total;
  final double discount; // descuento total en monto
  final String paymentMethod;
  final DateTime createdAt;

  Sale({
    required this.id,
    this.customerId,
    required this.total,
    required this.discount,
    required this.paymentMethod,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as String,
        customerId: m['customer_id'] as String?,
        total: (m['total'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        paymentMethod: m['payment_method'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'payment_method': paymentMethod,
        'created_at': createdAt.toIso8601String(),
      };
}
