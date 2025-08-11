import 'package:flutter/material.dart';

void main() {
  runApp(const app());
}

class app extends StatelessWidget {
  const app({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'popperscuventas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B615E)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4FAF9),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),
      home: const home(),
    );
  }
}

class home extends StatefulWidget {
  const home({super.key});

  @override
  State<home> createState() => _homeState();
}

class _homeState extends State<home> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('inicio'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            Text('contador: $count'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => count++),
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
              child: const Text('sumar'),
            ),
          ],
        ),
      ),
    );
  }
}
