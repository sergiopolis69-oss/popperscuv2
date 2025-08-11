import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';

final productRepoProvider = Provider((ref) => ProductRepository());
final customerRepoProvider = Provider((ref) => CustomerRepository());
final saleRepoProvider = Provider((ref) => SaleRepository());

final productsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.watch(productRepoProvider).all();
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  return ref.watch(customerRepoProvider).all();
});
