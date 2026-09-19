import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/stock/stock_page.dart';
import 'features/stock/offline_stock_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseOk = true;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    firebaseOk = false;
    debugPrint('Firebase init failed (no google-services.json) - running offline mode: $e');
  }
  runApp(GudangSaaSApp(firebaseOk: firebaseOk));
}

class GudangSaaSApp extends StatelessWidget {
  final bool firebaseOk;
  const GudangSaaSApp({super.key, this.firebaseOk = true});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gudang SaaS - QJ Motor 4385 SKU',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B2A4A)),
      home: firebaseOk ? const StockPage() : const OfflineStockPageFull(),
      debugShowCheckedModeBanner: false,
    );
  }
}
