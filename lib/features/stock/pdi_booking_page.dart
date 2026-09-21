import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/session.dart';
import 'motor_class.dart';
import 'stock_repository.dart';
// Catatan: Timestamp dipakai untuk tglSiap/tglKirim.

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
  bool loading = false;

  String _tgl(DateTime? d) => d == null ? 'Pilih tanggal' : DateFormat('dd/MM/yyyy').format(d);
  String _jam(TimeOfDay? t) => t == null ? 'Pilih jam' : t.format(context);

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 12),
        SizedBox(height: 52, width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : _simpanReal,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(loading ? 'Menyimpan...' : 'SIMPAN BOOKING PDI'))),
        const SizedBox(height: 12),
        const Text('Booking masuk hari ini', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookingHariIni(),
          builder: (c, s) {
            if (!s.hasData) return const LinearProgressIndicator();
            if (s.data!.isEmpty) return const Text('Belum ada booking hari ini', style: TextStyle(fontSize: 12, color: Colors.grey));
            return Column(children: s.data!.map((w) => Card(
              child: ListTile(
                title: Text('${w['motor'] ?? w['model'] ?? ''} • ${w['warna'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Siap: ${_str(w['tglSiap'])} • Kirim: ${_str(w['tglKirim'])} ${_jamStr(w)} • ${w['status']}',
                  style: const TextStyle(fontSize: 11)),
              ))).toList());
          },
        ),
      ]),
    );
  }

  Future<List<Map<String, dynamic>>> _bookingHariIni() async {
    final now = DateTime.now();
    final list = await repo.fetchWOSince(DateTime(now.year, now.month, now.day));
    return list.where((w) => '${w['kategori']}' == 'PDI').toList();
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
    await repo.createWO(
      nopol: rangkaCtrl.text.trim().isEmpty ? 'PDI' : rangkaCtrl.text.trim(),
      motor: model,
      keluhan: 'Booking PDI — ${customerCtrl.text.trim()}',
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
      },
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      warnaCtrl.clear();
      customerCtrl.clear();
      rangkaCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Booking PDI tersimpan')));
    setState(() {});
  }
}
