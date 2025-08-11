import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  late Future<List<Map<String, dynamic>>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _productsFuture = DBHelper.instance.getProducts();
    _salesFuture = DBHelper.instance.getSales(orderDesc: true);
    setState(() {});
  }

  void _openNewSale() async {
    final products = await DBHelper.instance.getProducts();
    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero agrega productos')));
      }
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16),
        child: _SaleForm(onSaved: () {
          Navigator.pop(ctx);
          _reload();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openNewSale,
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Nueva venta'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _salesFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sales = snap.data!;
              if (sales.isEmpty) {
                return const Center(child: Text('Sin ventas aún'));
              }
              return ListView.separated(
                itemCount: sales.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = sales[i];
                  return ListTile(
                    title: Text('${s['product_name']}  x${s['quantity']}'),
                    subtitle: Text(s['created_at'] ?? ''),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Total: \$${(s['total'] as num).toStringAsFixed(2)}'),
                        Text('Util: \$${(s['utility'] as num).toStringAsFixed(2)}'),
                      ],
                    ),
                    onLongPress: () async {
                      await DBHelper.instance.deleteSale(s['id'] as int);
                      _reload();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SaleForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _SaleForm({required this.onSaved});

  @override
  State<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<_SaleForm> {
  Map<String, dynamic>? _selectedProduct;
  final _qty = TextEditingController(text: '1');
  final _discount = TextEditingController(text: '0'); // %
  final _payment = ValueNotifier<String>('efectivo'); // efectivo, transferencia, tarjeta

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBHelper.instance.getProducts(),
      builder: (context, snap) {
        final products = snap.data ?? [];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Registrar venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedProduct,
              items: products.map((p) => DropdownMenuItem(value: p, child: Text(p['name']))).toList(),
              onChanged: (v) => setState(() => _selectedProduct = v),
              decoration: const InputDecoration(labelText: 'Producto'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Descuento %'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: _payment,
              builder: (_, value, __) => DropdownButtonFormField<String>(
                value: value,
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                ],
                onChanged: (v) => _payment.value = v ?? 'efectivo',
                decoration: const InputDecoration(labelText: 'Forma de pago'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (_selectedProduct == null) return;
                      final qty = int.tryParse(_qty.text) ?? 1;
                      final disc = double.tryParse(_discount.text) ?? 0.0;
                      await DBHelper.instance.createSale(
                        productId: _selectedProduct!['id'] as int,
                        quantity: qty,
                        discountPercent: disc,
                        paymentMethod: _payment.value,
                      );
                      widget.onSaved();
                    },
                    child: const Text('Guardar venta'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}