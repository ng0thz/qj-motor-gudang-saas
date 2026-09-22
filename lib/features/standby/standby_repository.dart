import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';
import '../stock/stock_repository.dart';

// Matematika rotasi murni TANPA Firebase (bisa unit-test).
// Rotasi D->A->B->C jangkar Senin 21 Sep 2026 = Asahatta (D).
class StandbyMath {
  static const kap = 3;
  static const rotasiEmail = [
    'deejayasa63@gmail.com',
    'wahyusurya16@icloud.com',
    'ranggaadisaputra024@gmail.com',
    'elvanpramudiansyah@gmail.com',
  ];
  static final anchor = DateTime(2026, 9, 21);
  static const pit1 = ['wahyusurya16@icloud.com', 'ranggaadisaputra024@gmail.com'];
  static const pit2 = ['elvanpramudiansyah@gmail.com', 'deejayasa63@gmail.com'];

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _idx(DateTime? now) {
    final t = now ?? DateTime.now();
    final a = DateTime(t.year, t.month, t.day);
    final b = DateTime(anchor.year, anchor.month, anchor.day);
    var idx = (a.difference(b).inDays) % rotasiEmail.length;
    if (idx < 0) idx += rotasiEmail.length;
    return idx;
  }

  static List<String> rotasiHariIni([DateTime? now]) {
    final idx = _idx(now);
    return List.generate(
      rotasiEmail.length, (i) => rotasiEmail[(idx + i) % rotasiEmail.length]);
  }

  static Map<String, dynamic> distribute({
    required int units,
    required Map<String, int> tab,
    required Map<String, int> hutang,
    DateTime? now,
  }) {
    final rotasi = rotasiHariIni(now);
    final dist = <Map<String, dynamic>>[];
    var sisa = units;
    for (final e in rotasi) {
      if (sisa <= 0) break;
      final saldo = tab[e] ?? 0;
      if (saldo > 0) {
        final ambil = saldo < sisa ? saldo : sisa;
        dist.add({'email': e, 'unit': ambil, 'dariTabungan': true});
        sisa -= ambil;
      }
    }
    var putaran = 0;
    while (sisa > 0 && putaran < 5) {
      var adaAmbil = false;
      for (final e in rotasi) {
        if (sisa <= 0) break;
        final sudah = dist.where((h) => h['email'] == e && h['dariTabungan'] != true)
            .fold<int>(0, (t, h) => t + (h['unit'] as int));
        final capEff = kap - (((hutang[e] ?? 0).clamp(0, kap)) as int);
        final ruang = capEff - sudah;
        if (ruang <= 0) continue;
        final ambil = ruang < sisa ? ruang : sisa;
        dist.add({'email': e, 'unit': ambil, 'dariTabungan': false});
        sisa -= ambil;
        adaAmbil = true;
      }
      if (!adaAmbil) break;
      putaran++;
    }
    final gabung = <String, Map<String, dynamic>>{};
    for (final h in dist) {
      final e = h['email'] as String;
      gabung.putIfAbsent(e, () => {'email': e, 'unit': 0, 'dariTabungan': false});
      gabung[e]!['unit'] = (gabung[e]!['unit'] as int) + (h['unit'] as int);
      if (h['dariTabungan'] == true) gabung[e]!['dariTabungan'] = true;
    }
    final hasil = rotasi.where((e) => gabung.containsKey(e)).map((e) => gabung[e]!).toList();

    final tabBaru = Map<String, int>.from(tab);
    for (final item in hasil) {
      final e = item['email'] as String;
      final u = item['unit'] as int;
      final h0 = hutang[e] ?? 0;
      if (item['dariTabungan'] == true) {
        tabBaru[e] = (tabBaru[e] ?? 0) - u;
        if (tabBaru[e]! < 0) tabBaru[e] = 0;
      }
      if (u < kap && h0 <= 0) {
        tabBaru[e] = (tabBaru[e] ?? 0) + (kap - u);
      }
    }
    final hutangBaru = Map<String, int>.from(hutang);
    if (units > 0) {
      for (final e in rotasi) {
        final h0 = hutangBaru[e] ?? 0;
        if (h0 > 0) {
          final lunas = h0 < kap ? h0 : kap;
          hutangBaru[e] = h0 - lunas;
        }
      }
    }
    return {'dist': hasil, 'tabBaru': tabBaru, 'hutangBaru': hutangBaru};
  }
}

// Standby ambil PDI (dulu file jadwal-mekanik.html -> kini Firestore multi-HP).
// Rotasi D->A->B->C jangkar Senin 21 Sep 2026 = Asahatta (D).
// Aturan: tabungan positif dipakai duluan -> bagi searah rotasi, maks 3/orang.
// Request khusus memotong antrean + dicatat HUTANG (jatah efektif 3-min(hutang,3),
// lunas maks 3/hari). Minggu OFF (level UI).
class StandbyRepo {
  final _fs = FirebaseService.instance;
  final _wo = StockRepository();

  static const kap = StandbyMath.kap;
  // Slot rotasi by email (stabil walau nama berubah).
  // D=Asahatta, A=Wahyu (kepala), B=Rangga, C=Elvan.
  static const rotasiEmail = StandbyMath.rotasiEmail;
  static final anchor = StandbyMath.anchor;
  static const pit1 = StandbyMath.pit1;
  static const pit2 = StandbyMath.pit2;

  String keyOf(DateTime d) => StandbyMath.keyOf(d);

  // Urutan rotasi hari ini (daftar email).
  List<String> rotasiHariIni([DateTime? now]) => StandbyMath.rotasiHariIni(now);

  // Distribusi murni (port hitungPDIReguler + utang request).
  // tab/hutang: email -> saldo. Return {dist, tabBaru, hutangBaru}.
  Map<String, dynamic> distribute({
    required int units,
    required Map<String, int> tab,
    required Map<String, int> hutang,
    DateTime? now,
  }) =>
      StandbyMath.distribute(units: units, tab: tab, hutang: hutang, now: now);

  DocumentReference<Map<String, dynamic>> _doc(String key) =>
      _fs.col('standby_harian').doc(key);

  Stream<Map<String, dynamic>?> watchDay(String key) {
    return _doc(key).snapshots().map((d) => d.data());
  }

  Future<List<Map<String, dynamic>>> _antreanUmum() async {
    final all = await _wo.fetchPDIBookings(limit: 200);
    final antre = all.where((w) {
      final st = '${w['status']}'.toUpperCase();
      return st != 'SELESAI' && st != 'BATAL' && '${w['mekanikUid'] ?? ''}'.isEmpty;
    }).toList();
    antre.sort((a, b) {
      final ta = (a['createdAt'] as Timestamp?);
      final tb = (b['createdAt'] as Timestamp?);
      if (ta == null || tb == null) return 0;
      return ta.compareTo(tb);
    });
    return antre;
  }

  // Generate/refresh hari ini. Units default = antrean umum. Hanya Ops.
  Future<void> generateDay({int? unitsOverride}) async {
    final key = keyOf(DateTime.now());
    final prevSnap = await _fs.col('standby_harian')
        .orderBy('tanggal', descending: true)
        .limit(1)
        .get();
    Map<String, int> tab = {};
    Map<String, int> hut = {};
    if (prevSnap.docs.isNotEmpty) {
      final m = prevSnap.docs.first.data();
      for (final e in (m['tabungan'] as Map? ?? {}).entries) {
        tab['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
      for (final e in (m['hutang'] as Map? ?? {}).entries) {
        hut['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    final antre = await _antreanUmum();
    final units = unitsOverride ?? antre.length;
    final r = distribute(units: units, tab: tab, hutang: hut);

    // uid + nama dari direktori team.
    final emailUid = <String, String>{};
    final emailNama = <String, String>{};
    try {
      final team = await _wo.watchTeam().first;
      for (final t in team) {
        emailUid['${t['email']}'] = '${t['uid'] ?? ''}';
        emailNama['${t['email']}'] = '${t['nama'] ?? t['email']}';
      }
    } catch (_) {}
    // Tempel WO tertua ke mekanik sesuai urutan distribusi.
    final dist = (r['dist'] as List).cast<Map<String, dynamic>>();
    var cursor = 0;
    final batch = _fs.db.batch();
    for (final d in dist) {
      final n = d['unit'] as int;
      final woIds = <String>[];
      for (var i = 0; i < n && cursor < antre.length; i++, cursor++) {
        woIds.add(antre[cursor]['id'] as String);
      }
      d['woIds'] = woIds;
      d['nama'] = emailNama[d['email']] ?? d['email'];
    }
    for (final d in dist) {
      for (final id in (d['woIds'] as List).cast<String>()) {
        batch.set(_fs.col('work_orders').doc(id), {
          'mekanik': d['nama'],
          'mekanikUid': emailUid[d['email']] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    batch.set(_doc(key), {
      'tanggal': key,
      'units': units,
      'distribusi': dist,
      'requests': [],
      'selesai': [],
      'tabungan': r['tabBaru'],
      'hutang': r['hutangBaru'],
      'sk': {},
      'pit1': null,
      'pit2': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
    await batch.commit();
  }

  // Request khusus: ambil N antrean umum tertua -> mekanik tsb + hutang += N.
  Future<void> requestUnits({
    required String email, required String nama,
    required int unit, String ket = '',
  }) async {
    if (unit <= 0) throw ArgumentError('unit harus > 0');
    final key = keyOf(DateTime.now());
    final antre = await _antreanUmum();
    final ambil = antre.take(unit).toList();
    String uid = '';
    try {
      final team = await _wo.watchTeam().first;
      final m = team.firstWhere((t) => t['email'] == email, orElse: () => {});
      uid = '${m['uid'] ?? ''}';
    } catch (_) {}
    final batch = _fs.db.batch();
    for (final w in ambil) {
      batch.set(_fs.col('work_orders').doc(w['id'] as String), {
        'mekanik': nama,
        'mekanikUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    final ref = _doc(key);
    final snap = await ref.get();
    final cur = snap.data() ?? {};
    final reqs = List<Map<String, dynamic>>.from(cur['requests'] ?? []);
    reqs.add({
      'email': email, 'nama': nama, 'unit': ambil.length, 'minta': unit,
      'ket': ket, 'woIds': ambil.map((w) => w['id']).toList(),
      'oleh': _fs.auth.currentUser?.email ?? '',
      'at': FieldValue.serverTimestamp(),
    });
    final hut = Map<String, dynamic>.from(cur['hutang'] ?? {});
    hut[email] = ((hut[email] as num?)?.toInt() ?? 0) + ambil.length;
    batch.set(ref, {
      'tanggal': key,
      'requests': reqs,
      'hutang': hut,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  // Tandai selesai untuk satu mekanik: selesaikan WO rotasi + request miliknya.
  Future<int> completeMekanik({required String key, required String email}) async {
    final snap = await _doc(key).get();
    final cur = snap.data() ?? {};
    var n = 0;
    final dist = List<Map<String, dynamic>>.from(cur['distribusi'] ?? []);
    for (final d in dist) {
      if (d['email'] != email) continue;
      for (final id in ((d['woIds'] as List?) ?? []).cast<String>()) {
        final r = await _wo.selesaikanWO(id);
        if (r == 'ok') n++;
      }
    }
    final reqs = List<Map<String, dynamic>>.from(cur['requests'] ?? []);
    for (final q in reqs) {
      if (q['email'] != email) continue;
      for (final id in ((q['woIds'] as List?) ?? []).cast<String>()) {
        final r = await _wo.selesaikanWO(id);
        if (r == 'ok') n++;
      }
    }
    final selesai = List<String>.from(cur['selesai'] ?? []);
    if (!selesai.contains(email)) selesai.add(email);
    await _doc(key).set({
      'selesai': selesai,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return n;
  }

  Future<void> pitCheck({required String key, required int pit}) async {
    await _doc(key).set({
      pit == 1 ? 'pit1' : 'pit2': {
        'oleh': _fs.auth.currentUser?.email ?? '',
        'at': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> skStatus({required String key, required String email, required String status}) async {
    // status: '' | 'jalan' | 'kembali'
    await _doc(key).set({
      'sk': {email: status},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Riwayat 30 hari terakhir.
  Stream<List<Map<String, dynamic>>> watchHistory() {
    return _fs.col('standby_harian').orderBy('tanggal', descending: true).limit(30).snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
