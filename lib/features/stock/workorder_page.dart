import 'package:flutter/material.dart';
import 'stock_repository.dart';
import 'frt_data.dart';
import 'job_part_map.dart';
import 'frt_import_page.dart';
import 'motor_class.dart';
import 'workorder_track_page.dart';

// WO: pilih Model + Tipe (Service/Warranty) -> pilih Job -> jasa otomatis.
// Tambah Part A,B,C -> saran job muncul. Total = part + labour.
class WorkOrderPage extends StatefulWidget {
  const WorkOrderPage({super.key});
  @override
  State<WorkOrderPage> createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage> {
  final repo = StockRepository();
  final nopolCtrl = TextEditingController();
  final keluhanCtrl = TextEditingController();
  String model = 'FORT 250';
  String tipe = 'SERVICE'; // SERVICE|WARRANTY
  String kategori = 'Reguler'; // Reguler|JobReturn|Kunjung|KSG1..KSG8|Warranty|PDI
  final kuponCtrl = TextEditingController();
  bool kuponStempel = false;
  static const kategoris = ['Reguler', 'JobReturn', 'Kunjung', 'KSG1', 'KSG2', 'KSG3', 'KSG4', 'KSG5', 'KSG6', 'KSG7', 'KSG8', 'Warranty', 'PDI'];
  String jobQuery = '';
  String partQuery = '';
  List<FrtEntry> frtCache = [];
  List<Map<String, dynamic>> jobs = []; // {faultCode, job, price}
  List<Map<String, dynamic>> parts = []; // {kode, nama, jual, qty}
  List<String> saranJob = [];

  final models = motorMaster.map((e) => e.model).toList();
  List<DropdownMenuItem<String>> get modelItems {
    final out = <DropdownMenuItem<String>>[];
    for (final k in ['KECIL', 'MEDIUM', 'HIGH']) {
      out.add(DropdownMenuItem(value: '__$k', enabled: false, child: Text('-- $k --', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))));
      for (final m in modelsOfKelas(k)) {
        out.add(DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))));
      }
    }
    return out;
  }

  Future<void> _loadFrt() async {
    final rows = await repo.fetchFrt(tipe);
    if (rows.isNotEmpty) {
      frtCache = rows.map((m) => FrtEntry(
        faultCode: '${m['faultCode'] ?? m['id'] ?? ''}',
        category: '${m['category'] ?? ''}',
        job: '${m['job'] ?? ''}',
        hours: Map<String, double>.from(((m['hours'] ?? {}) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
        price: Map<String, int>.from(((m['price'] ?? {}) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
      )).toList();
    } else {
      frtCache = tipe == 'WARRANTY' ? seedWarranty : seedService;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadFrt();
  }

  int get labourTotal => jobs.fold<int>(0, (t, j) => t + ((j['price'] ?? 0) as int));
  int get partsTotal => parts.fold<int>(0, (t, p) => t + ((p['jual'] ?? 0) as int) * ((p['qty'] ?? 1) as int));

  List<FrtEntry> get filteredJobs {
    final list = frtCache.where((e) => e.appliesTo(model)).toList();
    if (jobQuery.isEmpty) return list.take(30).toList();
    final q = jobQuery.toUpperCase();
    return list.where((e) => e.job.toUpperCase().contains(q) || e.faultCode.contains(q)).take(30).toList();
  }

  Future<void> _tambahPart() async {
    if (partQuery.isEmpty) return;
    final found = await repo.getByBarcode(partQuery.trim());
    if (found == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Part tidak ketemu: $partQuery')));
      return;
    }
    setState(() {
      parts.add({'kode': found.kode, 'nama': found.nama, 'jual': found.harga.jual, 'qty': 1, 'jenisPart': found.jenisPart});
      // Saran job dari part yang baru ditambah
      final s = suggestJobsForPart(kode: found.kode, nama: found.nama, jenisPart: found.jenisPart);
      for (final f in s) { if (!saranJob.contains(f)) saranJob.add(f); }
      // Fallback kategori bila tidak ada rule cocok
      if (s.isEmpty) {
        final kat = jobCategoryForPart(found.jenisPart);
        if (kat.isNotEmpty) {
          for (final e in frtCache.where((e) => e.category == kat && e.appliesTo(model)).take(3)) {
            if (!saranJob.contains(e.faultCode)) saranJob.add(e.faultCode);
          }
        }
      }
      partQuery = '';
    });
  }

  Future<void> _simpan() async {
    if (nopolCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nopol wajib diisi')));
      return;
    }
    await repo.createWO(
      nopol: nopolCtrl.text.trim(), motor: model, keluhan: keluhanCtrl.text.trim(),
      model: model, tipe: tipe, kategori: kategori,
      kuponNo: kuponCtrl.text.trim(), kuponStempel: kuponStempel,
      jobs: jobs, parts: parts,
      labourTotal: labourTotal, partsTotal: partsTotal,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WO tersimpan. Labour Rp $labourTotal + Part Rp $partsTotal')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Work Order + FRT'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Tracking nopol', icon: const Icon(Icons.history), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrderTrackPage()))),
          IconButton(tooltip: 'Import FRT', icon: const Icon(Icons.upload_file), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FrtImportPage()))),
        ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(child: TextField(controller: nopolCtrl, decoration: const InputDecoration(labelText: 'Nopol', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(value: model, decoration: InputDecoration(labelText: 'Model (${kelasOf(model)})', border: const OutlineInputBorder()),
            items: modelItems,
            onChanged: (v) { if (v == null || v.startsWith('__')) return; setState(() => model = v); })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: tipe, decoration: const InputDecoration(labelText: 'Tipe', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'SERVICE', child: Text('Service (retail)')), DropdownMenuItem(value: 'WARRANTY', child: Text('Warranty Claim'))],
            onChanged: (v) { setState(() { tipe = v!; jobs.clear(); }); _loadFrt(); })),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: keluhanCtrl, decoration: const InputDecoration(labelText: 'Keluhan', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: kategori, decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
            items: kategoris.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => kategori = v!))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: kuponCtrl, decoration: const InputDecoration(labelText: 'No. Kupon (KSG)', border: OutlineInputBorder()))),
          Checkbox(value: kuponStempel, onChanged: (v) => setState(() => kuponStempel = v ?? false)),
          const Text('Stempel', style: TextStyle(fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        Text('Pekerjaan ($tipe) — jasa otomatis per $model', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextField(decoration: const InputDecoration(hintText: 'Cari fault code / nama job...', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => jobQuery = v)),
        ...filteredJobs.map((e) => ListTile(
          dense: true,
          title: Text('${e.faultCode.isEmpty ? '' : '${e.faultCode} • '}${e.job}', style: const TextStyle(fontSize: 12)),
          trailing: Text('Rp ${e.priceFor(model)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          onTap: () => setState(() => jobs.add({'faultCode': e.faultCode, 'job': e.job, 'price': e.priceFor(model)})),
        )),
        if (jobs.isNotEmpty) ...[
          const Divider(),
          ...jobs.map((j) => ListTile(dense: true, title: Text('${j['faultCode']} • ${j['job']}', style: const TextStyle(fontSize: 12)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Rp ${j['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => jobs.remove(j))),
            ]))),
        ],
        const SizedBox(height: 12),
        const Text('Part A,B,C — tambah part, saran job muncul', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Scan/ketik kode part...', border: OutlineInputBorder()),
            onChanged: (v) => partQuery = v, onSubmitted: (_) => _tambahPart())),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _tambahPart, child: const Text('+ Part')),
        ]),
        ...parts.map((p) => ListTile(dense: true, title: Text('${p['kode']} • ${p['nama']}', style: const TextStyle(fontSize: 12)),
          subtitle: Text('Rp ${p['jual']} x${p['qty']}'),
          trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => parts.remove(p))))),
        if (saranJob.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.all(8), color: Colors.blue.shade50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Saran job dari part:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Wrap(spacing: 6, children: saranJob.map((f) {
                FrtEntry? e;
                try { e = frtCache.firstWhere((x) => x.faultCode == f); } catch (_) { e = null; }
                final label = e == null ? f : '${e.faultCode} • ${e.job} (Rp ${e.priceFor(model)})';
                return ActionChip(label: Text(label, style: const TextStyle(fontSize: 11)), onPressed: e == null ? null : () => setState(() {
                  jobs.add({'faultCode': e!.faultCode, 'job': e.job, 'price': e.priceFor(model)});
                }));
              }).toList()),
            ])),
        ],
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), color: const Color(0xFF1B2A4A),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Labour', style: TextStyle(color: Colors.white)), Text('Rp $labourTotal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Part', style: TextStyle(color: Colors.white)), Text('Rp $partsTotal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text('Rp ${labourTotal + partsTotal}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
          ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpan, child: const Text('Simpan WO'))),
      ]),
    );
  }
}
