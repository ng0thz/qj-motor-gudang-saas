import 'package:flutter/material.dart';
import 'stock_repository.dart';

// Bottom sheet konfirmasi 1-tap: nama mekanik + unit + tombol KONFIRMASI besar.
// Dipakai mekanik setelah PDI/pekerjaan selesai (tangan kotor = tanpa form).
void openKonfirmasiSelesai(
  BuildContext context, {
  required String woId,
  required String judul, // mis. "B 1234 ABC • Vario 160"
  required String subJudul, // mis. "PDI • 2 unit"
  required Future<void> Function() onBerhasil,
}) {
  final repo = StockRepository();
  showModalBottomSheet(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(subJudul, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, size: 26),
            label: const Text('KONFIRMASI SELESAI', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final hasil = await repo.selesaikanWO(woId);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (hasil == 'sudah') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sudah selesai sebelumnya')));
              } else if (hasil == 'ok') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Tercatat selesai')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mencatat')));
                return;
              }
              await onBerhasil();
            },
          ),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
      ]),
    ),
  );
}
