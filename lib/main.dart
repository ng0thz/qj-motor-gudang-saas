import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/stock/stock_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const GudangSaaSApp());
}

class GudangSaaSApp extends StatelessWidget {
  const GudangSaaSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gudang SaaS - 500 SKU',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B2A4A)),
      home: const StockPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
