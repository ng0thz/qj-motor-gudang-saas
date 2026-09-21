import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
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

  // Login Google KHUSUS Web (tombol disembunyikan di HP).
  // Hanya untuk email yang SUDAH didaftarkan Ops (ada users/{uid}).
  // Uid sama dengan akun email/password bila emailnya sama -> tidak bentrok.
  Future<void> loginGoogleWeb() async {
    if (!kIsWeb) throw const _GoogleHanyaWeb();
    final gUser = await GoogleSignIn().signIn();
    if (gUser == null) throw const _GoogleBatal();
    final gAuth = await gUser.authentication;
    final cred = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(accessToken: gAuth.accessToken, idToken: gAuth.idToken),
    );
    // Wajib terdaftar: tolak akun asing.
    bool terdaftar = false;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
      terdaftar = doc.exists;
    } catch (_) {
      terdaftar = false;
    }
    if (!terdaftar) {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      throw const _BelumTerdaftar();
    }
    await refreshSession(cred.user);
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

class _GoogleHanyaWeb implements Exception {
  const _GoogleHanyaWeb();
  @override
  String toString() => 'Login Google hanya tersedia di web.';
}

class _GoogleBatal implements Exception {
  const _GoogleBatal();
  @override
  String toString() => 'Login Google dibatalkan.';
}

class _BelumTerdaftar implements Exception {
  const _BelumTerdaftar();
  @override
  String toString() => 'Email Google ini belum didaftarkan Ops. Hubungi Ops Manager.';
}
