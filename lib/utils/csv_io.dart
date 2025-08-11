import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class CsvIO {
  static Future<String> exportTable(String table) async {
    final db = await AppDatabase().database;
    final rows = await db.query(table);
    final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
    final data = <List<dynamic>>[headers];
    for (final r in rows) {
      data.add(headers.map((h) => r[h]).toList());
    }
    final csv = const ListToCsvConverter().convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$table.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  static Future<int> importProductsFromCsv() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (res == null || res.files.isEmpty) return 0;
    final file = File(res.files.single.path!);
    final csvStr = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(csvStr);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    final db = await AppDatabase().database;
    int inserted = 0;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      final m = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < r.length; j++) {
        m[headers[j]] = r[j];
      }
      if ((m['name'] ?? '').toString().trim().isEmpty) continue;
      final price = (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse('${m['price']}') ?? 0;
      final stock = (m['stock'] is num) ? (m['stock'] as num).toInt() : int.tryParse('${m['stock']}') ?? 0;
      final row = {
        'id': (m['id'] ?? '').toString().isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : '${m['id']}',
        'name': '${m['name']}',
        'sku': (m['sku']?.toString().isEmpty ?? true) ? null : '${m['sku']}',
        'price': price,
        'stock': stock,
        'category': (m['category']?.toString().isEmpty ?? true) ? null : '${m['category']}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
      inserted++;
    }
    return inserted;
  }

  static Future<int> importCustomersFromCsv() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (res == null || res.files.isEmpty) return 0;
    final file = File(res.files.single.path!);
    final csvStr = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(csvStr);
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString()).toList();
    final db = await AppDatabase().database;
    int inserted = 0;
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      final m = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < r.length; j++) {
        m[headers[j]] = r[j];
      }
      if ((m['name'] ?? '').toString().trim().isEmpty) continue;
      final row = {
        'id': (m['id'] ?? '').toString().isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : '${m['id']}',
        'name': '${m['name']}',
        'phone': (m['phone']?.toString().isEmpty ?? true) ? null : '${m['phone']}',
        'email': (m['email']?.toString().isEmpty ?? true) ? null : '${m['email']}',
        'notes': (m['notes']?.toString().isEmpty ?? true) ? null : '${m['notes']}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await db.insert('customers', row, conflictAlgorithm: ConflictAlgorithm.replace);
      inserted++;
    }
    return inserted;
  }
}
