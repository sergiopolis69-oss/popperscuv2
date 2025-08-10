import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/client.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  Future<void> _importClientsCsv() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return;
    int imported = 0;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;
      final name = (r[0] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final phone = (r[1] ?? '').toString().trim();
      final email = (r[2] ?? '').toString().trim();
      await DBHelper.instance.upsertClient(name, phone: phone, email: email);
      imported++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clientes importados: $imported')));
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (_nameCtrl.text.trim().isEmpty) return;
                  await DBHelper.instance.upsertClient(_nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), email: _emailCtrl.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente guardado')));
                  }
                  _nameCtrl.clear(); _phoneCtrl.clear(); _emailCtrl.clear();
                  setState(() {});
                },
                child: const Text('Guardar'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: _importClientsCsv, icon: const Icon(Icons.upload_file), label: const Text('Importar CSV (name,phone,email)')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<ClientModel>>(
              future: DBHelper.instance.getClients().then((rows) => rows.map((e)=>ClientModel.fromMap(e)).toList()),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty) return const Center(child: Text('Sin clientes'));
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(items[i].name),
                    subtitle: Text([items[i].phone, items[i].email].where((e) => (e??'').isNotEmpty).join(' · ')),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
