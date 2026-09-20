import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_repository.dart';

// Batch/lot per part + konsumsi FIFO
class BatchPage extends StatefulWidget {
  final String kode;
  final String nama;
  const BatchPage({super.key, required this.kode, required this.nama});
  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  final repo = StockRepository();
  List<Map<String, dynamic>> lots = [];
  final lotCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '10');

  Future<void> _load() async {
    lots = await repo.fetchBatches(widget.kode);
    setState(() {});
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');
    return Scaffold(
      appBar: AppBar(title: Text('Batch ${widget.kode}'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: lotCtrl, decoration: const InputDecoration(labelText: 'Lot No (misal L-2026-01)', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () async {
            await repo.addBatch(kode: widget.kode, lotNo: lotCtrl.text.trim(), qty: int.tryParse(qtyCtrl.text) ?? 0, expired: DateTime.now().add(const Duration(days: 365)));
            lotCtrl.clear();
            _load();
          }, child: const Text('Tambah')),
        ])),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('FIFO: expired terdekat / masuk pertama dipakai dulu', style: TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: ListView.builder(itemCount: lots.length, itemBuilder: (_, i) {
          final l = lots[i];
          return ListTile(
            title: Text('${l['lotNo']} • sisa ${l['qty']}/${l['qtyAwal'] ?? ''}'),
            subtitle: Text('Masuk ${l['tglMasuk'] != null ? fmt.format((l['tglMasuk'] as dynamic).toDate()) : '-'} • Exp ${l['expired'] != null ? fmt.format((l['expired'] as dynamic).toDate()) : '-'}'),
          );
        })),
      ]),
    );
  }
}
