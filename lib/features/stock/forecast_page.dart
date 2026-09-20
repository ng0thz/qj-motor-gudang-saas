import 'package:flutter/material.dart';
import 'stock_repository.dart';
import 'forecast_service.dart';
import 'stock_model.dart';

// Analisa forecasting: kebutuhan 30 hari + safety + estimasi habis + trend
// Prioritas: stok menipis / FAST moving dulu (max 20 item agar hemat read)
class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key});
  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  final repo = StockRepository();
  final fc = ForecastService();
  List<Sparepart> items = [];
  Map<String, ForecastResult> hasil = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await repo.fetchAll3000();
    final low = all.where((p) => p.stok <= p.minStok).toList()
      ..sort((a, b) => (a.stok - a.minStok).compareTo(b.stok - b.minStok));
    final fast = all.where((p) => p.kategori == 'FAST' && p.stok > p.minStok).take(5).toList();
    final target = [...low.take(15), ...fast];
    setState(() => items = target);
    for (final p in target) {
      final r = await fc.forecastFor(p.kode, stokSaatIni: p.stok);
      if (!mounted) return;
      setState(() => hasil[p.kode] = r);
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Forecasting'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i];
                final f = hasil[p.kode];
                final eta = f == null ? '...' : (f.daysOfStock > 9000 ? 'tidak ada pemakaian' : '${f.daysOfStock} hari lagi habis');
                final trend = f == null ? '' : ' • trend ${f.trendPct >= 0 ? '+' : ''}${f.trendPct.toStringAsFixed(0)}%';
                return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.kode} • ${p.nama}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Stok ${p.stok} / min ${p.minStok} • Rp ${p.harga.jual}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 6),
                    if (f == null)
                      const Text('Hitung...', style: TextStyle(fontSize: 12))
                    else ...[
                      Text('Butuh 30 hari: ${f.forecast30} • Safety: ${f.safetyStock} • OUT 90 hari: ${f.out90}$trend', style: const TextStyle(fontSize: 12)),
                      Text('Estimasi: $eta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: f.daysOfStock <= 14 ? Colors.red : Colors.green)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: null, child: Text('Usul order +${f.suggestOrder}'))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(
                          onPressed: f.suggestOrder == 0 ? null : () async {
                            await repo.createPO(items: {p.kode: f.suggestOrder}, catatan: 'Forecast 30d + safety (OUT90 ${f.out90})');
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PO ${p.kode} +${f.suggestOrder} dibuat')));
                          },
                          child: const Text('Buat PO'))),
                      ]),
                    ],
                  ]),
                ));
              },
            ),
    );
  }
}
