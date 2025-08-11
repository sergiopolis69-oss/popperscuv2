import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/sale_repository.dart';
import '../repositories/customer_repository.dart';
import '../models/customer.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String? _customerId;
  DateTime? _from;
  DateTime? _to;

  Future<List<Customer>> _loadCustomers() => CustomerRepository().all();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _customerPicker()),
                const SizedBox(width: 8),
                Expanded(child: _dateButton('Desde', (d){ setState(()=> _from = d); })),
                const SizedBox(width: 8),
                Expanded(child: _dateButton('Hasta', (d){ setState(()=> _to = d); })),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: ()=> setState((){}), child: const Text('Buscar')),
            const Divider(height: 16),
            Expanded(child: _results()),
          ],
        ),
      ),
    );
  }

  Widget _customerPicker() {
    return FutureBuilder<List<Customer>>(
      future: _loadCustomers(),
      builder: (c, snap) {
        final list = snap.data ?? [];
        return DropdownButtonFormField<String>(
          value: _customerId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos los clientes')),
            ...list.map((e)=> DropdownMenuItem(value: e.id, child: Text(e.name)))
          ],
          onChanged: (v)=> _customerId = v,
          decoration: const InputDecoration(labelText: 'Cliente'),
        );
      },
    );
  }

  Widget _dateButton(String label, void Function(DateTime?) onPick) {
    final fmt = DateFormat('yyyy-MM-dd');
    final current = (label=='Desde') ? _from : _to;
    return OutlinedButton(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        onPick(picked);
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: ${current == null ? '-' : fmt.format(current)}'),
      ),
    );
  }

  Widget _results() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SaleRepository().history(customerId: _customerId, from: _from, to: _to),
      builder: (c, snap) {
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const Center(child: Text('Sin resultados'));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (c, i) {
            final r = rows[i];
            return ListTile(
              title: Text('Total: ${r['total']}  | Descuento: ${r['discount']}  | Pago: ${r['payment_method']}'),
              subtitle: Text('${r['customer_name'] ?? '(sin cliente)'} — ${r['created_at']}'),
            );
          },
        );
      },
    );
  }
}
