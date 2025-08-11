import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale_item.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _uuid = const Uuid();
  final _items = <SaleItem>[];
  String? _customerId;
  double _discount = 0;
  String _paymentMethod = 'Cash';

  Future<List<Product>> _loadProducts() => ProductRepository().all();
  Future<List<Customer>> _loadCustomers() => CustomerRepository().all();

  double get _subtotal => _items.fold(0.0, (p, e) => p + e.subtotal);
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS / Ventas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            FutureBuilder<List<Customer>>(
              future: _loadCustomers(),
              builder: (c, snap) {
                final list = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _customerId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Cliente: (no asignado)')),
                    ...list.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                  decoration: const InputDecoration(labelText: 'Cliente'),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '0',
                    decoration: const InputDecoration(labelText: 'Descuento total (monto)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'Card', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'Transfer', child: Text('Transferencia')),
                      DropdownMenuItem(value: 'Other', child: Text('Otro')),
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                    decoration: const InputDecoration(labelText: 'Forma de pago'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _loadProducts(),
                builder: (c, snap) {
                  final list = snap.data ?? [];
                  return ListView(
                    children: [
                      const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final p in list)
                        ListTile(
                          title: Text(p.name),
                          subtitle: Text('Stock: ${p.stock}  |  ${p.price.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () => _addItemDialog(p),
                          ),
                        ),
                      const Divider(height: 24),
                      const Text('Carrito', style: TextStyle(fontWeight: FontWeight.bold)),
                      for (int i=0; i<_items.length; i++)
                        ListTile(
                          title: Text('x${_items[i].quantity} — ${_items[i].productId}'),
                          subtitle: Text('Precio: ${_items[i].price.toStringAsFixed(2)}  | Desc. línea: ${_items[i].lineDiscount.toStringAsFixed(2)}  | Subtotal: ${_items[i].subtotal.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _editItemDialog(i)),
                              IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(()=> _items.removeAt(i))),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal: ${_subtotal.toStringAsFixed(2)}'),
                Text('Total: ${_total.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Guardar venta'),
              onPressed: _items.isEmpty ? null : _saveSale,
            )
          ],
        ),
      ),
    );
  }

  Future<void> _addItemDialog(Product p) async {
    final qty = TextEditingController(text: '1');
    final disc = TextEditingController(text: '0');
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Agregar: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad')),
            TextField(controller: disc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Descuento por línea (monto)')),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: (){
            final q = int.tryParse(qty.text) ?? 1;
            final d = double.tryParse(disc.text) ?? 0;
            setState((){
              _items.add(SaleItem(
                id: _uuid.v4(),
                saleId: 'temp',
                productId: p.id,
                quantity: q,
                price: p.price,
                lineDiscount: d,
              ));
            });
            Navigator.pop(c);
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  Future<void> _editItemDialog(int index) async {
    final it = _items[index];
    final qty = TextEditingController(text: it.quantity.toString());
    final disc = TextEditingController(text: it.lineDiscount.toString());
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Editar línea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad')),
            TextField(controller: disc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Descuento por línea (monto)')),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: (){
            final q = int.tryParse(qty.text) ?? it.quantity;
            final d = double.tryParse(disc.text) ?? it.lineDiscount;
            setState((){
              _items[index] = SaleItem(
                id: it.id,
                saleId: it.saleId,
                productId: it.productId,
                quantity: q,
                price: it.price,
                lineDiscount: d,
              );
            });
            Navigator.pop(c);
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _saveSale() async {
    final repo = SaleRepository();
    await repo.createSale(
      customerId: _customerId,
      items: _items.toList(),
      discount: _discount,
      paymentMethod: _paymentMethod,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
      setState((){
        _items.clear();
        _customerId = null;
        _discount = 0;
        _paymentMethod = 'Cash';
      });
    }
  }
}
