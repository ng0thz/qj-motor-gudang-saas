import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  Stream<User?> get authState => _auth.authStateChanges();

  // Login email+password, lalu muat tenantId + role.
  // Urutan: custom claims (idToken) -> fallback dokumen users/{uid}.
  Future<void> loginEmail(String email, String pass) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: pass);
    await refreshSession(cred.user);
  }

  Future<void> refreshSession([User? user]) async {
    user ??= _auth.currentUser;
    if (user == null) return;
    final s = AuthSession.instance;
    s.uid = user.uid;
    s.email = user.email ?? '';
    String tenant = '';
    String role = '';
    try {
      final token = await user.getIdTokenResult(true);
      tenant = '${token.claims?['tenantId'] ?? ''}';
      role = '${token.claims?['role'] ?? ''}';
    } catch (_) {}
    if (tenant.isEmpty || role.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        tenant = tenant.isEmpty ? '${doc.data()?['tenantId'] ?? ''}' : tenant;
        role = role.isEmpty ? '${doc.data()?['role'] ?? ''}' : role;
      } catch (_) {}
    }
    s.tenantId = tenant.isEmpty ? 'qj-motor' : tenant;
    s.role = role;
    // Tolak akun yang dinonaktifkan Ops (aktif==false di users/{uid}).
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && (doc.data()?['aktif'] ?? true) == false) {
        await _auth.signOut();
        s.uid = '';
        throw const _AkunNonaktif();
      }
    } catch (e) {
      if (e is _AkunNonaktif) rethrow;
    }
  }

  // Mekanik: login anonymous, role diambil dari users/{uid} yg dibuat Ops.
  // Prod ideal: Function verifyMekanikPin -> setCustomClaim (belum dibuat).
  Future<UserCredential> loginMekanik() async {
    final cred = await _auth.signInAnonymously();
    await refreshSession(cred.user);
    return cred;
  }

  Future<void> logout() async {
    await _auth.signOut();
    AuthSession.instance.clear();
  }
}

class _AkunNonaktif implements Exception {
  const _AkunNonaktif();
  @override
  String toString() => 'Akun dinonaktifkan. Hubungi Ops Manager.';
}
