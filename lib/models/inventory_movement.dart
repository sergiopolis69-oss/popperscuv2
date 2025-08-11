class InventoryMovement {
  final String id;
  final String productId;
  final String type; // 'in' | 'out' | 'adjust'
  final int quantity;
  final String? reason;
  final String? refSaleId;
  final DateTime createdAt;

  InventoryMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.reason,
    this.refSaleId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory InventoryMovement.fromMap(Map<String, dynamic> m) => InventoryMovement(
        id: m['id'] as String,
        productId: m['product_id'] as String,
        type: m['type'] as String,
        quantity: m['quantity'] as int,
        reason: m['reason'] as String?,
        refSaleId: m['ref_sale_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'type': type,
        'quantity': quantity,
        'reason': reason,
        'ref_sale_id': refSaleId,
        'created_at': createdAt.toIso8601String(),
      };
}
