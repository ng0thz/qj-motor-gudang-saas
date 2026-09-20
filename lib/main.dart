import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/qj_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/splash_page.dart';

// Config Firebase di-commit (apiKey Web publik, standar FlutterFire).
// Hanya serviceAccountKey.json yang rahasia dan tetap di-gitignore.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseOk = true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
