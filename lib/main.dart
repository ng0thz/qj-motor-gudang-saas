import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/stock/stock_page.dart';

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
      home: firebaseOk ? const StockPage() : const OfflineStockPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Fallback offline jika Firebase belum config (biar tidak blank hitam)
class OfflineStockPage extends StatelessWidget {
  const OfflineStockPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Offline Mode'), backgroundColor: const Color(0xFFE74C3C), foregroundColor: Colors.white),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        const Text('Firebase Belum Terhubung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('App jalan offline. Untuk sync ke Firestore qj-motor, tambahkan google-services.json dari Firebase Console.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const StockPage())), child: const Text('Coba Buka Stok (Offline 4385 SKU)')),
      ]))),
    );
  }
}
