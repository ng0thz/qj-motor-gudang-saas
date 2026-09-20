import 'package:flutter/material.dart';
import 'stock_repository.dart';

// Dashboard: nilai stok, fast moving, dead stock, alert
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = StockRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Dashboard'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: FutureBuilder(
        future: repo.fetchAll3000(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final all = s.data!;
          final nilai = all.fold<int>(0, (t, p) => t + (p.stok * p.harga.jual));
          final fast = all.where((p) => p.kategori == 'FAST').length;
          final habis = all.where((p) => p.stok == 0).length;
          final menipis = all.where((p) => p.stok > 0 && p.stok <= p.minStok).length;
          // Dead stock: stok>0 tapi updatedAt lama tidak bisa akurat tanpa movement; pakai status DRAFT lama sebagai proxy
          final dead = all.where((p) => p.stok > 0 && p.kategori == 'SLOW').take(10).toList();
          return ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              Expanded(child: _card('Nilai Stok', 'Rp $nilai', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _card('SKU', '${all.length}', Colors.grey)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _card('FAST', '$fast', Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _card('Habis', '$habis', Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _card('Menipis', '$menipis', Colors.orange)),
            ]),
            const SizedBox(height: 12),
            const Text('Dead stock contoh (SLOW + ada stok)', style: TextStyle(fontWeight: FontWeight.bold)),
            ...dead.map((p) => ListTile(dense: true, title: Text('${p.kode} • ${p.nama}', style: const TextStyle(fontSize: 12)), trailing: Text('Stok ${p.stok}'))),
          ]);
        },
      ),
    );
  }

  Widget _card(String t, String v, Color c) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [Text(t, style: const TextStyle(fontSize: 11)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13))]));
  }
}
