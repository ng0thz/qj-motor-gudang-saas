import 'package:flutter/material.dart';
import 'stock_repository.dart';

// Work Order sederhana link ke OUT via woId
class WorkOrderPage extends StatefulWidget {
  const WorkOrderPage({super.key});
  @override
  State<WorkOrderPage> createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage> {
  final repo = StockRepository();
  final nopolCtrl = TextEditingController();
  final motorCtrl = TextEditingController();
  final keluhanCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Work Order'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: nopolCtrl, decoration: const InputDecoration(labelText: 'Nopol', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: motorCtrl, decoration: const InputDecoration(labelText: 'Motor', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: keluhanCtrl, decoration: const InputDecoration(labelText: 'Keluhan', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () async {
              if (nopolCtrl.text.isEmpty) return;
              await repo.createWO(nopol: nopolCtrl.text.trim(), motor: motorCtrl.text.trim(), keluhan: keluhanCtrl.text.trim());
              nopolCtrl.clear(); motorCtrl.clear(); keluhanCtrl.clear();
            }, child: const Text('Buat WO')),
          ]),
        ])),
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.watchWO(),
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) return const Center(child: Text('Belum ada WO'));
            return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
              final w = s.data![i];
              return ListTile(
                title: Text('${w['nopol']} • ${w['motor'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${w['keluhan'] ?? ''} • ${w['status']} • ID ${w['id'].toString().substring(0, 6)}'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.pop(context, w['id']), // pilih WO -> dipakai sebagai woId OUT
              );
            });
          },
        )),
      ]),
    );
  }
}
