import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  int? _productId;
  int _quantity = 1;
  int? _clientId;
  String _payment = 'Efectivo';
  double _discount = 0.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<Map<String,dynamic>>>(
            future: DBHelper.instance.getProducts(),
            builder: (_, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final items = snap.data!;
              return DropdownButtonFormField<int>(
                value: _productId,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: items.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text('${m['name']} (Stock ${m['quantity']})'))).toList(),
                onChanged: (v)=> setState(()=>_productId=v),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                  initialValue: '1',
                  onChanged: (v)=> _quantity = int.tryParse(v) ?? 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<List<Map<String,dynamic>>>(
                  future: DBHelper.instance.getClients(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final items = snap.data!;
                    return DropdownButtonFormField<int>(
                      value: _clientId,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: items.map((m)=>DropdownMenuItem(value: m['id'] as int, child: Text(m['name'].toString()))).toList(),
                      onChanged: (v)=> setState(()=> _clientId = v),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _payment,
                  decoration: const InputDecoration(labelText: 'Forma de pago'),
                  items: const ['Efectivo','Transferencia','Tarjeta'].map((p)=>DropdownMenuItem(value:p, child: Text(p))).toList(),
                  onChanged: (v)=> setState(()=> _payment = v ?? 'Efectivo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Descuento %'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  initialValue: '0',
                  onChanged: (v)=> _discount = double.tryParse(v) ?? 0.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (_productId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona producto')));
                return;
              }
              try {
                await DBHelper.instance.createSale(
                  productId: _productId!,
                  quantity: _quantity,
                  clientId: _clientId,
                  payment: _payment,
                  discountPercent: _discount,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta registrada')));
                }
                setState(() {});
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Guardar venta'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Text('Últimas ventas'),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String,dynamic>>>(
              future: DBHelper.instance.getSalesWithDetails(),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rows = snap.data!;
                if (rows.isEmpty) return const Text('Sin ventas aún');
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return ListTile(
                      title: Text('${r['product_name']} × ${r['quantity']}'),
                      subtitle: Text('${r['client'] ?? '—'} · ${r['payment']} · desc ${r['discount_percent']}%'),
                      trailing: Text('U: ${((r['utility'] as num?)??0).toStringAsFixed(2)}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
