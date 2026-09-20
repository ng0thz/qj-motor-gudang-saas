import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'stock_repository.dart';

// DAILY OPERATION REPORT QJMOTOR ADIDAYA BALI – BENGKEL SERVICE
// Format A-F persis draft frontdesk. Angka auto dari WO + mutasi,
// D/E/F + Hotline manual, RINGKASAN auto (bisa edit).
class ClosingReportPage extends StatefulWidget {
  const ClosingReportPage({super.key});
  @override
  State<ClosingReportPage> createState() => _ClosingReportPageState();
}

class _ClosingReportPageState extends State<ClosingReportPage> {
  final repo = StockRepository();
  bool loading = true;
  Map<String, dynamic> d = {};
  final kerjaCtrl = TextEditingController();
  final kendalaCtrl = TextEditingController();
  final tindakCtrl = TextEditingController();
  final hotlineCtrl = TextEditingController();
  final ringkasanCtrl = TextEditingController();
  final Set<String> pilihPenerima = {};

  @override
  void initState() {
    super.initState();
    _build();
  }

  DateTime _start(DateTime n) => DateTime(n.year, n.month, n.day);

  int _kat(List<Map<String, dynamic>> wos, String k) =>
      wos.where((w) => '${w['kategori'] ?? 'Reguler'}' == k).length;

  Future<void> _build() async {
    setState(() => loading = true);
    final now = DateTime.now();
    final start = _start(now);
    final monthStart = DateTime(now.year, now.month, 1);
    final movs = await repo.fetchMovementsSince(start);
    final wos = await repo.fetchWOSince(start);
    final wosMonth = await repo.fetchWOSince(monthStart);
    final movsMonth = await repo.fetchMovementsSince(monthStart);
    final pos = await repo.fetchPOsSince(start);
    final all = await repo.fetchAll3000();
    final jenisOf = {for (final p in all) p.kode: p.jenisPart};
    final price = {for (final p in all) p.kode: p.harga.jual};

    // A. Unit
    final ksg = {for (var i = 1; i <= 8; i++) 'KSG$i': _kat(wos, 'KSG$i')};
    final reguler = _kat(wos, 'Reguler');
    final jobReturn = _kat(wos, 'JobReturn');
    final kunjung = _kat(wos, 'Kunjung');
    final warranty = _kat(wos, 'Warranty');
    final pdi = _kat(wos, 'PDI');
    final total = wos.length;
    final pdiLabour = wos.where((w) => '${w['kategori']}' == 'PDI').fold<int>(0, (t, w) => t + ((w['labourTotal'] ?? 0) as int));
    // Kupon KSG
    final kuponOk = wos.where((w) => '${w['kategori']}'.startsWith('KSG') && (w['kuponStempel'] == true)).length;
    final kuponTotal = ksg.values.fold<int>(0, (t, v) => t + v);

    // B. Sparepart dari OUT hari ini
    int oli = 0, filter = 0;
    final Map<String, int> indentPerPart = {};
    for (final m in movs) {
      if (m['tipe'] != 'OUT') continue;
      final kode = '${m['kode_part']}';
      final q = (m['qty'] ?? 0) as int;
      final j = (jenisOf[kode] ?? '').toUpperCase();
      final nama = kode.toUpperCase();
      if (j == 'OIL_FLUID' || nama.startsWith('LIDEM') || nama.contains('OIL')) oli += q;
      if (nama.contains('FILTER') || kode.startsWith('2601') || kode.startsWith('1601')) filter += q;
    }
    int indentItems = 0;
    for (final p in pos) {
      final items = (p['items'] ?? []) as List;
      indentItems += items.fold<int>(0, (t, e) => t + ((e['qty'] ?? 0) as int));
    }

    // C. Labour
    final labourToday = wos.where((w) => '${w['status']}'.toUpperCase() == 'SELESAI')
        .fold<int>(0, (t, w) => t + ((w['labourTotal'] ?? 0) as int));
    final labourMtd = wosMonth.where((w) => '${w['status']}'.toUpperCase() == 'SELESAI')
        .fold<int>(0, (t, w) => t + ((w['labourTotal'] ?? 0) as int));
    int omzetMtd = 0;
    for (final m in movsMonth) {
      if (m['tipe'] != 'OUT') continue;
      omzetMtd += (price['${m['kode_part']}'] ?? 0) * ((m['qty'] ?? 0) as int);
    }

    // F auto: WO belum selesai + stok kritis
    final tertunda = wos.where((w) => ['OPEN', 'PROSES'].contains('${w['status']}'.toUpperCase())).length;
    final habis = all.where((p) => p.stok == 0).length;
    final menipis = all.where((p) => p.stok > 0 && p.stok <= p.minStok).length;

    d = {
      'total': total, 'totalMtd': wosMonth.length,
      'reguler': reguler, 'jobReturn': jobReturn, 'kunjung': kunjung,
      'warranty': warranty, 'pdi': pdi, 'pdiLabour': pdiLabour,
      'ksg': ksg, 'kuponOk': kuponOk, 'kuponTotal': kuponTotal,
      'oli': oli, 'filter': filter, 'indent': indentItems,
      'labourToday': labourToday, 'labourMtd': labourMtd, 'omzetMtd': omzetMtd,
      'tertunda': tertunda, 'habis': habis, 'menipis': menipis,
      'po': pos.length,
    };
    ringkasanCtrl.text =
        '$total unit hari ini ($reguler reguler, ${ksg.values.fold(0, (a, b) => a + b)} KSG, ${_kat(wos, 'Warranty')} warranty, $pdi PDI). '
        'Tertunda $tertunda. Stok kritis $habis habis/$menipis menipis.';
    tindakCtrl.text = tertunda > 0 ? 'Selesaikan $tertunda WO tertunda.' : '';
    if (habis + menipis > 0) tindakCtrl.text += (tindakCtrl.text.isEmpty ? '' : ' ') + 'Cek $habis habis/$menipis menipis.';
    setState(() => loading = false);
  }

  String _text() {
    final tgl = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final ksg = (d['ksg'] ?? {}) as Map;
    final b = StringBuffer();
    b.writeln('📋 *DAILY OPERATION REPORT QJMOTOR ADIDAYA BALI – BENGKEL SERVICE*');
    b.writeln('📅 AKTIVITAS HARI INI Tanggal: [$tgl]');
    b.writeln('━━━━━━━━━━━━━━━━');
    b.writeln('*A. UNIT SERVICE*');
    b.writeln('Unit Service Total : ${d['total']}');
    b.writeln('Unit Service Total s/d hari ini : ${d['totalMtd']}');
    b.writeln('Service Reguler : ${d['reguler']}');
    b.writeln('Service Job Return : ${d['jobReturn']}');
    b.writeln('Service Kunjung : ${d['kunjung']}');
    b.writeln('Service Warranty/Claim : ${d['warranty']}');
    for (var i = 1; i <= 8; i += 4) {
      b.writeln('Unit KSG $i : ${ksg['KSG$i'] ?? 0}                     Unit KSG ${i + 4} : ${ksg['KSG${i + 4}'] ?? 0}');
    }
    b.writeln('Kupon terkumpul+stempel: ${d['kuponOk']}/${d['kuponTotal']}${(d['kuponTotal'] ?? 0) > (d['kuponOk'] ?? 0) ? ' ⚠️ kurang ${((d['kuponTotal'] ?? 0) as int) - ((d['kuponOk'] ?? 0) as int)}' : ' ✅'}');
    b.writeln('Unit PDI : ${d['pdi']}  Biaya service : Rp. ${d['pdiLabour']}');
    b.writeln('');
    b.writeln('B. SPAREPART');
    b.writeln('Oli Mesin : ${d['oli']}');
    b.writeln('Filter Oli : ${d['filter']}');
    b.writeln('Sparepart Indent : ${d['indent']} item');
    b.writeln('Hotline Order : ${hotlineCtrl.text.isEmpty ? '-' : hotlineCtrl.text}');
    b.writeln('');
    b.writeln('C. Labour / jasa service : Rp. ${d['labourToday']}');
    b.writeln('Total s/d hari ini :');
    b.writeln('Rp. ${d['labourMtd']} (omzet part MTD Rp. ${d['omzetMtd']})');
    b.writeln('');
    if (kerjaCtrl.text.isNotEmpty) { b.writeln('D. PEKERJAAN KHUSUS'); b.writeln(kerjaCtrl.text); b.writeln(''); }
    if (kendalaCtrl.text.isNotEmpty) { b.writeln('E. KENDALA'); b.writeln('• ${kendalaCtrl.text}'); b.writeln(''); }
    if (tindakCtrl.text.isNotEmpty) { b.writeln('F. TINDAK LANJUT BESOK'); b.writeln('• ${tindakCtrl.text}'); b.writeln(''); }
    b.writeln('━━━━━━━━━━━━━━━━━━');
    b.writeln('RINGKASAN ✅');
    b.writeln(ringkasanCtrl.text);
    b.writeln('');
    b.writeln('Terima kasih.');
    return b.toString();
  }

  Future<void> _kirim() async {
    final recips = await repo.watchRecipients().first;
    final targets = recips.where((r) => pilihPenerima.contains(r['id'])).toList();
    if (targets.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih penerima dulu')));
      return;
    }
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await repo.saveDailyReport(dateKey: key, text: _text(), summary: {...d,
      'kerja': kerjaCtrl.text, 'kendala': kendalaCtrl.text, 'tindak': tindakCtrl.text,
      'hotline': hotlineCtrl.text, 'ringkasan': ringkasanCtrl.text,
      'penerima': targets.map((t) => t['nama']).toList()});
    for (final t in targets) {
      final wa = '${t['wa']}'.replaceAll(RegExp(r'[^0-9]'), '');
      if (wa.isEmpty) continue;
      await launchUrl(Uri.parse('https://wa.me/$wa?text=${Uri.encodeComponent(_text())}'), mode: LaunchMode.externalApplication);
    }
    await Share.share(_text(), subject: 'Daily Operation Report QJMOTOR');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan A-F diarsip + dibuka di WA')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Laporan Harian A-F'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _build),
          IconButton(icon: const Icon(Icons.person_add), onPressed: () {})]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(_text(), style: const TextStyle(fontSize: 12))),
              const SizedBox(height: 12),
              const Text('Bagian manual (D/E/F + Hotline + Ringkasan bisa edit)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: kerjaCtrl, decoration: const InputDecoration(labelText: 'D. Pekerjaan khusus'), maxLines: 2, onChanged: (_) => setState(() {})),
              TextField(controller: kendalaCtrl, decoration: const InputDecoration(labelText: 'E. Kendala'), maxLines: 2, onChanged: (_) => setState(() {})),
              TextField(controller: tindakCtrl, decoration: const InputDecoration(labelText: 'F. Tindak lanjut besok (auto, bisa edit)'), maxLines: 2, onChanged: (_) => setState(() {})),
              TextField(controller: hotlineCtrl, decoration: const InputDecoration(labelText: 'Hotline Order (manual)'), onChanged: (_) => setState(() {})),
              TextField(controller: ringkasanCtrl, decoration: const InputDecoration(labelText: 'RINGKASAN (auto, bisa edit)'), maxLines: 2, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              const Text('Penerima', style: TextStyle(fontWeight: FontWeight.bold)),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.watchRecipients(),
                builder: (c, s) {
                  if (!s.hasData) return const LinearProgressIndicator();
                  if (pilihPenerima.isEmpty) { for (final r in s.data!) { pilihPenerima.add(r['id']); } }
                  return Column(children: s.data!.map((r) => CheckboxListTile(
                    value: pilihPenerima.contains(r['id']),
                    onChanged: (v) => setState(() => v! ? pilihPenerima.add(r['id']) : pilihPenerima.remove(r['id'])),
                    title: Text('${r['nama']} • ${r['role']}', style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${r['wa']}', style: const TextStyle(fontSize: 11)),
                  )).toList());
                },
              ),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                icon: const Icon(Icons.send), label: const Text('Arsip + Kirim WA'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                onPressed: _kirim)),
            ]),
    );
  }
}
