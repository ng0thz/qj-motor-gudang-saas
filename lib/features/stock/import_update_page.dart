import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';

// Halaman import update data + harga terbaru
// Format CSV: Part Code;Part Name;Motor Type;Retail Price (ex TAX);TAX;Harga Jual konsumen
// Stok TIDAK diambil - hanya update kode/nama/motor/retail/pajak/jual
class ImportUpdatePage extends StatefulWidget {
  const ImportUpdatePage({super.key});
  @override
  State<ImportUpdatePage> createState() => _ImportUpdatePageState();
}

class _ImportUpdatePageState extends State<ImportUpdatePage> {
  String log = 'Pilih file CSV Book baru untuk update.\nStok tidak diubah (tetap real gudang).';
  bool loading = false;
  int updated = 0;

  Future<void> _pickAndUpdate() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (res == null) return;
    setState(() { loading = true; log = 'Membaca file...'; });
    try {
      final bytes = res.files.first.bytes!;
      final text = String.fromCharCodes(bytes);
      final lines = text.split('\n').skip(2); // skip 2 header
      final fs = FirebaseService.instance;
      int batchCount = 0;
      var batch = fs.db.batch();
      updated = 0;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final c = line.split(';');
        if (c.length < 4) continue;
        final kode = c[0].trim();
        if (kode.isEmpty || kode == 'Part Code') continue;
        final nama = c.length > 1 ? c[1].trim() : '';
        final motor = c.length > 2 ? c[2].trim() : '';
        final retail = int.tryParse(c[3].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (retail == 0 && nama.isEmpty) continue; // skip tanpa harga + tanpa nama
        final doc = fs.doc('spareparts', kode);
        batch.set(doc, {
          'tenantId': fs.effectiveTenantId,
          'kode': kode,
          'nama': nama,
          'motorType': motor,
          'barcode': kode,
          // stok TIDAK diupdate
          'harga': {'modal': (retail*0.85).round(), 'retail': retail, 'pajakPersen': 11, 'pajakRp': retail*11~/100, 'jual': retail + retail*11~/100},
          'kompatibel': motor.split('/').map((e)=>e.trim()).toList(),
          'status': 'DRAFT',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batchCount++; updated++;
        if (batchCount >= 400) { await batch.commit(); batch = fs.db.batch(); batchCount = 0; }
      }
      if (batchCount > 0) await batch.commit();
      setState(() { log = 'Selesai: $updated SKU diupdate (nama+harga). Stok tetap.'; });
    } catch (e) {
      setState(() { log = 'Gagal: $e'; });
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Import Update'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Format: CSV ; delimiter, header sama seperti Book2.csv', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('• Update: kode, nama, motor, retail, pajak 11%, jual\n• TIDAK update: stok, alamat, minStok', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: loading ? null : _pickAndUpdate, icon: const Icon(Icons.upload_file), label: Text(loading ? 'Proses...' : 'Pilih File CSV Baru')),
        const SizedBox(height: 16),
        Expanded(child: SingleChildScrollView(child: Text(log))),
      ])),
    );
  }
}
