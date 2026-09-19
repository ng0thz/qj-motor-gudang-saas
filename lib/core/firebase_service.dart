import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // TenantId Production QJ Motor - REAL
  String get tenantId => auth.currentUser?.displayName ?? 'qj-motor';
  String get effectiveTenantId {
    final claimTenant = auth.currentUser?.photoURL;
    if (claimTenant != null && claimTenant.isNotEmpty) return claimTenant;
    return 'qj-motor'; // PRODUCTION QJ Motor Free
  }

  CollectionReference<Map<String, dynamic>> col(String name) {
    return db.collection('tenants').doc(effectiveTenantId).collection(name);
  }

  DocumentReference<Map<String, dynamic>> doc(String col, String id) {
    return db.collection('tenants').doc(effectiveTenantId).collection(col).doc(id);
  }
}
