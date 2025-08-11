class SaleItem {
  final String id, saleId, productId;
  final int quantity;
  final double price, costAtSale, lineDiscount;
  final double subtotal; // = price*quantity - lineDiscount, mínimo 0
  ...
}
