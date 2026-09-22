import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/session.dart';
import 'motor_class.dart';
import 'stock_repository.dart';
// Catatan: Timestamp dipakai untuk tglSiap/tglKirim.
// Halaman ini KHUSUS Web (admin_sales bekerja dari desktop).

// Booking PDI oleh Admin Sales: tipe motor, warna, tanggal dipersiapkan,
// tanggal + jam pengiriman. Masuk sebagai WO kategori PDI status OPEN.
class PdiBookingPage extends StatefulWidget {
  const PdiBookingPage({super.key});
  @override
  State<PdiBookingPage> createState() => _PdiBookingPageState();
}

class _PdiBookingPageState extends State<PdiBookingPage> {
  final repo = StockRepository();
  String model = 'FORT 250';
  final warnaCtrl = TextEditingController();
  final customerCtrl = TextEditingController();
  final rangkaCtrl = TextEditingController();
  DateTime? tglSiap;
  DateTime? tglKirim;
  TimeOfDay? jamKirim;
  String? mekanikUid; // opsional: request ke mekanik tertentu (kosong = antre umum)
  bool loading = false;

  String _tgl(DateTime? d) => d == null ? 'Pilih tanggal' : DateFormat('dd/MM/yyyy').format(d);
  String _jam(TimeOfDay? t) => t == null ? 'Pilih jam' : t.format(context);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking PDI')),
        body: const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Booking PDI hanya lewat Web (desktop).\nBuka aplikasi web di laptop/PC.',
            textAlign: TextAlign.center),
        )),
      );
    }
    if (!AuthSession.instance.canBookPDI) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking PDI')),
        body: const Center(child: Text('Halaman ini khusus Admin Sales / Frontdesk / Ops.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('QJ Motor - Booking PDI'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(value: model,
          decoration: const InputDecoration(labelText: 'Tipe motor', border: OutlineInputBorder()),
          items: motorMaster.map((m) => DropdownMenuItem(value: m.model, child: Text('${m.model} (${m.kelas})'))).toList(),
          onChanged: (v) => setState(() => model = v!)),
        const SizedBox(height: 10),
        TextField(controller: warnaCtrl, decoration: const InputDecoration(labelText: 'Warna', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: customerCtrl, decoration: const InputDecoration(labelText: 'Nama customer (opsional)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: rangkaCtrl, decoration: const InputDecoration(labelText: 'No. rangka (opsional)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        ListTile(title: const Text('Tanggal dipersiapkan'), trailing: Text(_tgl(tglSiap)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 90)));
            if (d != null) setState(() => tglSiap = d);
          }),
        ListTile(title: const Text('Tanggal pengiriman'), trailing: Text(_tgl(tglKirim)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
            if (d != null) setState(() => tglKirim = d);
          }),
        ListTile(title: const Text('Jam pengiriman'), trailing: Text(_jam(jamKirim)),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (t != null) setState(() => jamKirim = t);
          }),
        const SizedBox(height: 10),
        // Request ke mekanik tertentu (opsional — kosong = antre umum diambil siapa saja)
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.watchTeam(),
          builder: (c, s) {
            final meks = (s.data ?? []).where((t) =>
              t['role'] == 'mekanik' || t['role'] == 'kepala_mekanik').toList();
            if (meks.isNotEmpty && mekanikUid != null &&
                !meks.any((m) => m['uid'] == mekanikUid)) {
              mekanikUid = null;
            }
            return DropdownButtonFormField<String>(
              value: mekanikUid,
              decoration: const InputDecoration(
                labelText: 'Mekanik pelaksana (opsional)',
                helperText: 'Kosong = antre umum, diambil mekanik yang siap',
                border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Antre umum —')),
                ...meks.map((m) => DropdownMenuItem(
                  value: m['uid'] as String,
                  child: Text('${m['nama']} (${m['role'] == 'kepala_mekanik' ? 'Kepala' : 'Mekanik'})'))),
              ],
              onChanged: (v) => setState(() => mekanikUid = v),
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(height: 52, width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : _simpanReal,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(loading ? 'Menyimpan...' : 'SIMPAN BOOKING PDI'))),
        const SizedBox(height: 12),
        const Text('Monitoring pergerakan PDI', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.fetchPDIBookings(),
          builder: (c, s) {
            if (!s.hasData) return const LinearProgressIndicator();
            final antre = s.data!.where((w) => '${w['status']}'.toUpperCase() != 'SELESAI').toList();
            final selesai = s.data!.where((w) => '${w['status']}'.toUpperCase() == 'SELESAI').toList();
            return DefaultTabController(
              length: 2,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TabBar(labelColor: const Color(0xFF1B2A4A), tabs: [
                  Tab(text: 'Antrian (${antre.length})'),
                  Tab(text: 'Selesai (${selesai.length})'),
                ]),
                SizedBox(
                  height: 320,
                  child: TabBarView(children: [
                    _daftarPDI(antre, 'Belum ada antrean PDI'),
                    _daftarPDI(selesai, 'Belum ada PDI selesai'),
                  ]),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _daftarPDI(List<Map<String, dynamic>> list, String kosong) {
    if (list.isEmpty) return Center(child: Text(kosong, style: const TextStyle(fontSize: 12, color: Colors.grey)));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final w = list[i];
        final mek = '${w['mekanik'] ?? ''}';
        return Card(
          child: ListTile(
            onTap: () => _kelolaPDI(w),
            title: Text('${w['motor'] ?? w['model'] ?? ''} • ${w['warna'] ?? '-'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${w['customer'] ?? ''} • Siap: ${_str(w['tglSiap'])}\nKirim: ${_str(w['tglKirim'])} ${_jamStr(w)} • ${w['status']} • ${_sisa(w)}\nMekanik: ${mek.isEmpty ? '— antre umum —' : mek}',
              style: const TextStyle(fontSize: 11)),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right, size: 18),
          ));
      });
  }

  // Kelola satu PDI: ganti mekanik + majukan status (OPEN->PROSES->SELESAI).
  Future<void> _kelolaPDI(Map<String, dynamic> w) async {
    final s = AuthSession.instance;
    final bolehAtur = s.isOps || s.isFrontdesk || s.isAdminSales;
    final bolehKerjakan = bolehAtur || s.isKepalaMekanik ||
        (s.role == 'mekanik' && (w['mekanikUid'] == s.uid || '${w['mekanikUid'] ?? ''}'.isEmpty));
    if (!bolehAtur && !bolehKerjakan) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya Sales/Frontdesk/Ops/mekanik terkait yang bisa kelola.')));
      return;
    }
    String? mekUid = '${w['mekanikUid'] ?? ''}'.isEmpty ? null : '${w['mekanikUid']}';
    final aksi = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text('${w['motor'] ?? ''} • ${w['warna'] ?? ''}', style: const TextStyle(fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: ${w['status']} • ${_sisa(w)}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          if (bolehAtur) StreamBuilder<List<Map<String, dynamic>>>(
            stream: repo.watchTeam(),
            builder: (c2, s2) {
              final meks = (s2.data ?? []).where((t) =>
                t['role'] == 'mekanik' || t['role'] == 'kepala_mekanik').toList();
              return DropdownButtonFormField<String>(
                value: mekUid,
                decoration: const InputDecoration(
                  labelText: 'Mekanik pelaksana', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Antre umum —')),
                  ...meks.map((m) => DropdownMenuItem(
                    value: m['uid'] as String, child: Text('${m['nama']}', style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) => setD(() => mekUid = v),
              );
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          if (bolehKerjakan && '${w['status']}'.toUpperCase() == 'OPEN')
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 'proses'),
              child: const Text('Mulai (PROSES)')),
          if (bolehKerjakan && '${w['status']}'.toUpperCase() != 'SELESAI')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, 'selesai'),
              child: const Text('Selesaikan')),
          if (bolehAtur)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, 'simpan'),
              child: const Text('Simpan mekanik')),
        ],
      )));
    if (aksi == null || !mounted) return;
    try {
      if (aksi == 'simpan') {
        String mekNama = '';
        if (mekUid != null) {
          final team = await repo.watchTeam().first;
          mekNama = '${team.firstWhere((t) => t['uid'] == mekUid, orElse: () => {})['nama'] ?? ''}';
        }
        await repo.updateWO(w['id'] as String, {'mekanik': mekNama, 'mekanikUid': mekUid ?? ''});
      } else if (aksi == 'proses') {
        await repo.updateWO(w['id'] as String, {'status': 'PROSES'});
      } else if (aksi == 'selesai') {
        await repo.selesaikanWO(w['id'] as String);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDI diperbarui')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // Hitung mundur ke tanggal pengiriman
  String _sisa(Map<String, dynamic> w) {
    try {
      final t = (w['tglKirim'] as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      final h = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (h < 0) return 'terlewat ${-h} hari';
      if (h == 0) return 'kirim HARI INI';
      return 'sisa $h hari';
    } catch (_) {
      return '';
    }
  }

  String _str(dynamic ts) {
    try {
      return DateFormat('dd/MM').format((ts as dynamic).toDate());
    } catch (_) {
      return '-';
    }
  }

  String _jamStr(Map<String, dynamic> w) {
    final j = w['jamKirim'];
    if (j is Map) return '${j['jam'] ?? ''}:${(j['menit'] ?? '').toString().padLeft(2, '0')}';
    return '';
  }

  Future<void> _simpanReal() async {
    if (tglSiap == null || tglKirim == null || jamKirim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal disiapkan, tanggal & jam kirim wajib diisi')));
      return;
    }
    setState(() => loading = true);
    String mekNama = '';
    if (mekanikUid != null) {
      try {
        final team = await repo.watchTeam().first;
        final m = team.firstWhere((t) => t['uid'] == mekanikUid, orElse: () => {});
        mekNama = '${m['nama'] ?? ''}';
      } catch (_) {}
    }
    await repo.createWO(
      nopol: rangkaCtrl.text.trim().isEmpty ? 'PDI' : rangkaCtrl.text.trim(),
      motor: model,
      keluhan: 'Booking PDI — ${customerCtrl.text.trim()}',
      mekanik: mekNama,
      model: model,
      tipe: 'SERVICE',
      kategori: 'PDI',
      extra: {
        'warna': warnaCtrl.text.trim(),
        'customer': customerCtrl.text.trim(),
        'tglSiap': Timestamp.fromDate(tglSiap!),
        'tglKirim': Timestamp.fromDate(tglKirim!),
        'jamKirim': {'jam': jamKirim!.hour, 'menit': jamKirim!.minute},
        'dibookingOleh': AuthSession.instance.email,
        'mekanikUid': mekanikUid ?? '',
      },
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      mekanikUid = null;
      warnaCtrl.clear();
      customerCtrl.clear();
      rangkaCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Booking PDI tersimpan')));
    setState(() {});
  }
}
