import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // Tenant dari session login (claims -> users/{uid} -> default qj-motor).
  // Hack displayName/photoURL lama sudah dihapus.
  String get tenantId => AuthSession.instance.tenantId;
  String get effectiveTenantId => AuthSession.instance.tenantId;

  CollectionReference<Map<String, dynamic>> col(String name) {
    return db.collection('tenants').doc(effectiveTenantId).collection(name);
  }

  DocumentReference<Map<String, dynamic>> doc(String col, String id) {
    return db.collection('tenants').doc(effectiveTenantId).collection(col).doc(id);
  }
}
