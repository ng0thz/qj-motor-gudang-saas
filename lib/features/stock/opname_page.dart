import 'package:flutter/material.dart';
import 'stock_repository.dart';
import 'stock_model.dart';
import 'scan_page.dart';
import 'part_baru_page.dart';
import 'opname_report_page.dart';
import '../../core/session.dart';

// Opname: MULAI/GABUNG SESI -> HITUNG via scan (multi-HP) -> REVIEW -> APPROVED.
// Satu HP mulai sesi, SEMUA HP terdaftar bisa input hitung via scan.
// Alur cepat: Scan -> dialog jumlah (+/-) -> Simpan & Scan Lagi.
class OpnamePage extends StatefulWidget {
  const OpnamePage({super.key});
  @override
  State<OpnamePage> createState() => _OpnamePageState();
}

class _OpnamePageState extends State<OpnamePage> {
  final repo = StockRepository();
  String? opnameId;
  Map<String, dynamic>? sesi;
  final zonaCtrl = TextEditingController(text: 'A');
  List<Sparepart> list = [];
  final Map<String, TextEditingController> fisik = {};
  final Map<String, Map<String, dynamic>> counted = {}; // kode -> item live
  bool starting = false;

  @override
  void dispose() {
    zonaCtrl.dispose();
    for (final c in fisik.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _start() async {
    if (!AuthSession.instance.canStartOpname) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mulai sesi: Staff Gudang / Kepala Mekanik / Ops.')));
      return;
    }
    setState(() => starting = true);
    try {
      final id = await repo.startOpname(
        scopeZona: zonaCtrl.text.split(',').map((e) => e.trim()).toList(),
        catatan: 'Opname ${DateTime.now()} oleh ${AuthSession.instance.email}');
      await _join(id, null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mulai: $e')));
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  Future<void> _join(String id, Map<String, dynamic>? info) async {
    final zona = (info != null && (info['scopeZona'] as List?) != null)
        ? (info['scopeZona'] as List).map((e) => '$e'.trim().toUpperCase()).toList()
        : zonaCtrl.text.split(',').map((e) => e.trim().toUpperCase()).toList();
    // Query per zona di server (hemat baca untuk 10rb+ SKU, bukan tarik semua).
    final all = await repo.fetchByZona(zona);
    if (!mounted) return;
    setState(() {
      opnameId = id;
      sesi = info;
      list = all.take(2000).toList();
      for (final p in list) { fisik[p.kode] = TextEditingController(text: '${p.stok}'); }
    });
  }

  // Simpan HANYA yang berubah (hasil scan / edit manual beda dari sistem),
  // batch 400/komit. Yang belum dihitung tetap "belum dihitung" (jujur di review).
  Future<void> _saveAll() async {
    final rows = <Map<String, dynamic>>[];
    for (final p in list) {
      final cur = counted[p.kode];
      if (cur != null) {
        rows.add({'kode': p.kode, 'stokSistem': p.stok,
          'stokFisik': cur['stokFisik'] as int? ?? p.stok});
        continue;
      }
      final f = int.tryParse(fisik[p.kode]?.text ?? '');
      if (f != null && f != p.stok) {
        rows.add({'kode': p.kode, 'stokSistem': p.stok, 'stokFisik': f});
      }
    }
    if (rows.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada perubahan — semua sama dengan sistem')));
      return;
    }
    try {
      final n = await repo.saveCountsBatch(opnameId: opnameId!, rows: rows);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n perubahan tersimpan (dari ${list.length} part), siap review')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
    }
  }

  // Scan cepat: cocok -> dialog jumlah; tak cocok -> tawar daftar baru.
  Future<void> _scanHitung({bool loop = false}) async {
    if (!AuthSession.instance.canCountOpname) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun Anda tidak punya akses input opname.')));
      return;
    }
    final code = await openScan(context, title: 'Scan Opname ${sesi?['scopeZona'] ?? ''}');
    if (code == null || !mounted) return;
    final part = await repo.getByBarcode(code);
    if (!mounted) return;
    if (part == null) {
      if (AuthSession.instance.canCreatePart) {
        final daftar = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          title: const Text('Kode belum terdaftar'),
          content: Text('"$code" belum ada di master.\nDaftarkan dulu lalu hitung?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Lewati')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Daftarkan')),
          ],
        ));
        if (daftar == true && mounted) {
          final ok = await Navigator.push(context, MaterialPageRoute(
            builder: (_) => PartBaruPage(kodeAwal: code)));
          if (ok == true && mounted && loop) _scanHitung(loop: true);
        } else if (loop && mounted) {
          _scanHitung(loop: true);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belum terdaftar: $code (hubungi Staff Gudang)')));
        if (loop) _scanHitung(loop: true);
      }
      return;
    }
    // Pastikan part masuk daftar sesi (mis. zona beda / part baru)
    if (!list.any((p) => p.kode == part.kode)) {
      setState(() {
        list = [...list, part];
        fisik[part.kode] = TextEditingController(text: '${part.stok}');
      });
    }
    final again = await _quickCount(part);
    if (again == true && mounted) _scanHitung(loop: true);
  }

  // Dialog hitung cepat: stepper + simpan langsung. Return true = scan lagi.
  Future<bool?> _quickCount(Sparepart p) async {
    final cur = counted[p.kode];
    var val = cur != null ? (cur['stokFisik'] as int? ?? p.stok) : p.stok;
    final ctrl = TextEditingController(text: '$val');
    var saved = false;
    final r = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(p.kode, style: const TextStyle(fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Sistem: ${p.stok} • ${p.alamat.isEmpty ? 'tanpa alamat' : p.alamat}',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (cur != null) Text('Terhitung: ${cur['stokFisik']} oleh ${cur['countedBy'] ?? '-'}',
            style: const TextStyle(fontSize: 12, color: Colors.blue)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(iconSize: 28, onPressed: () {
              val = (int.tryParse(ctrl.text) ?? val) - 1;
              if (val < 0) val = 0;
              ctrl.text = '$val'; setD(() {});
            }, icon: const Icon(Icons.remove)),
            SizedBox(width: 90, child: TextField(controller: ctrl, textAlign: TextAlign.center,
              keyboardType: TextInputType.number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Fisik', border: OutlineInputBorder()),
              onChanged: (v) => val = int.tryParse(v) ?? val)),
            IconButton.filledTonal(iconSize: 28, onPressed: () {
              val = (int.tryParse(ctrl.text) ?? val) + 1;
              ctrl.text = '$val'; setD(() {});
            }, icon: const Icon(Icons.add)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
          ElevatedButton(
            onPressed: () async {
              await repo.saveCount(opnameId: opnameId!, kode: p.kode, stokSistem: p.stok, stokFisik: val);
              saved = true;
              if (ctx.mounted) Navigator.pop(ctx, false);
            },
            child: const Text('Simpan')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
            onPressed: () async {
              await repo.saveCount(opnameId: opnameId!, kode: p.kode, stokSistem: p.stok, stokFisik: val);
              saved = true;
              if (ctx.mounted) Navigator.pop(ctx, true); // scan lagi
            },
            child: const Text('Simpan & Scan Lagi')),
        ],
      )));
    if (saved) {
      fisik[p.kode]?.text = '$val';
      if (mounted) setState(() {}); // refresh warna status via stream di bawah
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final s = AuthSession.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QJ Motor - Opname'),
        backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
      ),
      body: opnameId == null ? _lobby(s) : _counting(s),
      floatingActionButton: opnameId == null
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton.extended(
                heroTag: 'scanLoop',
                onPressed: () => _scanHitung(loop: true),
                icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan Hitung')),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'scanOnce',
                backgroundColor: Colors.white, foregroundColor: const Color(0xFF1B2A4A),
                onPressed: () => _scanHitung(),
                icon: const Icon(Icons.qr_code), label: const Text('Scan 1x')),
            ]),
    );
  }

  // Lobi: mulai sesi baru ATAU gabung sesi aktif (multi-HP).
  Widget _lobby(AuthSession s) {
    return Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
          icon: const Icon(Icons.assignment, size: 16),
          label: const Text('Riwayat & Report'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const OpnameReportPage())),
        )),
        const SizedBox(height: 8),
        const Text('1) Mulai sesi baru (Staff / Kepala Mekanik / Ops)',
          style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          Expanded(child: TextField(controller: zonaCtrl, decoration: const InputDecoration(
            labelText: 'Zona (A,B)', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: starting ? null : _start,
            child: Text(starting ? '...' : 'Mulai')),
        ]),
        const SizedBox(height: 12),
        const Text('2) Atau gabung sesi yang sedang berjalan (semua HP)',
          style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.watchOpnames(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final sesiAktif = snap.data!;
            if (sesiAktif.isEmpty) {
              return const Center(child: Text('Belum ada sesi aktif.\nMulai sesi baru di atas.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
            }
            return ListView.builder(itemCount: sesiAktif.length, itemBuilder: (_, i) {
              final o = sesiAktif[i];
              return Card(child: ListTile(
                leading: const Icon(Icons.fact_check, color: Color(0xFF1B2A4A)),
                title: Text('Zona ${(o['scopeZona'] as List?)?.join(',') ?? '-'} • ${o['status']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${o['catatan'] ?? ''}', style: const TextStyle(fontSize: 11)),
                trailing: ElevatedButton(
                  onPressed: () => _join(o['id'] as String, o),
                  child: const Text('Gabung')),
              ));
            });
          },
        )),
      ]));
  }

  Widget _counting(AuthSession s) {
    return Column(children: [
      Align(alignment: Alignment.centerRight, child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.receipt_long, size: 16),
          label: const Text('Report sesi ini'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => OpnameDetailPage(opnameId: opnameId!))),
        ),
      )),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF1B2A4A),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.watchOpnameItems(opnameId!),
          builder: (c, snap) {
            final items = snap.data ?? [];
            counted.clear();
            for (final m in items) { counted['${m['kode']}'] = m; }
            final cocok = items.where((m) => m['status'] == 'COCOK').length;
            final selisih = items.length - cocok;
            return Text('Sesi $opnameId • Terhitung ${items.length}/${list.length} '
              '(Cocok $cocok, Selisih $selisih) • live dari semua HP',
              style: const TextStyle(color: Colors.white, fontSize: 11));
          },
        )),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.watchOpnameItems(opnameId!),
        builder: (c, snap) {
          final items = snap.data ?? [];
          counted.clear();
          for (final m in items) { counted['${m['kode']}'] = m; }
          return ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
            final p = list[i];
            final m = counted[p.kode];
            final st = m?['status'] as String?;
            return ListTile(
              dense: true,
              leading: Icon(
                st == null ? Icons.radio_button_unchecked
                  : st == 'COCOK' ? Icons.check_circle : Icons.warning,
                color: st == null ? Colors.grey : st == 'COCOK' ? Colors.green : Colors.orange,
                size: 20),
              title: Text('${p.kode} • ${p.nama}', style: const TextStyle(fontSize: 12)),
              subtitle: Text(
                m == null
                    ? 'Sistem ${p.stok} • ${p.alamat}'
                    : 'Sistem ${p.stok} → Fisik ${m['stokFisik']} (${m['status']}) • ${m['countedBy'] ?? ''}',
                style: const TextStyle(fontSize: 11)),
              trailing: SizedBox(width: 76, child: TextField(
                controller: fisik[p.kode], keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fisik', border: OutlineInputBorder(), isDense: true),
                onTap: () => _quickCount(p))),
              onTap: () => _quickCount(p),
            );
          });
        })),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: _saveAll, child: const Text('Simpan Hitung'))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            if (!s.canApprove) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hanya Ops Manager yang bisa Approve.')));
              return;
            }
            await repo.approveOpname(opnameId: opnameId!, approve: true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Approved: selisih auto-adjust')));
              setState(() { opnameId = null; sesi = null; list = []; counted.clear(); });
            }
          },
          child: Text(s.canApprove ? 'Approve' : 'Approve (Ops)'))),
      ]),
    ]);
  }
}
