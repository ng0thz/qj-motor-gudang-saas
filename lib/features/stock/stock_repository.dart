import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';
import 'stock_model.dart';

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

  Future<Sparepart?> getByBarcode(String barcode) async {
    final q = await _fs.col('spareparts').where('barcode', isEqualTo: barcode).limit(1).get();
    if (q.docs.isEmpty) {
      final q2 = await _fs.col('spareparts').where('kode', isEqualTo: barcode).limit(1).get();
      if (q2.docs.isEmpty) return null;
      return Sparepart.fromDoc(q2.docs.first);
    }
    return Sparepart.fromDoc(q.docs.first);
  }

  Future<void> upsert(Sparepart p) async {
    await _fs.doc('spareparts', p.kode).set(p.toMap(), SetOptions(merge: true));
  }

  // IN / OUT - tercatat di stock_movements, stok update via Function onCreateStockMovement
  Future<void> addMovement({
    required String kode, required int qty, required String tipe, // IN|OUT
    String? nopol, String? mekanikId, String? mekanikNama, String? woId
  }) async {
    await _fs.col('stock_movements').add({
      'tipe': tipe, 'kode_part': kode, 'qty': qty,
      'kendaraan': nopol!=null ? {'nopol':nopol} : null,
      'mekanik': mekanikId!=null ? {'id':mekanikId,'nama':mekanikNama} : null,
      'woId': woId,
      'oleh': _fs.auth.currentUser?.uid ?? 'demo',
      'timestamp': FieldValue.serverTimestamp(),
    });
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
