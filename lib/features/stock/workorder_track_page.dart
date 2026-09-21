import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/session.dart';
import 'selesaikan_sheet.dart';
import 'stock_repository.dart';

// Tracking motor konsumen untuk frontdesk (mobile + desktop).
// Cari nopol -> riwayat WO + part yang pernah dipakai.
// Bisa update status WO + tulis catatan/saran servis berikutnya.
class WorkOrderTrackPage extends StatefulWidget {
  const WorkOrderTrackPage({super.key});
  @override
  State<WorkOrderTrackPage> createState() => _WorkOrderTrackPageState();
}

class _WorkOrderTrackPageState extends State<WorkOrderTrackPage> {
  final repo = StockRepository();
  final cariCtrl = TextEditingController();
  List<Map<String, dynamic>> riwayat = [];
  Map<String, dynamic>? pilih;
  List<Map<String, dynamic>> mutasi = [];
  bool loading = false;

  final catatanCtrl = TextEditingController();
  final saranCtrl = TextEditingController();
  final nextKmCtrl = TextEditingController();
  String statusEdit = 'OPEN';

  Future<void> _cari() async {
    if (cariCtrl.text.trim().isEmpty) return;
    setState(() => loading = true);
    riwayat = await repo.fetchWOByNopol(cariCtrl.text);
    pilih = null;
    setState(() => loading = false);
  }

  Future<void> _buka(Map<String, dynamic> wo) async {
    setState(() => pilih = wo);
    mutasi = await repo.fetchMovementsByWO('${wo['id']}');
    catatanCtrl.text = '${wo['catatan'] ?? ''}';
    saranCtrl.text = '${wo['saranNext'] ?? ''}';
    nextKmCtrl.text = '${wo['nextKm'] ?? ''}';
    statusEdit = '${wo['status'] ?? 'OPEN'}';
    setState(() {});
  }

  Future<void> _simpan() async {
    if (pilih == null) return;
    await repo.updateWO('${pilih!['id']}', {
      'status': statusEdit,
      'catatan': catatanCtrl.text.trim(),
      'saranNext': saranCtrl.text.trim(),
      'nextKm': nextKmCtrl.text.trim(),
    });
    setState(() => pilih = {...pilih!, 'status': statusEdit});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WO terupdate')));
  }

  // Tombol 1-tap Selesai / Batal sesuai aturan (10 menit / supervisor).
  Widget _tombolSelesai() {
    final selesai = '${pilih!['status']}'.toUpperCase() == 'SELESAI';
    final supervisor = AuthSession.instance.isOps || AuthSession.instance.isKepalaMekanik;
    if (!selesai) {
      return SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle, size: 24),
          label: const Text('TAP SELESAI', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () => openKonfirmasiSelesai(
            context,
            woId: '${pilih!['id']}',
            judul: '${pilih!['nopol']} • ${pilih!['motor'] ?? pilih!['model'] ?? ''}',
            subJudul: '${pilih!['kategori'] ?? ''} • ${_tgl(pilih!['createdAt'])}',
            onBerhasil: () async {
              final fresh = await repo.fetchWOByNopol('${pilih!['nopol']}');
              final upd = fresh.where((w) => '${w['id']}' == '${pilih!['id']}');
              if (mounted) setState(() => pilih = upd.isNotEmpty ? upd.first : {...pilih!, 'status': 'SELESAI'});
            },
          ),
        ),
      );
    }
    final oleh = (pilih!['selesaiOleh'] ?? {}) as Map;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text('✅ Selesai oleh ${oleh['email'] ?? '-'}',
          style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        icon: const Icon(Icons.undo, size: 18),
        label: Text(supervisor ? 'Batalkan (supervisor)' : 'Batalkan (maks 10 mnt)'),
        onPressed: () async {
          final hasil = await repo.batalkanSelesai('${pilih!['id']}', supervisor: supervisor);
          if (!mounted) return;
          if (hasil == 'ditolak') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lewat 10 menit — hanya Kepala Mekanik/Ops yang bisa batalkan')));
          } else if (hasil == 'ok') {
            setState(() => pilih = {...pilih!, 'status': 'PROSES'});
          }
        },
      ),
    ]);
  }

  String _tgl(dynamic ts) {
    if (ts == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy').format((ts as dynamic).toDate());
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Tracking Servis'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: LayoutBuilder(builder: (c, box) {
        final lebar = box.maxWidth > 900;
        final listPane = Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: TextField(controller: cariCtrl, decoration: const InputDecoration(labelText: 'Nopol (mis. B 1234 ABC)', border: OutlineInputBorder()),
              onSubmitted: (_) => _cari(), textCapitalization: TextCapitalization.characters)),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: loading ? null : _cari, child: const Text('Cari')),
          ])),
          if (loading) const LinearProgressIndicator(),
          Expanded(child: riwayat.isEmpty
              ? const Center(child: Text('Cari nopol untuk lihat riwayat servis + part'))
              : ListView.builder(itemCount: riwayat.length, itemBuilder: (_, i) {
                  final w = riwayat[i];
                  final sel = pilih != null && pilih!['id'] == w['id'];
                  return Card(color: sel ? Colors.blue.shade50 : null, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text('${w['nopol']} • ${w['motor'] ?? w['model'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${_tgl(w['createdAt'])} • ${w['kategori'] ?? ''} • ${w['status']} • Labour Rp ${w['labourTotal'] ?? 0}',
                        style: const TextStyle(fontSize: 11)),
                      trailing: (w['saranNext'] ?? '').toString().isNotEmpty
                          ? const Icon(Icons.event_note, size: 18, color: Colors.orange)
                          : null,
                      onTap: () => _buka(w),
                    ));
                })),
        ]);
        final detailPane = pilih == null
            ? const Center(child: Text('Pilih WO untuk lihat part + update + saran next service'))
            : ListView(padding: const EdgeInsets.all(12), children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: repo.streamWODoc('${pilih!['id']}'),
                  builder: (c, s) {
                    final pending = s.data?.metadata.hasPendingWrites ?? false;
                    if (!pending) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                      child: const Text('⏳ Belum sinkron — tersimpan di HP, terkirim otomatis saat online',
                        style: TextStyle(fontSize: 11)),
                    );
                  },
                ),
                Text('${pilih!['nopol']} • ${pilih!['motor'] ?? pilih!['model'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Keluhan: ${pilih!['keluhan'] ?? '-'} • ${_tgl(pilih!['createdAt'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                _tombolSelesai(),
                const SizedBox(height: 8),
                const Text('Part yang pernah dipakai', style: TextStyle(fontWeight: FontWeight.bold)),
                ...((pilih!['parts'] ?? []) as List).map((p) => ListTile(dense: true,
                  title: Text('${p['kode']} • ${p['nama']}', style: const TextStyle(fontSize: 12)),
                  trailing: Text('x${p['qty'] ?? 1} • Rp ${p['jual'] ?? ''}', style: const TextStyle(fontSize: 12)))),
                if (mutasi.isNotEmpty) ...[
                  const Text('Mutasi gudang terkait', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ...mutasi.map((m) => ListTile(dense: true,
                    title: Text('${m['tipe']} ${m['kode_part']} x${m['qty']}', style: const TextStyle(fontSize: 12)),
                    subtitle: Text('${m['catatan'] ?? ''}', style: const TextStyle(fontSize: 11)))),
                ],
                const SizedBox(height: 8),
                const Text('Update + saran next service', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(value: ['OPEN', 'PROSES', 'SELESAI', 'BATAL'].contains(statusEdit) ? statusEdit : 'OPEN',
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const ['OPEN', 'PROSES', 'SELESAI', 'BATAL'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => statusEdit = v!)),
                const SizedBox(height: 8),
                TextField(controller: catatanCtrl, decoration: const InputDecoration(labelText: 'Catatan servis', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 8),
                TextField(controller: saranCtrl, decoration: const InputDecoration(labelText: 'Saran untuk servis berikutnya', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 8),
                TextField(controller: nextKmCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target KM servis berikutnya', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpan, child: const Text('Simpan update'))),
              ]);
        if (!lebar) {
          // Mobile: list dulu, detail sebagai halaman terpisah via dialog navigasi
          return pilih == null ? listPane : Column(children: [
            Align(alignment: Alignment.centerLeft,
              child: TextButton.icon(icon: const Icon(Icons.arrow_back), label: const Text('Kembali'), onPressed: () => setState(() => pilih = null))),
            Expanded(child: detailPane),
          ]);
        }
        return Row(children: [
          SizedBox(width: 380, child: listPane),
          const VerticalDivider(width: 1),
          Expanded(child: detailPane),
        ]);
      }),
    );
  }
}
