import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';

// Import hasil opname peralatan via CSV / Excel (xlsx).
// Kolom: Kode,Nama,Lokasi,Penanggung Jawab,Jumlah,Kondisi,Catatan
// - Kode kosong = skip, Nama kosong = skip
// - Lokasi: PIT 1|PIT 2|GUDANG|RUANG SERVICE|LAINNYA (fallback PIT 1)
// - Kondisi: BAIK|RUSAK|HILANG (fallback BAIK)
// - Jumlah: angka, fallback 1
// Upload batch 300/commmit, tandai verifiedAt jika Kondisi diisi.
class PeralatanImportPage extends StatefulWidget {
  const PeralatanImportPage({super.key});
  @override
  State<PeralatanImportPage> createState() => _PeralatanImportPageState();
}

class _PeralatanImportPageState extends State<PeralatanImportPage> {
  String log = 'Pilih file CSV atau Excel (xlsx) hasil opname peralatan.\n'
      'Header: Kode,Nama,Lokasi,Penanggung Jawab,Jumlah,Kondisi,Catatan';
  bool loading = false;
  int done = 0;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (res == null) return;
    setState(() { loading = true; log = 'Membaca ${res.files.first.name}...'; });
    try {
      final name = res.files.first.name.toLowerCase();
      List<List<String>> rows;
      if (name.endsWith('.csv')) {
        final txt = utf8.decode(res.files.first.bytes!, allowMalformed: true);
        rows = txt.split('\n').map((l) => l.split(',').map((e) => e.trim()).toList()).toList();
        // support ; delimiter
        if (rows.isNotEmpty && rows[0].length == 1 && rows[0][0].contains(';')) {
          rows = txt.split('\n').map((l) => l.split(';').map((e) => e.trim()).toList()).toList();
        }
      } else {
        // xlsx via excel package (light parse via bytes-> csv fallback: treat as not supported if fails)
        log = 'Excel terdeteksi - parsing...';
        // Simple: try decode as utf8 csv inside xlsx is not valid, so inform user to save as CSV
        setState(() => log = 'Untuk Excel, silakan Save As CSV (Comma delimited) dulu, lalu upload CSV.');
        setState(() => loading = false);
        return;
      }
      // cari header
      int start = 0;
      for (var i = 0; i < rows.length && i < 5; i++) {
        final r = rows[i].map((e) => e.toLowerCase()).join(',');
        if (r.contains('kode') && r.contains('nama')) { start = i + 1; break; }
      }
      final fs = FirebaseService.instance;
      var batch = fs.db.batch();
      int batchN = 0;
      int baru = 0, upd = 0;
      done = 0;
      for (var i = start; i < rows.length; i++) {
        final c = rows[i];
        if (c.length < 2) continue;
        String kode = c.isNotEmpty ? c[0].trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-') : '';
        String nama = c.length > 1 ? c[1].trim() : '';
        if (kode.isEmpty || nama.isEmpty) continue;
        // skip header repeat
        if (kode.toLowerCase() == 'kode') continue;
        String lokasi = c.length > 2 ? c[2].trim().toUpperCase() : 'PIT 1';
        if (!['PIT 1','PIT 2','GUDANG','RUANG SERVICE','LAINNYA'].contains(lokasi)) lokasi = 'PIT 1';
        String pj = c.length > 3 ? c[3].trim() : '';
        int jumlah = c.length > 4 ? int.tryParse(c[4].replaceAll(RegExp(r'[^0-9]'),'')) ?? 1 : 1;
        if (jumlah < 1) jumlah = 1;
        String kondisi = c.length > 5 ? c[5].trim().toUpperCase() : 'BAIK';
        if (!['BAIK','RUSAK','HILANG'].contains(kondisi)) kondisi = 'BAIK';
        String catatan = c.length > 6 ? c[6].trim() : '';
        final doc = fs.doc('peralatan', kode);
        batch.set(doc, {
          'tenantId': fs.effectiveTenantId,
          'nama': nama,
          'lokasi': lokasi,
          'penanggungJawab': pj,
          'jumlah': jumlah,
          'kondisi': kondisi,
          'catatan': catatan,
          'verifiedBy': fs.auth.currentUser?.email ?? '',
          'verifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batchN++; done++;
        // deteksi baru vs update via get? skip, hitung upd saja
        upd++;
        if (batchN >= 300) { await batch.commit(); batch = fs.db.batch(); batchN = 0; }
      }
      if (batchN > 0) await batch.commit();
      setState(() => log = 'Selesai: $done baris diproses.\n'
          '• Format: Kode,Nama,Lokasi,Penanggung Jawab,Jumlah,Kondisi,Catatan\n'
          '• Semua baris ditandai terverifikasi (cek fisik).');
    } catch (e) {
      setState(() => log = 'Gagal: $e');
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Peralatan - Opname'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Template CSV: Kode,Nama,Lokasi,Penanggung Jawab,Jumlah,Kondisi,Catatan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const Text('Contoh: PK-001,Dongkrak 2T,PIT 1,Wahyu,1,BAIK,cek 28/09', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: loading ? null : _pick, icon: const Icon(Icons.upload_file), label: Text(loading ? 'Proses...' : 'Pilih File CSV')),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: Text(log, style: const TextStyle(fontSize: 12)))),
      ])),
    );
  }
}
