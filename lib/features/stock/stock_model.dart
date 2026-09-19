import 'package:cloud_firestore/cloud_firestore.dart';

class Harga {
  final int modal;
  final int retail;
  final int pajakPersen;
  final int pajakRp;
  final int jual;
  final int? grosir;

  Harga({required this.modal, required this.retail, this.pajakPersen=11, this.grosir})
      : pajakRp = (retail * pajakPersen ~/ 100),
        jual = retail + (retail * pajakPersen ~/ 100);

  Map<String,dynamic> toMap() => {
    'modal': modal, 'retail': retail, 'pajakPersen': pajakPersen,
    'pajakRp': pajakRp, 'jual': jual, 'grosir': grosir
  };

  factory Harga.fromMap(Map<String,dynamic> m) => Harga(
    modal: m['modal']??0, retail: m['retail']??0,
    pajakPersen: m['pajakPersen']??11, grosir: m['grosir']
  );
}

class Substitusi {
  final String kode;
  final String nama;
  final String status; // Substitusi Langsung | Alternatif
  final String catatan;
  Substitusi({required this.kode, required this.nama, required this.status, this.catatan=''});
  Map<String,dynamic> toMap() => {'kode':kode,'nama':nama,'status':status,'catatan':catatan};
  factory Substitusi.fromMap(Map<String,dynamic> m) => Substitusi(
    kode:m['kode'], nama:m['nama'], status:m['status'], catatan:m['catatan']??''
  );
}

class Sparepart {
  final String kode; // Part Code 05523M79K500
  final String nama; // Part Name
  final String motorType; // AX 180 (VIENTO) ABS - bisa koma
  final int stok;
  final int minStok;
  final String alamat; // A-02-04-M05
  final String rak;
  final String bin;
  final String barcode; // sama dengan kode
  final Harga harga;
  final List<Substitusi> substitusi;
  final List<String> kompatibel;
  final String kategori; // FAST|MEDIUM|SLOW - moving
  final String jenisPart; // ENGINE|BRAKE|BODY|ELECTRICAL|etc
  final int prioritas; // 1=ada harga (fokus), 2=belum ada harga
  final String status; // DRAFT|VERIFIED

  Sparepart({
    required this.kode, required this.nama, required this.motorType,
    required this.stok, required this.minStok, required this.alamat,
    required this.rak, required this.bin, required this.barcode,
    required this.harga, this.substitusi=const[], this.kompatibel=const[], this.kategori='MEDIUM',
    this.jenisPart='OTHER', this.prioritas=1, this.status='DRAFT'
  });

  Map<String,dynamic> toMap() => {
    'kode':kode,'nama':nama,'motorType':motorType,'stok':stok,'minStok':minStok,
    'alamat':alamat,'rak':rak,'bin':bin,'barcode':barcode,
    'harga':harga.toMap(),
    'substitusi': substitusi.map((e)=>e.toMap()).toList(),
    'kompatibel': kompatibel,
    'kategori':kategori,
    'jenisPart':jenisPart,
    'prioritas':prioritas,
    'status':status,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory Sparepart.fromDoc(DocumentSnapshot<Map<String,dynamic>> doc) {
    final m = doc.data()!;
    return Sparepart(
      kode: m['kode'], nama: m['nama'], motorType: m['motorType']??'',
      stok: m['stok']??0, minStok: m['minStok']??5,
      alamat: m['alamat']??'', rak: m['rak']??'', bin: m['bin']??'',
      barcode: m['barcode']??m['kode'],
      harga: Harga.fromMap(m['harga']??{}),
      substitusi: ((m['substitusi'] as List?)??[]).map((e)=>Substitusi.fromMap(e)).toList(),
      kompatibel: List<String>.from(m['kompatibel']??[]),
      kategori: m['kategori']??'MEDIUM',
      jenisPart: m['jenisPart']??'OTHER',
      prioritas: m['prioritas']??1,
      status: m['status']??'DRAFT',
    );
  }

  bool get isMenipis => stok <= minStok;
  bool get isHabis => stok == 0;
}
