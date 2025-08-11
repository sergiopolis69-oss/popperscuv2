import 'dart:convert'; import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db.dart';

class CsvIO {
  static Future<String> exportTableToDownloads(String table) async {
    final db = await AppDatabase().database;
    final rows = await db.query(table);
    final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
    final data = <List<dynamic>>[headers];
    for (final r in rows) { data.add(headers.map((h) => r[h]).toList()); }
    final csv = const ListToCsvConverter().convert(data);
    final savedPath = await FileSaver.instance.saveFile(
      name: '$table.csv',
      bytes: utf8.encode(csv),
      mimeType: MimeType.csv,
    );
    return savedPath ?? 'Descargas';
  }

  // ... (deja también exportTableLocal e importProducts/Customers como los tenías)
}
