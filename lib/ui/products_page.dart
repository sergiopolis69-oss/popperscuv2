import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../providers/providers.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: productsAsync.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (c, i) {
            final p = items[i];
            return ListTile(
              title: Text(p.name),
              subtitle: Text('SKU: ${p.sku ?? '-'}  |  Stock: ${p.stock}  |  ${p.price.toStringAsFixed(2)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _openForm(edit: p)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                    await ref.read(productRepoProvider).delete(p.id);
                    setState((){});
                  }),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _openForm({Product? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final skuCtrl = TextEditingController(text: edit?.sku ?? '');
    final priceCtrl = TextEditingController(text: edit?.price.toString() ?? '0');
    final stockCtrl = TextEditingController(text: edit?.stock.toString() ?? '0');
    final categoryCtrl = TextEditingController(text: edit?.category ?? '');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(edit == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Categoría')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () async {
            final repo = ref.read(productRepoProvider);
            if (edit == null) {
              final p = Product(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 0,
                stock: int.tryParse(stockCtrl.text) ?? 0,
                category: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
              );
              await repo.create(p);
            } else {
              final p = edit.copyWith(
                name: nameCtrl.text.trim(),
                sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? edit.price,
                stock: int.tryParse(stockCtrl.text) ?? edit.stock,
                category: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                updatedAt: DateTime.now(),
              );
              await repo.update(p);
            }
            if (mounted) Navigator.pop(c);
            setState((){});
          }, child: const Text('Guardar'))
        ],
      ),
    );
  }
}
