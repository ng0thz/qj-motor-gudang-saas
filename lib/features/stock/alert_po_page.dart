import 'package:flutter/material.dart';
import 'stock_repository.dart';

// Alert stok <= min + usulan PO (max = min*3)
class AlertPOPage extends StatefulWidget {
  const AlertPOPage({super.key});
  @override
  State<AlertPOPage> createState() => _AlertPOPageState();
}

class _AlertPOPageState extends State<AlertPOPage> {
  final repo = StockRepository();
  final Set<String> pilih = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Alert & PO'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: StreamBuilder(
        stream: repo.watchLowStock(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Semua stok aman'));
          return Column(children: [
            Padding(padding: const EdgeInsets.all(8), child: Text('${list.length} SKU <= min', style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
              final p = list[i];
              final need = repo.suggestQty(p);
              final sel = pilih.contains(p.kode);
              return CheckboxListTile(
                value: sel,
                onChanged: (v) => setState(() => v! ? pilih.add(p.kode) : pilih.remove(p.kode)),
                title: Text('${p.kode} • ${p.nama}', style: const TextStyle(fontSize: 12)),
                subtitle: Text('Stok ${p.stok} / min ${p.minStok} • usul +$need • Rp ${p.harga.jual}'),
              );
            })),
            Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart), label: Text('Buat PO (${pilih.length})'),
              onPressed: pilih.isEmpty ? null : () async {
                final all = (await repo.fetchAll3000()).where((p) => pilih.contains(p.kode)).toList();
                await repo.createPO(items: {for (final p in all) p.kode: repo.suggestQty(p)}, catatan: 'Auto dari alert');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PO DRAFT dibuat')));
              },
            ))),
          ]);
        },
      ),
    );
  }
}
