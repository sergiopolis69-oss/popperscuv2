import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DBHelper.instance.getProducts();
  }

  void _refresh() {
    setState(() {
      _future = DBHelper.instance.getProducts();
    });
  }

  void _openNewProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16),
        child: _ProductForm(onSaved: () {
          Navigator.pop(ctx);
          _refresh();
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
                  onPressed: _openNewProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar producto'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const Center(child: Text('Sin productos'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = items[i];
                  final utilidadUnit = (p['price_sell'] ?? 0) - (p['price_buy'] ?? 0);
                  return ListTile(
                    title: Text(p['name'] ?? ''),
                    subtitle: Text('Cat: ${p['category'] ?? '-'}  |  Stock: ${p['stock']}'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('\$${(p['price_sell'] ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Utl: \$${utilidadUnit.toStringAsFixed(2)}'),
                      ],
                    ),
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => Padding(
                          padding: EdgeInsets.only(
                              bottom: MediaQuery.of(ctx).viewInsets.bottom,
                              left: 16, right: 16, top: 16),
                          child: _ProductForm(existing: p, onSaved: () {
                            Navigator.pop(ctx);
                            _refresh();
                          }),
                        ),
                      );
                    },
                    onLongPress: () async {
                      await DBHelper.instance.deleteProduct(p['id'] as int);
                      _refresh();
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

class _ProductForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _ProductForm({this.existing, required this.onSaved});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _priceBuy = TextEditingController();
  final _priceSell = TextEditingController();
  final _stock = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e['name'] ?? '';
      _category.text = e['category'] ?? '';
      _priceBuy.text = (e['price_buy'] ?? 0).toString();
      _priceSell.text = (e['price_sell'] ?? 0).toString();
      _stock.text = (e['stock'] ?? 0).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.existing == null ? 'Nuevo producto' : 'Editar producto',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceBuy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio compra'),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Número' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceSell,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio venta'),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Número' : null,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock'),
              validator: (v) => (int.tryParse(v ?? '') == null) ? 'Entero' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (!(_form.currentState?.validate() ?? false)) return;
                      final data = {
                        'name': _name.text.trim(),
                        'category': _category.text.trim(),
                        'price_buy': double.parse(_priceBuy.text),
                        'price_sell': double.parse(_priceSell.text),
                        'stock': int.parse(_stock.text),
                      };
                      if (widget.existing == null) {
                        await DBHelper.instance.insertProduct(data);
                      } else {
                        await DBHelper.instance.updateProduct(widget.existing!['id'] as int, data);
                      }
                      widget.onSaved();
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
