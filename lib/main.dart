// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/products_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inventario',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0A84FF)),
      home: const ProductsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
