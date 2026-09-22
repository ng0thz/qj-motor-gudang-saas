import 'package:flutter/material.dart';
import 'stock_repository.dart';
import 'stock_model.dart';
import 'label_print_page.dart';

// Pilih banyak SKU -> cetak label PDF batch
class LabelBatchPage extends StatefulWidget {
  const LabelBatchPage({super.key});
  @override
  State<LabelBatchPage> createState() => _LabelBatchPageState();
}

class _LabelBatchPageState extends State<LabelBatchPage> {
  final repo = StockRepository();
  final Set<String> pilih = {};
  String q = '';
  String zona = '';

  List<Sparepart> _filter(List<Sparepart> all) {
    var list = all;
    if (q.isNotEmpty) {
      list = list.where((p) => p.kode.toLowerCase().contains(q.toLowerCase()) || p.nama.toLowerCase().contains(q.toLowerCase())).toList();
    }
    if (zona.trim().isNotEmpty) {
      final z = zona.trim().toUpperCase();
      list = list.where((p) => p.alamat.toUpperCase().startsWith(z)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Label Batch'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: TextField(onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(hintText: 'Cari kode/nama...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: Row(children: [
          Expanded(child: TextField(onChanged: (v) => setState(() => zona = v),
            decoration: const InputDecoration(hintText: 'Zona rak (mis. A) — kosong = semua', prefixIcon: Icon(Icons.grid_view), border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () async {
            final all = await repo.fetchAll3000();
            if (mounted) setState(() => pilih.addAll(_filter(all).map((p) => p.kode)));
          }, child: const Text('Pilih tampil')),
          TextButton(onPressed: () => setState(() => pilih.clear()), child: const Text('Reset')),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Bercode = Part Code. Tempel QR di bin, lalu scan langsung cocok.',
            style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: FutureBuilder(
          future: repo.fetchAll3000(),
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final list = _filter(s.data!).take(500).toList();
            return ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
              final p = list[i];
              final sel = pilih.contains(p.kode);
              return CheckboxListTile(
                value: sel, onChanged: (v) => setState(() => v! ? pilih.add(p.kode) : pilih.remove(p.kode)),
                title: Text(p.nama, style: const TextStyle(fontSize: 12)),
                subtitle: Text('${p.kode} • ${p.alamat}'),
              );
            });
          },
        )),
        Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf), label: Text('Cetak ${pilih.length} Label'),
          onPressed: pilih.isEmpty ? null : () async {
            final all = await repo.fetchAll3000();
            final items = all.where((p) => pilih.contains(p.kode)).map((p) =>
              LabelItem(kode: p.kode, nama: p.nama, jual: p.harga.jual, alamat: p.alamat)).toList();
            if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LabelPrintPage(items: items)));
          },
        ))),
      ]),
    );
  }
}
