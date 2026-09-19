import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  // Staff/Frontdesk/Ops: Email+Pass
  Future<UserCredential> loginEmail(String email, String pass) {
    return _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  // Mekanik: QR PIN -> Anonymous + custom claim via Function
  Future<UserCredential> loginMekanik(String mekanikId, String pin) async {
    // Untuk MVP: Anonymous login, role disimpan di Firestore users/{uid}
    // Prod: panggil Function verifyMekanikPin({mekanikId, pin}) -> setCustomClaim
    return await _auth.signInAnonymously();
  }

  Future<void> logout() => _auth.signOut();

  String? get role {
    // Baca dari ID token custom claim (prod) atau Firestore users (dev)
    return _auth.currentUser?.displayName; // placeholder
  }
}
