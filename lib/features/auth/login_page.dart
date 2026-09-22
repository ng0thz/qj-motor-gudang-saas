import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../../core/qj_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool showPass = false;
  late final AnimationController _logoAnim;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _logoAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
    _scale = CurvedAnimation(parent: _logoAnim, curve: Curves.easeOutCubic);
    _glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoAnim, curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _logoAnim.forward());
  }

  @override
  void dispose() {
    _logoAnim.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void _bounce() => _logoAnim.forward(from: 0);

  Future<void> _login() async {
    _bounce();
    setState(() { loading = true; error = null; });
    try {
      await AuthService().loginEmail(emailCtrl.text, passCtrl.text);
    } on FirebaseAuthException catch (e) {
      setState(() => error = _pesan(e.code));
    } catch (e) {
      setState(() => error = 'Gagal login: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loginGoogle() async {
    _bounce();
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [QjColors.navy, QjColors.navyDark],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _logoAnim,
                  builder: (_, child) {
                    final s = 0.82 + 0.18 * _scale.value;
                    final g = _glow.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220 + 40 * g,
                          height: 90 + 40 * g,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: QjColors.red.withOpacity(0.22 * (1 - g * 0.5)),
                                blurRadius: 40 + 20 * g,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(scale: s, child: child),
                      ],
                    );
                  },
                  child: Column(
                    children: [
                      Image.asset('assets/qj_logo_white.png', width: 220,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.two_wheeler, color: Colors.white, size: 64)),
                      const SizedBox(height: 10),
                      Container(
                        width: 48, height: 2,
                        decoration: BoxDecoration(
                          color: QjColors.red, borderRadius: BorderRadius.circular(1)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('QJ Motor',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const Text('Gudang & Bengkel  \u2022  ALWAYS FORWARD',
                  style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailCtrl, keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passCtrl, obscureText: !showPass,
                          decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(),
                            suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => showPass = !showPass))),
                          onSubmitted: (_) => _login(),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QjColors.red, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('MASUK', style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: loading ? null : _loginGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 24),
                              label: const Text('Masuk dengan Google'),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Akun dibuat oleh Ops Manager.\nMekanik: gunakan akun yang didaftarkan.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
