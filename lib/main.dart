import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/qj_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/splash_page.dart';

// Catatan: JANGAN import firebase_options.dart di sini — file itu di-gitignore
// agar key asli tidak bocor. Setelah `flutterfire configure` (lihat
// docs/WEB_DESKTOP.md langkah aktivasi), ganti pemanggilan di bawah menjadi:
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// dan tambahkan: import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseOk = true;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    firebaseOk = false;
    debugPrint('Firebase init failed - running offline mode: $e');
  }
  runApp(GudangSaaSApp(firebaseOk: firebaseOk));
}

class GudangSaaSApp extends StatelessWidget {
  final bool firebaseOk;
  const GudangSaaSApp({super.key, this.firebaseOk = true});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QJ Motor - Gudang & Bengkel',
      theme: qjTheme(),
      home: SplashPage(firebaseOk: firebaseOk),
      debugShowCheckedModeBanner: false,
    );
  }
}
