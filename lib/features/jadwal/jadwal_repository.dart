import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';

// Siklus PIKET SIANG kebersihan + standby 12:00-13:00 (dari file roster).
// Pasangan bergantian tiap hari kalender:
//   Pair 0 = Rangga + Wahyu, Pair 1 = Asahatta + Elvan.
// Jangkar: Jumat 25 Sep 2026 = Pair 0 (cocok: 25,28,30 = R+W; 26,29 = A+E).
// Minggu OFF semua; Senin memakai jatah Minggu (Minggu & Senin indeks sama).
class JadwalMath {
  static const pair0 = ['ranggaadisaputra024@gmail.com', 'wahyusurya16@icloud.com'];
  static const pair1 = ['deejayasa63@gmail.com', 'elvanpramudiansyah@gmail.com'];
  static final anchor = DateTime(2026, 9, 25); // Jumat, Pair 0

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _mod(int a, int n) => ((a % n) + n) % n;

  // Indeks = jumlah HARI KERJA (non-Minggu) dari jangkar, Senin-Sabtu.
  // Minggu tidak dihitung (OFF) sehingga Senin otomatis memakai jatah Minggu.
  static int pairOf(DateTime d) {
    if (d.weekday == DateTime.sunday) return -1;
    final t = DateTime(d.year, d.month, d.day);
    final b = DateTime(anchor.year, anchor.month, anchor.day);
    if (t.isAtSameMomentAs(b)) return 0;
    var workdays = 1; // jangkar ikut dihitung
    if (t.isAfter(b)) {
      var cur = b.add(const Duration(days: 1));
      while (!cur.isAfter(t)) {
        if (cur.weekday != DateTime.sunday) workdays++;
        cur = cur.add(const Duration(days: 1));
      }
    } else {
      var cur = t;
      while (cur.isBefore(b)) {
        if (cur.weekday != DateTime.sunday) workdays--;
        cur = cur.add(const Duration(days: 1));
      }
    }
    return _mod(workdays - 1, 2);
  }

  static List<String> pairEmails(DateTime d) {
    final p = pairOf(d);
    if (p < 0) return [];
    return p == 0 ? pair0 : pair1;
  }
}

// Check-off piket siang 12:00-13:00.
// Koleksi: tenants/{tid}/piket_siang/{yyyy-MM-dd} {pair, emails, check:{oleh,at}}.
class JadwalRepo {
  final _fs = FirebaseService.instance;

  String keyOf(DateTime d) => JadwalMath.keyOf(d);
  int pairOf(DateTime d) => JadwalMath.pairOf(d);
  List<String> pairEmails(DateTime d) => JadwalMath.pairEmails(d);

  DocumentReference<Map<String, dynamic>> _doc(String key) =>
      _fs.col('piket_siang').doc(key);

  Stream<Map<String, dynamic>?> watchSiang(String key) {
    return _doc(key).snapshots().map((d) => d.data());
  }

  Future<void> checkSiang({required String key, required int pair, required List<String> emails}) async {
    await _doc(key).set({
      'tanggal': key,
      'pair': pair,
      'emails': emails,
      'check': {
        'oleh': _fs.auth.currentUser?.email ?? '',
        'at': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
