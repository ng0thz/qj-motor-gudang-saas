import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool showPass = false;

  Future<void> _login() async {
    setState(() { loading = true; error = null; });
    try {
      await AuthService().loginEmail(emailCtrl.text, passCtrl.text);
      // AuthGate otomatis pindah via authStateChanges
    } on FirebaseAuthException catch (e) {
      setState(() => error = _pesan(e.code));
    } catch (e) {
      setState(() => error = 'Gagal login: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loginGoogle() async {
    setState(() { loading = true; error = null; });
    try {
      await AuthService().loginGoogleWeb();
    } on FirebaseAuthException catch (e) {
      setState(() => error = _pesan(e.code));
    } catch (e) {
      setState(() => error = '$e');
    }
    if (mounted) setState(() => loading = false);
  }

  String _pesan(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun dinonaktifkan. Hubungi Ops Manager.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Tidak ada koneksi. Periksa internet / gunakan mode offline.';
      default:
        return 'Gagal login ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2A4A),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
        Image.asset('assets/qjmotor_logo_transparent.png', height: 72,
          errorBuilder: (_, __, ___) => const Icon(Icons.build, color: Colors.white, size: 56)),
        const SizedBox(height: 12),
        const Text('QJ Motor', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Gudang & Bengkel SaaS', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 28),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: passCtrl, obscureText: !showPass,
            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showPass = !showPass))),
            onSubmitted: (_) => _login()),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: loading ? null : _login,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
            child: loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('MASUK'),
          )),
          if (kIsWeb) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: loading ? null : _loginGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Masuk dengan Google'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
          ],
        ]))),
        const SizedBox(height: 12),
        const Text('Akun dibuat oleh Ops Manager.\nMekanik: gunakan akun yang didaftarkan.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11)),
      ]))),
    );
  }
}
