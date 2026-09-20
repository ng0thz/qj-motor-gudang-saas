import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'stock_repository.dart';
import 'frt_data.dart';

// Import digitasi penuh 2 tabel FRT dari CSV.
// Format: fault_code,category,job,fort250_hour,fort250_price,srv250_hour,srv250_price,srv600_hour,srv600_price,srk800_hour,srk800_price
// PRICE '-' / kosong = 0 (tidak berlaku, disembunyikan).
class FrtImportPage extends StatefulWidget {
  const FrtImportPage({super.key});
  @override
  State<FrtImportPage> createState() => _FrtImportPageState();
}

class _FrtImportPageState extends State<FrtImportPage> {
  final repo = StockRepository();
  String tipe = 'WARRANTY';
  String log = 'Pilih CSV FRT.\nSeed bawaan: ${seedWarranty.length} warranty + ${seedService.length} service.';
  bool loading = false;

  Future<void> _seed() async {
    setState(() => loading = true);
    final list = tipe == 'WARRANTY' ? seedWarranty : seedService;
    await repo.saveFrtBatch(tipe, list.map((e) => e.toMap()).toList());
    setState(() { log = 'Seed ${list.length} $tipe tersimpan.'; loading = false; });
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (res == null) return;
    setState(() => loading = true);
    try {
      final text = String.fromCharCodes(res.files.first.bytes!);
      final lines = text.split('\n').skip(1);
      final rows = <Map<String, dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final c = line.split(',');
        if (c.length < 3) continue;
        int p(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        double h(String s) => double.tryParse(s.trim()) ?? 0;
        rows.add({
          'faultCode': c[0].trim(), 'category': c[1].trim(), 'job': c[2].trim(),
          'hours': {'FORT 250': h(c.length > 3 ? c[3] : '0'), 'SRV 250 AMT': h(c.length > 5 ? c[5] : '0'), 'SRV 600 V': h(c.length > 7 ? c[7] : '0'), 'SRK 800 RR': h(c.length > 9 ? c[9] : '0')},
          'price': {'FORT 250': p(c.length > 4 ? c[4] : '0'), 'SRV 250 AMT': p(c.length > 6 ? c[6] : '0'), 'SRV 600 V': p(c.length > 8 ? c[8] : '0'), 'SRK 800 RR': p(c.length > 10 ? c[10] : '0')},
        });
      }
      await repo.saveFrtBatch(tipe, rows);
      setState(() => log = 'Import $tipe: ${rows.length} baris tersimpan.');
    } catch (e) {
      setState(() => log = 'Gagal: $e');
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Import FRT'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(value: tipe, decoration: const InputDecoration(labelText: 'Tipe', border: OutlineInputBorder()),
          items: const [DropdownMenuItem(value: 'WARRANTY', child: Text('WARRANTY CLAIM')), DropdownMenuItem(value: 'SERVICE', child: Text('SERVICE retail'))],
          onChanged: (v) => setState(() => tipe = v!)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: loading ? null : _seed, child: const Text('Simpan Seed'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: loading ? null : _pick, child: const Text('Pilih CSV Penuh'))),
        ]),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: Text(log))),
      ])),
    );
  }
}
