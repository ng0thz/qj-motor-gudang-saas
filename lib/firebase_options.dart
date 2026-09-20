// Config Firebase asli proyek gudang-saas-platform.
// apiKey Web bersifat publik (wajar di-commit, standar FlutterFire).
// JANGAN commit serviceAccountKey.json (server, rahasia) — tetap di .gitignore.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAuBthxHbxp17UWWsB0CipsetTT5AyMwsk',
    appId: '1:437791084895:web:218917ae1c45707bad66ea',
    messagingSenderId: '437791084895',
    projectId: 'gudang-saas-platform',
    authDomain: 'gudang-saas-platform.firebaseapp.com',
    storageBucket: 'gudang-saas-platform.firebasestorage.app',
  );

  // TODO: daftarkan aplikasi Android di Console (package
  // com.qjmotor.saas.gudang_saas), lalu ganti appId di bawah dengan
  // mobilesdk_app_id dari google-services.json. Sementara memakai nilai
  // proyek yang sama agar build tidak gagal.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAuBthxHbxp17UWWsB0CipsetTT5AyMwsk',
    appId: '1:437791084895:web:218917ae1c45707bad66ea',
    messagingSenderId: '437791084895',
    projectId: 'gudang-saas-platform',
    storageBucket: 'gudang-saas-platform.firebasestorage.app',
  );
}
