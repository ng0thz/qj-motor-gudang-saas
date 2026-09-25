import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';

// Pendataan peralatan bengkel (dongkrak, kunci torsi, kompresor, dsb).
// Koleksi: tenants/{tid}/peralatan/{kode} — kode unik PK-001, dst.
// Opname peralatan = verifikasi fisik per item (verifiedAt/verifiedBy).
class Peralatan {
  final String kode;
  final String nama;
  final String lokasi; // PIT 1|PIT 2|GUDANG|RUANG SERVICE|LAINNYA
  final String penanggungJawab;
  final String kondisi; // BAIK|RUSAK|HILANG
  final int jumlah;
  final String catatan;
  final String verifiedBy;
  final Timestamp? verifiedAt;

  const Peralatan({
    required this.kode, required this.nama, this.lokasi = 'PIT 1',
    this.penanggungJawab = '', this.kondisi = 'BAIK', this.jumlah = 1,
    this.catatan = '', this.verifiedBy = '', this.verifiedAt,
  });

  factory Peralatan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Peralatan(
      kode: d.id,
      nama: '${m['nama'] ?? ''}',
      lokasi: '${m['lokasi'] ?? 'PIT 1'}',
      penanggungJawab: '${m['penanggungJawab'] ?? ''}',
      kondisi: '${m['kondisi'] ?? 'BAIK'}',
      jumlah: (m['jumlah'] as num?)?.toInt() ?? 1,
      catatan: '${m['catatan'] ?? ''}',
      verifiedBy: '${m['verifiedBy'] ?? ''}',
      verifiedAt: m['verifiedAt'] as Timestamp?,
    );
  }

  static const lokasiList = ['PIT 1', 'PIT 2', 'GUDANG', 'RUANG SERVICE', 'LAINNYA'];
  static const kondisiList = ['BAIK', 'RUSAK', 'HILANG'];
}

class PeralatanRepository {
  final _fs = FirebaseService.instance;

  Stream<List<Peralatan>> watchAll({String? lokasi, String? kondisi, bool belumVerif = false}) {
    Query<Map<String, dynamic>> q = _fs.col('peralatan').orderBy('kode');
    if (lokasi != null && lokasi.isNotEmpty) q = q.where('lokasi', isEqualTo: lokasi);
    if (kondisi != null && kondisi.isNotEmpty) q = q.where('kondisi', isEqualTo: kondisi);
    return q.snapshots().map((s) {
      var list = s.docs.map((d) => Peralatan.fromDoc(d)).toList();
      if (belumVerif) list = list.where((p) => p.verifiedAt == null).toList();
      return list;
    });
  }

  Future<List<Peralatan>> fetchAll() async {
    final s = await _fs.col('peralatan').orderBy('kode').limit(1000).get();
    return s.docs.map((d) => Peralatan.fromDoc(d)).toList();
  }

  // Simpan (tambah/edit). Kode dinormalisasi UPPERCASE, spasi jadi '-'.
  Future<void> save({
    required String kode, required String nama, String lokasi = 'PIT 1',
    String penanggungJawab = '', String kondisi = 'BAIK', int jumlah = 1, String catatan = '',
  }) async {
    final k = kode.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
    if (k.isEmpty || nama.trim().isEmpty) throw ArgumentError('Kode & nama wajib diisi');
    await _fs.doc('peralatan', k).set({
      'tenantId': _fs.effectiveTenantId,
      'nama': nama.trim(),
      'lokasi': lokasi,
      'penanggungJawab': penanggungJawab.trim(),
      'kondisi': kondisi,
      'jumlah': jumlah < 1 ? 1 : jumlah,
      'catatan': catatan.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateKondisi(String kode, String kondisi, {String catatan = ''}) async {
    final data = <String, dynamic>{
      'kondisi': kondisi,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (catatan.trim().isNotEmpty) data['catatan'] = catatan.trim();
    await _fs.doc('peralatan', kode).set(data, SetOptions(merge: true));
  }

  // Cek fisik opname: cap siapa + kapan memverifikasi (kondisi ikut dicatat).
  Future<void> verifikasiFisik(String kode, String kondisi) async {
    final me = _fs.auth.currentUser;
    await _fs.doc('peralatan', kode).set({
      'kondisi': kondisi,
      'verifiedBy': me?.email ?? me?.uid ?? '',
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> hapus(String kode) async {
    await _fs.doc('peralatan', kode).delete();
  }
}
