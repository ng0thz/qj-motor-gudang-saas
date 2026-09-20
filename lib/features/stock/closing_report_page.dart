import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'stock_repository.dart';

// Laporan aktivitas bengkel harian -> dikirim WA saat closing.
// Dibaca: Operation Manager, Direktur/Komisaris, Owner.
// Sumber: work_orders + stock_movements hari ini + stok kritis + PO.
class ClosingReportPage extends StatefulWidget {
  const ClosingReportPage({super.key});
  @override
  State<ClosingReportPage> createState() => _ClosingReportPageState();
}

class _ClosingReportPageState extends State<ClosingReportPage> {
  final repo = StockRepository();
  bool loading = true;
  String text = '';
  Map<String, dynamic> summary = {};
  final Set<String> pilihPenerima = {};

  @override
  void initState() {
    super.initState();
    _build();
  }

  DateTime _startOfToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _build() async {
    setState(() => loading = true);
    final start = _startOfToday();
    final tgl = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.now());
    final movs = await repo.fetchMovementsSince(start);
    final wos = await repo.fetchWOSince(start);
    final pos = await repo.fetchPOsSince(start);

    final woMasuk = wos.length;
    final woSelesai = wos.where((w) => '${w['status']}'.toUpperCase() == 'SELESAI').length;
    final woProses = wos.where((w) => ['OPEN', 'PROSES'].contains('${w['status']}'.toUpperCase())).length;

    int outQty = 0, inQty = 0;
    final Map<String, int> outPerPart = {};
    for (final m in movs) {
      final q = (m['qty'] ?? 0) as int;
      if (m['tipe'] == 'OUT') { outQty += q; outPerPart[m['kode_part']] = (outPerPart[m['kode_part']] ?? 0) + q; }
      if (m['tipe'] == 'IN') inQty += q;
    }
    final topOut = outPerPart.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    int omzet = 0;
    final all = await repo.fetchAll3000();
    final price = {for (final p in all) p.kode: p.harga.jual};
    for (final e in topOut) { omzet += (price[e.key] ?? 0) * e.value; }
    final habis = all.where((p) => p.stok == 0).length;
    final menipis = all.where((p) => p.stok > 0 && p.stok <= p.minStok).length;

    final buf = StringBuffer();
    buf.writeln('*LAPORAN HARIAN BENGKEL QJ MOTOR*');
    buf.writeln(tgl);
    buf.writeln('--------------------------');
    buf.writeln('1. WORK ORDER: $woMasuk masuk, $woSelesai selesai, $woProses proses/antri');
    buf.writeln('2. PART: OUT $outQty pcs, IN $inQty pcs');
    if (topOut.isNotEmpty) {
      buf.writeln('   Top OUT: ${topOut.take(3).map((e) => '${e.key} (${e.value})').join(', ')}');
    }
    buf.writeln('3. OMZET PART (estimasi): Rp $omzet');
    buf.writeln('4. STOK KRITIS: $habis habis, $menipis menipis');
    buf.writeln('5. PO HARI INI: ${pos.length} dokumen');
    buf.writeln('--------------------------');
    buf.writeln('Dibuat otomatis oleh sistem. Detail di aplikasi.');

    summary = {
      'woMasuk': woMasuk, 'woSelesai': woSelesai, 'woProses': woProses,
      'outQty': outQty, 'inQty': inQty, 'omzet': omzet,
      'habis': habis, 'menipis': menipis, 'po': pos.length,
    };
    setState(() { text = buf.toString(); loading = false; });
  }

  Future<void> _kirim() async {
    final recips = await repo.watchRecipients().first;
    final targets = recips.where((r) => pilihPenerima.contains(r['id']) && (r['aktif'] ?? true) == true).toList();
    if (targets.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih penerima dulu')));
      return;
    }
    // Arsip dulu
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await repo.saveDailyReport(dateKey: key, text: text, summary: {...summary, 'penerima': targets.map((t) => t['nama']).toList()});
    // Kirim per penerima via wa.me
    for (final t in targets) {
      final wa = '${t['wa']}'.replaceAll(RegExp(r'[^0-9]'), '');
      if (wa.isEmpty) continue;
      final uri = Uri.parse('https://wa.me/$wa?text=${Uri.encodeComponent(text)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Fallback share sheet
    await Share.share(text, subject: 'Laporan Harian QJ Motor');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan diarsip + dibuka di WA')));
  }

  Future<void> _kelolaPenerima() async {
    final nama = TextEditingController();
    final wa = TextEditingController();
    String role = 'Operation Manager';
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tambah penerima'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: role, items: const [
          DropdownMenuItem(value: 'Operation Manager', child: Text('Operation Manager')),
          DropdownMenuItem(value: 'Direktur/Komisaris', child: Text('Direktur/Komisaris')),
          DropdownMenuItem(value: 'Owner', child: Text('Owner')),
          DropdownMenuItem(value: 'Frontdesk', child: Text('Frontdesk')),
        ], onChanged: (v) => role = v!, decoration: const InputDecoration(labelText: 'Role')),
        const SizedBox(height: 8),
        TextField(controller: wa, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No WA (628...)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: () async {
          await repo.upsertRecipient(nama: nama.text.trim(), role: role, wa: wa.text.trim());
          if (mounted) Navigator.pop(context);
        }, child: const Text('Simpan')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Closing Harian'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _build),
          IconButton(icon: const Icon(Icons.person_add), onPressed: _kelolaPenerima),
        ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(text, style: const TextStyle(fontSize: 13))),
                const SizedBox(height: 12),
                const Text('Penerima (dicentang yang dikirim)', style: TextStyle(fontWeight: FontWeight.bold)),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repo.watchRecipients(),
                  builder: (c, s) {
                    if (!s.hasData) return const LinearProgressIndicator();
                    if (s.data!.isEmpty) return const Text('Belum ada penerima. Tambah via ikon orang di atas.', style: TextStyle(fontSize: 12));
                    // default centang semua saat pertama load
                    if (pilihPenerima.isEmpty) {
                      for (final r in s.data!) { pilihPenerima.add(r['id']); }
                    }
                    return Column(children: s.data!.map((r) => CheckboxListTile(
                      value: pilihPenerima.contains(r['id']),
                      onChanged: (v) => setState(() => v! ? pilihPenerima.add(r['id']) : pilihPenerima.remove(r['id'])),
                      title: Text('${r['nama']} • ${r['role']}', style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${r['wa']}', style: const TextStyle(fontSize: 11)),
                      secondary: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => repo.deleteRecipient(r['id'])),
                    )).toList());
                  },
                ),
              ]))),
              Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                icon: const Icon(Icons.send), label: const Text('Arsip + Kirim WA Closing'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                onPressed: _kirim,
              ))),
            ]),
    );
  }
}
