import 'package:flutter/material.dart';
import 'stock_repository.dart';
import 'stock_model.dart';
import '../../core/session.dart';

// Opname: COUNTING -> REVIEW (variance) -> APPROVED (auto adjust)
class OpnamePage extends StatefulWidget {
  const OpnamePage({super.key});
  @override
  State<OpnamePage> createState() => _OpnamePageState();
}

class _OpnamePageState extends State<OpnamePage> {
  final repo = StockRepository();
  String? opnameId;
  final zonaCtrl = TextEditingController(text: 'A');
  List<Sparepart> list = [];
  final Map<String, TextEditingController> fisik = {};

  Future<void> _start() async {
    final id = await repo.startOpname(scopeZona: zonaCtrl.text.split(','), catatan: 'Opname ${DateTime.now()}');
    final all = await repo.fetchAll3000();
    final zona = zonaCtrl.text.split(',').map((e) => e.trim().toUpperCase()).toList();
    setState(() {
      opnameId = id;
      list = all.where((p) => zona.any((z) => p.alamat.toUpperCase().startsWith(z))).take(200).toList();
      for (final p in list) { fisik[p.kode] = TextEditingController(text: '${p.stok}'); }
    });
  }

  Future<void> _saveAll() async {
    for (final p in list) {
      final f = int.tryParse(fisik[p.kode]?.text ?? '') ?? p.stok;
      await repo.saveCount(opnameId: opnameId!, kode: p.kode, stokSistem: p.stok, stokFisik: f);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hasil hitung tersimpan, siap review')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Opname'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: zonaCtrl, decoration: const InputDecoration(labelText: 'Zona (A,B)', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _start, child: const Text('Mulai')),
        ]),
        const SizedBox(height: 8),
        if (opnameId != null) Text('ID: $opnameId • ${list.length} item', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
          final p = list[i];
          return ListTile(
            title: Text('${p.kode} • ${p.nama}', style: const TextStyle(fontSize: 12)),
            subtitle: Text('Sistem ${p.stok} • ${p.alamat}'),
            trailing: SizedBox(width: 80, child: TextField(controller: fisik[p.kode], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fisik', border: OutlineInputBorder()))),
          );
        })),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: opnameId == null ? null : _saveAll, child: const Text('Simpan Hitung'))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: opnameId == null ? null : () async {
              if (!AuthSession.instance.canApprove) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hanya Ops Manager yang bisa Approve.')));
                return;
              }
              await repo.approveOpname(opnameId: opnameId!, approve: true);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved: selisih auto-adjust')));
            }, child: Text(AuthSession.instance.canApprove ? 'Approve' : 'Approve (Ops)'))),
        ]),
      ])),
    );
  }
}
