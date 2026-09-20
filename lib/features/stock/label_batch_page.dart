import 'package:flutter/material.dart';
import 'stock_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Label Batch'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(hintText: 'Cari kode/nama...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        Expanded(child: FutureBuilder(
          future: repo.fetchAll3000(),
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            var list = s.data!;
            if (q.isNotEmpty) list = list.where((p) => p.kode.toLowerCase().contains(q.toLowerCase()) || p.nama.toLowerCase().contains(q.toLowerCase())).take(100).toList();
            else { list = list.take(100).toList(); }
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
