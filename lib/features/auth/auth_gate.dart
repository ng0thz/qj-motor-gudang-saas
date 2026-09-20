import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../stock/offline_stock_page.dart';
import '../stock/stock_page.dart';
import 'login_page.dart';

// Gerbang: belum login -> LoginPage. Sudah login -> muat session -> StockPage.
// Mode offline (firebase gagal init) -> langsung halaman offline tanpa login.
class AuthGate extends StatelessWidget {
  final bool firebaseOk;
  const AuthGate({super.key, required this.firebaseOk});

  @override
  Widget build(BuildContext context) {
    if (!firebaseOk) return const OfflineStockPageFull();
    return StreamBuilder<User?>(
      stream: AuthService().authState,
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) return const LoginPage();
        return FutureBuilder(
          future: AuthService().refreshSession(snap.data),
          builder: (c2, s2) {
            if (s2.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const StockPage();
          },
        );
      },
    );
  }
}
