import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../providers/providers.dart';
import '../repositories/customer_repository.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: customersAsync.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (c, i) {
            final p = items[i];
            return ListTile(
              title: Text(p.name),
              subtitle: Text('${p.phone ?? '-'}  |  ${p.email ?? '-'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _openForm(edit: p)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                    await ref.read(customerRepoProvider).delete(p.id);
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

  Future<void> _openForm({Customer? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final phoneCtrl = TextEditingController(text: edit?.phone ?? '');
    final emailCtrl = TextEditingController(text: edit?.email ?? '');
    final notesCtrl = TextEditingController(text: edit?.notes ?? '');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(edit == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notas')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () async {
            final repo = ref.read(customerRepoProvider);
            if (edit == null) {
              await repo.create(Customer(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              ));
            } else {
              await repo.update(Customer(
                id: edit.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                createdAt: edit.createdAt,
                updatedAt: DateTime.now(),
              ));
            }
            if (mounted) Navigator.pop(c);
            setState((){});
          }, child: const Text('Guardar'))
        ],
      ),
    );
  }
}
