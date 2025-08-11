import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/db_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _exporting = false;
  String? _lastPath;
  final _buffer = StringBuffer();

  Future<String> _writeCsv(String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${dir.path}/$prefix_$ts.csv';
    final f = File(path);
    await f.writeAsString(_buffer.toString());
    return path;
  }

  Future<void> _export(Future<String> Function() producer) async {
    setState(() {
      _exporting = true;
      _lastPath = null;
      _buffer.clear();
    });
    try {
      final path = await producer();
      setState(() => _lastPath = path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV guardado: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export(() async {
              final rows = await DBHelper.instance.getProducts();
              _buffer.writeln(['id','name','category','price_buy','price_sell','stock','utility_unit'].join(','));
              for (final r in rows) {
                final util = (r['price_sell'] as num) - (r['price_buy'] as num);
                _buffer.writeln([
                  r['id'], _s(r['name']), _s(r['category']),
                  (r['price_buy'] as num).toStringAsFixed(2),
                  (r['price_sell'] as num).toStringAsFixed(2),
                  r['stock'],
                  util.toStringAsFixed(2)
                ].join(','));
              }
              return _writeCsv('inventario');
            }),
            icon: const Icon(Icons.download),
            label: const Text('Exportar inventario a CSV'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export(() async {
              final rows = await DBHelper.instance.getSales(orderDesc: true);
              _buffer.writeln(['id','created_at','product_name','quantity','price_buy','price_sell','discount_percent','payment','total','utility'].join(','));
              for (final r in rows) {
                _buffer.writeln([
                  r['id'],
                  _s(r['created_at']),
                  _s(r['product_name']),
                  r['quantity'],
                  (r['price_buy'] as num).toStringAsFixed(2),
                  (r['price_sell'] as num).toStringAsFixed(2),
                  (r['discount_percent'] as num).toStringAsFixed(2),
                  _s(r['payment']),
                  (r['total'] as num).toStringAsFixed(2),
                  (r['utility'] as num).toStringAsFixed(2),
                ].join(','));
              }
              return _writeCsv('ventas');
            }),
            icon: const Icon(Icons.download_for_offline),
            label: const Text('Exportar ventas a CSV'),
          ),
          const SizedBox(height: 16),
          if (_lastPath != null)
            OutlinedButton.icon(
              onPressed: () async {
                await Share.shareXFiles([XFile(_lastPath!)], text: 'Reporte CSV');
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir CSV'),
            ),
        ],
      ),
    );
  }
}

String _s(Object? v) => (v ?? '').toString().replaceAll(',', ' ');
