import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_repository.dart';
import 'scan_page.dart';

// Kelola barcode supplier + ubah harga manual + lihat riwayat harga.
void openBarcodeHarga(BuildContext context, String kode, int retailNow) {
  final repo = StockRepository();
  final barcodeCtrl = TextEditingController();
  final hargaCtrl = TextEditingController(text: '$retailNow');
  showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Barcode & Harga — $kode', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode supplier', border: OutlineInputBorder()))),
          IconButton(tooltip: 'Scan', icon: const Icon(Icons.qr_code_scanner), onPressed: () async {
            final code = await openScan(ctx, title: 'Scan barcode supplier');
            if (code != null) barcodeCtrl.text = code;
          }),
          IconButton(tooltip: 'Tambah', icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () async {
            await repo.addBarcode(kode, barcodeCtrl.text);
            barcodeCtrl.clear();
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Barcode ditambahkan')));
          }),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: hargaCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Retail baru (pajak 11% otomatis)', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () async {
            final r = int.tryParse(hargaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (r <= 0) return;
            await repo.updateHarga(kode, r);
            if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harga diupdate + riwayat tercatat'))); }
          }, child: const Text('Simpan')),
        ]),
        const SizedBox(height: 8),
        const Text('Riwayat harga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.fetchPriceHistory(kode),
          builder: (c, s) {
            if (!s.hasData) return const LinearProgressIndicator();
            if (s.data!.isEmpty) return const Text('Belum ada perubahan tercatat.', style: TextStyle(fontSize: 11, color: Colors.grey));
            final fmt = DateFormat('dd/MM/yy HH:mm');
            return Column(children: s.data!.map((h) => ListTile(dense: true,
              title: Text('Rp ${h['retailLama']} → Rp ${h['retailBaru']}', style: const TextStyle(fontSize: 12)),
              subtitle: Text('${h['sumber'] ?? ''}', style: const TextStyle(fontSize: 11)),
              trailing: Text(h['timestamp'] == null ? '' : fmt.format((h['timestamp'] as dynamic).toDate()), style: const TextStyle(fontSize: 10)),
            )).toList());
          },
        ),
      ]),
    );
  });
}
