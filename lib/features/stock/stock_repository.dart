import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';
import 'stock_model.dart';
import 'motor_class.dart' show kelasOf;

class StockRepository {
  final _fs = FirebaseService.instance;

  // 3000 SKU: jangan load semua sekaligus - pakai pagination 50
  Stream<List<Sparepart>> watchAll({int limit = 50}) {
    return _fs.col('spareparts').orderBy('kode').limit(limit).snapshots().map(
      (s) => s.docs.map((d)=> Sparepart.fromDoc(d)).toList()
    );
  }

  // Pagination untuk 3000 SKU - load more
  Future<List<Sparepart>> fetchPage({DocumentSnapshot? startAfter, int limit = 50, String? search}) async {
    Query<Map<String,dynamic>> q = _fs.col('spareparts').orderBy('kode').limit(limit);
    if (search != null && search.isNotEmpty) {
      // Search via where kode >= search && kode < search+'\uf8ff' atau via Algolia/Typesense untuk 3000 SKU
      // MVP: client filter, prod: pakai Firestore full-text atau load semua ke memory (3000 masih ringan 3MB)
      q = _fs.col('spareparts').orderBy('kode').limit(3000);
    }
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.get();
    return snap.docs.map((d)=> Sparepart.fromDoc(d)).toList();
  }

  Future<List<Sparepart>> fetchAll3000() async {
    final snap = await _fs.col('spareparts').orderBy('kode').limit(3000).get();
    return snap.docs.map((d)=> Sparepart.fromDoc(d)).toList();
  }

  // Scan cocok ke: kode, barcode primer, atau barcode supplier (barcodes[])
  Future<Sparepart?> getByBarcode(String barcode) async {
    final code = barcode.trim();
    var q = await _fs.col('spareparts').where('kode', isEqualTo: code).limit(1).get();
    if (q.docs.isNotEmpty) return Sparepart.fromDoc(q.docs.first);
    q = await _fs.col('spareparts').where('barcode', isEqualTo: code).limit(1).get();
    if (q.docs.isNotEmpty) return Sparepart.fromDoc(q.docs.first);
    q = await _fs.col('spareparts').where('barcodes', arrayContains: code).limit(1).get();
    if (q.docs.isNotEmpty) return Sparepart.fromDoc(q.docs.first);
    return null;
  }

  // Daftarkan barcode supplier/kemasan ke SKU (cukup scan sekali)
  Future<void> addBarcode(String kode, String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty || code == kode) return;
    await _fs.doc('spareparts', kode).set({
      'barcodes': FieldValue.arrayUnion([code]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeBarcode(String kode, String barcode) async {
    await _fs.doc('spareparts', kode).set({
      'barcodes': FieldValue.arrayRemove([barcode]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Ubah harga manual per SKU + catat riwayat
  Future<void> updateHarga(String kode, int retailBaru, {String sumber = 'manual'}) async {
    final doc = await _fs.doc('spareparts', kode).get();
    final lama = Sparepart.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
    if (lama.harga.retail == retailBaru) return;
    final batch = _fs.db.batch();
    batch.set(_fs.doc('spareparts', kode), {
      'harga': {'modal': (retailBaru * 0.85).round(), 'retail': retailBaru, 'pajakPersen': 11,
        'pajakRp': retailBaru * 11 ~/ 100, 'jual': retailBaru + retailBaru * 11 ~/ 100},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_fs.doc('spareparts', kode).collection('price_history').doc(), {
      'retailLama': lama.harga.retail, 'jualLama': lama.harga.jual,
      'retailBaru': retailBaru, 'jualBaru': retailBaru + retailBaru * 11 ~/ 100,
      'sumber': sumber, 'oleh': _fs.auth.currentUser?.uid ?? 'demo',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> fetchPriceHistory(String kode, {int limit = 10}) async {
    final s = await _fs.doc('spareparts', kode).collection('price_history')
        .orderBy('timestamp', descending: true).limit(limit).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> upsert(Sparepart p) async {
    await _fs.doc('spareparts', p.kode).set(p.toMap(), SetOptions(merge: true));
  }

  // IN / OUT - tercatat di stock_movements, stok update via Function onCreateStockMovement
  Future<void> addMovement({
    required String kode, required int qty, required String tipe, // IN|OUT|PINDAH|ADJUST|OPNAME
    String? nopol, String? mekanikId, String? mekanikNama, String? woId,
    String? lotNo, String? alamatBaru, String? catatan,
  }) async {
    final batch = _fs.db.batch();
    final movRef = _fs.col('stock_movements').doc();
    batch.set(movRef, {
      'tenantId': _fs.effectiveTenantId,
      'tipe': tipe, 'kode_part': kode, 'qty': qty,
      'kendaraan': nopol!=null ? {'nopol':nopol} : null,
      'mekanik': mekanikId!=null ? {'id':mekanikId,'nama':mekanikNama} : null,
      'woId': woId,
      'lotNo': lotNo,
      'alamatBaru': alamatBaru,
      'catatan': catatan,
      'oleh': _fs.auth.currentUser?.uid ?? 'demo',
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Update stok langsung di client agar offline-first tetap jalan
    final delta = tipe == 'IN' ? qty : tipe == 'OUT' ? -qty : 0;
    if (delta != 0) {
      final spRef = _fs.doc('spareparts', kode);
      batch.set(spRef, {
        'stok': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    if (tipe == 'OUT' && lotNo != null) {
      await consumeFIFO(kode, qty);
    }
  }

  // 1. Simpan rak + catat mutasi PINDAH
  Future<void> moveRak({required String kode, required String alamatBaru, String? alasan}) async {
    final parts = alamatBaru.split('-');
    final rak = parts.length > 1 ? '${parts[0]}-${parts[1]}' : parts.first;
    final bin = parts.length > 3 ? parts.sublist(3).join('-') : '';
    final batch = _fs.db.batch();
    batch.set(_fs.doc('spareparts', kode), {
      'alamat': alamatBaru, 'rak': rak, 'bin': bin,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_fs.col('stock_movements').doc(), {
      'tenantId': _fs.effectiveTenantId,
      'tipe': 'PINDAH', 'kode_part': kode, 'qty': 0,
      'alamatBaru': alamatBaru, 'catatan': alasan ?? 'Pindah rak',
      'oleh': _fs.auth.currentUser?.uid ?? 'demo',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> history(String kode, {int limit = 50}) {
    return _fs.col('stock_movements').where('kode_part', isEqualTo: kode).orderBy('timestamp', descending: true).limit(limit).snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // 3. Alert min/max + usulan PO (maxStok default = minStok*3 bila kosong)
  Stream<List<Sparepart>> watchLowStock({int limit = 100}) {
    return _fs.col('spareparts').where('stok', isGreaterThan: -1).limit(500).snapshots().map((s) {
      final all = s.docs.map((d) => Sparepart.fromDoc(d)).toList();
      final low = all.where((p) => p.stok <= p.minStok).toList()
        ..sort((a, b) => (a.stok - a.minStok).compareTo(b.stok - b.minStok));
      return low.take(limit).toList();
    });
  }

  int suggestQty(Sparepart p) {
    final maxStok = p.minStok * 3;
    final need = maxStok - p.stok;
    return need > 0 ? need : 0;
  }

  Future<void> createPO({required Map<String, int> items, String? supplier, String? catatan}) async {
    await _fs.col('purchase_orders').add({
      'tenantId': _fs.effectiveTenantId,
      'items': items.entries.map((e) => {'kode': e.key, 'qty': e.value}).toList(),
      'supplier': supplier ?? '', 'catatan': catatan ?? '',
      'status': 'DRAFT', // DRAFT|ORDER|TERIMA
      'oleh': _fs.auth.currentUser?.uid ?? 'demo',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 4. Batch/lot FIFO (penting untuk oli/ban)
  Future<void> addBatch({required String kode, required String lotNo, required int qty, DateTime? expired, DateTime? tglMasuk}) async {
    await _fs.col('spareparts').doc(kode).collection('batches').doc(lotNo).set({
      'lotNo': lotNo, 'qty': qty, 'qtyAwal': qty,
      'tglMasuk': Timestamp.fromDate(tglMasuk ?? DateTime.now()),
      'expired': expired != null ? Timestamp.fromDate(expired) : null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> fetchBatches(String kode) async {
    final s = await _fs.col('spareparts').doc(kode).collection('batches').orderBy('tglMasuk').get();
    return s.docs.map((d) => {'lotNo': d.id, ...d.data()}).toList();
  }

  // Konsumsi FIFO: lot expired paling dekat / masuk paling dulu
  Future<void> consumeFIFO(String kode, int qty) async {
    var sisa = qty;
    final s = await _fs.col('spareparts').doc(kode).collection('batches').orderBy('tglMasuk').get();
    // Prioritaskan yang ada expired paling dekat dulu
    final docs = s.docs.toList()
      ..sort((a, b) {
        final ea = (a.data()['expired'] as Timestamp?);
        final eb = (b.data()['expired'] as Timestamp?);
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return ea.compareTo(eb);
      });
    final batch = _fs.db.batch();
    for (final d in docs) {
      if (sisa <= 0) break;
      final q = (d.data()['qty'] ?? 0) as int;
      if (q <= 0) continue;
      final ambil = q >= sisa ? sisa : q;
      batch.update(d.reference, {'qty': FieldValue.increment(-ambil)});
      sisa -= ambil;
    }
    if (sisa != qty) await batch.commit();
  }

  // 2. Opname + variance + approval
  Future<String> startOpname({required List<String> scopeZona, required String catatan}) async {
    final ref = await _fs.col('stock_opnames').add({
      'tenantId': _fs.effectiveTenantId,
      'scopeZona': scopeZona, 'catatan': catatan,
      'status': 'COUNTING', // COUNTING|REVIEW|APPROVED|REJECTED
      'createdAt': FieldValue.serverTimestamp(),
      'oleh': _fs.auth.currentUser?.uid ?? 'demo',
    });
    return ref.id;
  }

  Future<void> saveCount({required String opnameId, required String kode, required int stokSistem, required int stokFisik}) async {
    final selisih = stokFisik - stokSistem;
    await _fs.col('stock_opnames').doc(opnameId).collection('items').doc(kode).set({
      'kode': kode, 'stokSistem': stokSistem, 'stokFisik': stokFisik, 'selisih': selisih,
      'status': selisih == 0 ? 'COCOK' : (selisih > 0 ? 'LEBIH' : 'KURANG'),
      'countedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveOpname({required String opnameId, required bool approve}) async {
    final items = await _fs.col('stock_opnames').doc(opnameId).collection('items').get();
    final batch = _fs.db.batch();
    batch.update(_fs.col('stock_opnames').doc(opnameId), {
      'status': approve ? 'APPROVED' : 'REJECTED',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    if (approve) {
      for (final d in items.docs) {
        final m = d.data();
        final selisih = (m['selisih'] ?? 0) as int;
        if (selisih != 0) {
          final mov = _fs.col('stock_movements').doc();
          batch.set(mov, {
            'tenantId': _fs.effectiveTenantId,
            'tipe': 'OPNAME', 'kode_part': m['kode'], 'qty': selisih.abs(),
            'catatan': 'Adjust opname $opnameId (${selisih > 0 ? '+' : ''}$selisih)',
            'oleh': _fs.auth.currentUser?.uid ?? 'demo',
            'timestamp': FieldValue.serverTimestamp(),
          });
          batch.set(_fs.doc('spareparts', m['kode']), {
            'stok': FieldValue.increment(selisih),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    }
    await batch.commit();
  }

  // 5. Work order servis link ke OUT (+ jobs FRT + parts + total)
  Future<String> createWO({
    required String nopol, required String motor, required String keluhan, String? mekanik,
    String model = '', String tipe = 'SERVICE', // SERVICE|WARRANTY
    String kategori = 'Reguler', // Reguler|JobReturn|Kunjung|KSG1..KSG8|Warranty|PDI
    String kuponNo = '', bool kuponStempel = false,
    List<Map<String, dynamic>> jobs = const [], List<Map<String, dynamic>> parts = const [],
    int labourTotal = 0, int partsTotal = 0,
    Map<String, dynamic> extra = const {},
  }) async {
    final ref = await _fs.col('work_orders').add({
      'tenantId': _fs.effectiveTenantId,
      'nopol': nopol, 'motor': motor, 'model': model, 'motorClass': model.isEmpty ? '' : kelasOf(model), 'tipe': tipe,
      'kategori': kategori, 'kuponNo': kuponNo, 'kuponStempel': kuponStempel,
      ...extra,
      'keluhan': keluhan, 'mekanik': mekanik ?? '',
      'jobs': jobs, 'parts': parts,
      'labourTotal': labourTotal, 'partsTotal': partsTotal,
      'grandTotal': labourTotal + partsTotal,
      'status': 'OPEN', // OPEN|PROSES|SELESAI|BATAL
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateWO(String id, Map<String, dynamic> data) async {
    await _fs.col('work_orders').doc(id).set({
      ...data, 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Selesaikan WO secara atomik + audit (siapa/kapan).
  // Idempoten: WO yang sudah SELESAI tidak berubah (return 'sudah').
  // Return: 'ok' | 'sudah'.
  Future<String> selesaikanWO(String id) async {
    final me = _fs.auth.currentUser;
    final hasil = await _fs.db.runTransaction((tx) async {
      final snap = await tx.get(_fs.col('work_orders').doc(id));
      if (!snap.exists) return 'hilang';
      final m = snap.data()!;
      if ('${m['status']}'.toUpperCase() == 'SELESAI') return 'sudah';
      tx.set(_fs.col('work_orders').doc(id), {
        'status': 'SELESAI',
        'selesaiOleh': {'uid': me?.uid ?? '', 'email': me?.email ?? ''},
        'selesaiAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(_fs.col('work_orders').doc(id).collection('riwayat').doc(), {
        'aksi': 'SELESAI',
        'olehUid': me?.uid ?? '',
        'olehEmail': me?.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return 'ok';
    });
    return hasil;
  }

  // Batalkan penyelesaian: oleh penyelesai maks 10 menit, atau kepala/ops kapan saja.
  // Return: 'ok' | 'ditolak' | 'bukan-selesai'.
  Future<String> batalkanSelesai(String id, {required bool supervisor}) async {
    final me = _fs.auth.currentUser;
    final hasil = await _fs.db.runTransaction((tx) async {
      final snap = await _fs.col('work_orders').doc(id);
      final doc = await tx.get(snap);
      if (!doc.exists) return 'hilang';
      final m = doc.data()!;
      if ('${m['status']}'.toUpperCase() != 'SELESAI') return 'bukan-selesai';
      final oleh = (m['selesaiOleh'] ?? {}) as Map;
      bool boleh = supervisor;
      if (!boleh) {
        final selesaiAt = m['selesaiAt'];
        if ('${oleh['uid'] ?? ''}' == (me?.uid ?? '') && selesaiAt != null) {
          try {
            final dt = (selesaiAt as dynamic).toDate() as DateTime;
            boleh = DateTime.now().difference(dt).inMinutes <= 10;
          } catch (_) {}
        }
      }
      if (!boleh) return 'ditolak';
      tx.set(_fs.col('work_orders').doc(id), {
        'status': 'PROSES',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(_fs.col('work_orders').doc(id).collection('riwayat').doc(), {
        'aksi': 'BATAL_SELESAI',
        'olehUid': me?.uid ?? '',
        'olehEmail': me?.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return 'ok';
    });
    return hasil;
  }

  // Master FRT (frt_warranty / frt_service), doc id = faultCode (warranty) / slug job (service)
  Future<List<Map<String, dynamic>>> fetchFrt(String tipe) async {
    final col = tipe == 'WARRANTY' ? 'frt_warranty' : 'frt_service';
    final s = await _fs.col(col).limit(500).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> saveFrtBatch(String tipe, List<Map<String, dynamic>> rows) async {
    final col = tipe == 'WARRANTY' ? 'frt_warranty' : 'frt_service';
    var batch = _fs.db.batch();
    var n = 0;
    for (final r in rows) {
      final id = (r['faultCode'] ?? '').toString().isNotEmpty ? r['faultCode'] : (r['job'] ?? '').toString();
      if (id.toString().isEmpty) continue;
      batch.set(_fs.col(col).doc(id.toString()), {...r, 'tenantId': _fs.effectiveTenantId, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      n++;
      if (n >= 400) { await batch.commit(); batch = _fs.db.batch(); n = 0; }
    }
    if (n > 0) await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> watchWO({String? status}) {
    Query<Map<String, dynamic>> q = _fs.col('work_orders').orderBy('createdAt', descending: true).limit(100);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // Tracking motor konsumen: riwayat WO per nopol + part per WO
  Future<List<Map<String, dynamic>>> fetchWOByNopol(String nopol) async {
    final key = nopol.trim().toUpperCase().replaceAll(' ', '');
    final s = await _fs.col('work_orders').limit(500).get();
    final out = s.docs.map((d) => {'id': d.id, ...d.data()}).where((w) {
      final n = '${w['nopol'] ?? ''}'.toUpperCase().replaceAll(' ', '');
      return n == key || n.contains(key) || key.contains(n);
    }).toList();
    out.sort((a, b) {
      final ta = (a['createdAt'] as Timestamp?);
      final tb = (b['createdAt'] as Timestamp?);
      if (ta == null || tb == null) return 0;
      return tb.compareTo(ta);
    });
    return out.take(50).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMovementsByWO(String woId) async {
    final s = await _fs.col('stock_movements').where('woId', isEqualTo: woId).limit(100).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // Stream 1 WO + metadata (untuk badge "Belum sinkron" saat offline).
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamWODoc(String id) {
    return _fs.col('work_orders').doc(id).snapshots(includeMetadataChanges: true);
  }

  // Laporan closing harian: agregasi WO + mutasi hari ini + stok kritis + PO
  Future<List<Map<String, dynamic>>> fetchMovementsSince(DateTime start) async {
    final s = await _fs.col('stock_movements')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('timestamp', descending: true).limit(1000).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWOSince(DateTime start) async {
    final s = await _fs.col('work_orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('createdAt', descending: true).limit(500).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPOsSince(DateTime start) async {
    final s = await _fs.col('purchase_orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('createdAt', descending: true).limit(100).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> saveDailyReport({required String dateKey, required String text, required Map<String, dynamic> summary}) async {
    await _fs.col('daily_reports').doc(dateKey).set({
      'tenantId': _fs.effectiveTenantId,
      'text': text, 'summary': summary,
      'createdAt': FieldValue.serverTimestamp(),
      'oleh': _fs.auth.currentUser?.uid ?? 'demo',
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchRecipients() {
    return _fs.col('report_recipients').orderBy('role').snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> upsertRecipient({String? id, required String nama, required String role, required String wa}) async {
    final ref = id == null ? _fs.col('report_recipients').doc() : _fs.col('report_recipients').doc(id);
    await ref.set({'tenantId': _fs.effectiveTenantId, 'nama': nama, 'role': role, 'wa': wa, 'aktif': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> deleteRecipient(String id) async {
    await _fs.col('report_recipients').doc(id).delete();
  }

  // Import Excel foto kamu: Part Code, Part Name, Motor Type, Retail, TAX, Harga Jual - Support 3000 SKU (batch 500)
  Future<void> importFromExcel(List<Map<String,dynamic>> rows) async {
    // Firestore batch max 500 writes - untuk 3000 SKU butuh 6 batch
    const batchSize = 500;
    for (var i=0; i<rows.length; i+=batchSize) {
      final batch = FirebaseService.instance.db.batch();
      final chunk = rows.skip(i).take(batchSize);
      for (var r in chunk) {
        final kode = r['Part Code'].toString().trim();
        if (kode.isEmpty) continue;
        final retail = int.tryParse(r['Retail Price (ex TAX)'].toString().replaceAll(RegExp(r'[^0-9]'),'')) ?? 0;
        final pajakPersen = 11;
        final doc = _fs.doc('spareparts', kode);
        batch.set(doc, {
          'kode': kode,
          'nama': r['Part Name'],
          'motorType': r['Motor Type'] ?? '',
          'barcode': kode,
          'stok': int.tryParse(r['stok'].toString()) ?? 0,
          'minStok': 5,
          'alamat': r['alamat'] ?? 'A-02-04-M05',
          'rak': 'A-02', 'bin':'M05',
          'kategori':'MEDIUM',
          'harga': {
            'modal': (retail * 0.85).round(),
            'retail': retail,
            'pajakPersen': pajakPersen,
            'pajakRp': retail * pajakPersen ~/100,
            'jual': retail + retail * pajakPersen ~/100,
          },
          'substitusi': [],
          'kompatibel': (r['Motor Type']??'').toString().split(',').map((e)=>e.trim()).toList(),
          'tenantId': _fs.effectiveTenantId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge:true));
      }
      await batch.commit();
    }
  }
}
