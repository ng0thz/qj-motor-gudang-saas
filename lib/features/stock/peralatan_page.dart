import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/session.dart';
import 'peralatan_repository.dart';

// Pendataan peralatan bengkel: daftar + kondisi + cek fisik opname + PDF.
// Kelola (tambah/edit/kondisi): staff gudang / kepala mekanik / ops.
// Hapus: ops saja. Lihat: semua role penghitung.
class PeralatanPage extends StatefulWidget {
  const PeralatanPage({super.key});
  @override
  State<PeralatanPage> createState() => _PeralatanPageState();
}

class _PeralatanPageState extends State<PeralatanPage> {
  final repo = PeralatanRepository();
  final cariCtrl = TextEditingController();
  String cari = '';
  String? lokasiFilter;
  String? kondisiFilter;
  bool belumVerif = false;
  bool exporting = false;

  @override
  void dispose() {
    cariCtrl.dispose();
    super.dispose();
  }

  bool get _bolehKelola {
    final s = AuthSession.instance;
    return s.isStaff || s.isKepalaMekanik;
  }

  Color _kondisiColor(String k) {
    switch (k.toUpperCase()) {
      case 'BAIK':
        return Colors.green;
      case 'RUSAK':
        return Colors.orange;
      case 'HILANG':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _tgl(dynamic ts) {
    try {
      // ignore: avoid_dynamic_calls
      return DateFormat('dd/MM/yy').format((ts as dynamic).toDate());
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AuthSession.instance;
    if (!s.canPeralatan) {
      return Scaffold(
        appBar: AppBar(title: const Text('Peralatan Bengkel')),
        body: const Center(child: Text('Tidak ada akses.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('QJ Motor - Peralatan'),
        backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Export PDF', icon: exporting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.picture_as_pdf),
            onPressed: exporting ? null : _exportPdf),
        ],
      ),
      floatingActionButton: _bolehKelola
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
              onPressed: () => _formTambah(),
              icon: const Icon(Icons.add), label: const Text('Tambah Alat'))
          : null,
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: TextField(
          controller: cariCtrl,
          decoration: const InputDecoration(labelText: 'Cari kode / nama',
            prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => cari = v.trim().toUpperCase()),
        )),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _chipFilter('Semua lokasi', lokasiFilter == null, () => setState(() => lokasiFilter = null)),
            ...Peralatan.lokasiList.map((l) =>
              _chipFilter(l, lokasiFilter == l, () => setState(() => lokasiFilter = lokasiFilter == l ? null : l))),
            const SizedBox(width: 6),
            _chipFilter('Belum verif', belumVerif, () => setState(() => belumVerif = !belumVerif),
              color: Colors.deepOrange),
          ])),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _chipFilter('Semua kondisi', kondisiFilter == null, () => setState(() => kondisiFilter = null)),
            ...Peralatan.kondisiList.map((k) =>
              _chipFilter(k, kondisiFilter == k, () => setState(() => kondisiFilter = kondisiFilter == k ? null : k),
                color: _kondisiColor(k))),
          ])),
        const SizedBox(height: 4),
        Expanded(child: StreamBuilder<List<Peralatan>>(
          stream: repo.watchAll(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var list = snap.data!;
            if (lokasiFilter != null) list = list.where((p) => p.lokasi == lokasiFilter).toList();
            if (kondisiFilter != null) list = list.where((p) => p.kondisi == kondisiFilter).toList();
            if (belumVerif) list = list.where((p) => p.verifiedAt == null).toList();
            if (cari.isNotEmpty) {
              list = list.where((p) =>
                p.kode.contains(cari) || p.nama.toUpperCase().contains(cari)).toList();
            }
            if (list.isEmpty) {
              return const Center(child: Text('Tidak ada peralatan.\nTambahkan via tombol di bawah.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
            }
            final baik = list.where((p) => p.kondisi == 'BAIK').length;
            final rusak = list.where((p) => p.kondisi == 'RUSAK').length;
            final hilang = list.where((p) => p.kondisi == 'HILANG').length;
            return Column(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('Total ${list.length} • Baik $baik • Rusak $rusak • Hilang $hilang',
                  style: const TextStyle(fontSize: 11, color: Colors.grey))),
              Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
                final p = list[i];
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: _kondisiColor(p.kondisi),
                    child: Text(p.kode.isEmpty ? '?' : p.kode[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  title: Text('${p.kode} • ${p.nama}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.lokasi}${p.penanggungJawab.isNotEmpty ? ' • ${p.penanggungJawab}' : ''} • x${p.jumlah}\n'
                    '${p.verifiedAt == null ? 'Belum diverifikasi' : 'Verif ${_tgl(p.verifiedAt)} oleh ${p.verifiedBy.split('@').first}'}'
                    '${p.catatan.isNotEmpty ? '\n${p.catatan}' : ''}',
                    style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                  trailing: Chip(label: Text(p.kondisi, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: _kondisiColor(p.kondisi), visualDensity: VisualDensity.compact),
                  onTap: () => _kelola(p),
                ));
              })),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _chipFilter(String label, bool aktif, VoidCallback onTap, {Color? color}) {
    final c = color ?? const Color(0xFF1B2A4A);
    return Padding(padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
      child: ChoiceChip(label: Text(label, style: TextStyle(fontSize: 11,
        color: aktif ? Colors.white : c)),
        selected: aktif, selectedColor: c,
        onSelected: (_) => onTap()));
  }

  Future<void> _formTambah({Peralatan? edit}) async {
    final kodeCtrl = TextEditingController(text: edit?.kode ?? '');
    final namaCtrl = TextEditingController(text: edit?.nama ?? '');
    final pjCtrl = TextEditingController(text: edit?.penanggungJawab ?? '');
    final catCtrl = TextEditingController(text: edit?.catatan ?? '');
    final jumCtrl = TextEditingController(text: '${edit?.jumlah ?? 1}');
    String lokasi = edit?.lokasi ?? Peralatan.lokasiList.first;
    String kondisi = edit?.kondisi ?? 'BAIK';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(edit == null ? 'Tambah Peralatan' : 'Edit ${edit.kode}',
          style: const TextStyle(fontSize: 14)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (edit == null) TextField(controller: kodeCtrl, textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Kode unik * (mis. PK-001)',
              border: OutlineInputBorder(), isDense: true)),
          if (edit == null) const SizedBox(height: 8),
          TextField(controller: namaCtrl, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama alat *',
              border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: lokasi,
            decoration: const InputDecoration(labelText: 'Lokasi', border: OutlineInputBorder(), isDense: true),
            items: Peralatan.lokasiList.map((l) =>
              DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setD(() => lokasi = v ?? lokasi)),
          const SizedBox(height: 8),
          TextField(controller: pjCtrl,
            decoration: const InputDecoration(labelText: 'Penanggung jawab',
              border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: kondisi,
              decoration: const InputDecoration(labelText: 'Kondisi', border: OutlineInputBorder(), isDense: true),
              items: Peralatan.kondisiList.map((k) =>
                DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setD(() => kondisi = v ?? kondisi))),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: TextField(controller: jumCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Jml', border: OutlineInputBorder(), isDense: true))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: catCtrl,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(), isDense: true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      )));
    if (ok != true || !mounted) return;
    try {
      await repo.save(
        kode: edit?.kode ?? kodeCtrl.text,
        nama: namaCtrl.text,
        lokasi: lokasi,
        penanggungJawab: pjCtrl.text,
        kondisi: kondisi,
        jumlah: int.tryParse(jumCtrl.text) ?? 1,
        catatan: catCtrl.text,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peralatan tersimpan')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _kelola(Peralatan p) async {
    final s = AuthSession.instance;
    String kondisi = p.kondisi;
    final aksi = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text('${p.kode} • ${p.nama}', style: const TextStyle(fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.lokasi} • x${p.jumlah}${p.penanggungJawab.isNotEmpty ? ' • ${p.penanggungJawab}' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          if (_bolehKelola) DropdownButtonFormField<String>(value: kondisi,
            decoration: const InputDecoration(labelText: 'Kondisi fisik', border: OutlineInputBorder(), isDense: true),
            items: Peralatan.kondisiList.map((k) =>
              DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setD(() => kondisi = v ?? kondisi)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          if (_bolehKelola) ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('Edit Data')),
          if (_bolehKelola) ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, 'verif:$kondisi'),
            child: const Text('Cek Fisik OK')),
          if (s.isOps) TextButton(
            onPressed: () => Navigator.pop(ctx, 'hapus'),
            child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      )));
    if (aksi == null || !mounted) return;
    try {
      if (aksi == 'edit') {
        await _formTambah(edit: p);
      } else if (aksi.startsWith('verif:')) {
        await repo.verifikasiFisik(p.kode, aksi.split(':')[1]);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.kode} terverifikasi: ${aksi.split(':')[1]}')));
      } else if (aksi == 'hapus') {
        final ya = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          title: const Text('Hapus peralatan?', style: TextStyle(fontSize: 14)),
          content: Text('${p.kode} • ${p.nama} akan dihapus permanen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.white))),
          ],
        ));
        if (ya == true && mounted) {
          await repo.hapus(p.kode);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Peralatan dihapus')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _exportPdf() async {
    setState(() => exporting = true);
    try {
      final list = await repo.fetchAll();
      final doc = pw.Document();
      final baik = list.where((p) => p.kondisi == 'BAIK').length;
      final rusak = list.where((p) => p.kondisi == 'RUSAK').length;
      final hilang = list.where((p) => p.kondisi == 'HILANG').length;
      final sudahVerif = list.where((p) => p.verifiedAt != null).length;
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
        build: (_) => [
          pw.Text('QJ MOTOR - DAFTAR PERALATAN BENGKEL',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Dicetak ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} '
            '\u2022 Total ${list.length} (Baik $baik, Rusak $rusak, Hilang $hilang) '
            '\u2022 Terverifikasi $sudahVerif',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: {
              0: const pw.FixedColumnWidth(52),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FixedColumnWidth(44),
              4: const pw.FixedColumnWidth(52),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ['Kode', 'Nama', 'Lokasi', 'Kondisi', 'Verifikasi']
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList()),
              ...list.map((p) => pw.TableRow(children: [
                _pdfCell(p.kode),
                _pdfCell('${p.nama}${p.penanggungJawab.isNotEmpty ? ' (${p.penanggungJawab})' : ''}'),
                _pdfCell(p.lokasi),
                _pdfCell(p.kondisi),
                _pdfCell(p.verifiedAt == null ? '-' : _tgl(p.verifiedAt)),
              ])),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            pw.Column(children: [
              pw.Text('Diperiksa,', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 36),
              pw.Text('( Kepala Mekanik )', style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.Column(children: [
              pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 36),
              pw.Text('( Ops Manager )', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
        ],
      ));
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'peralatan_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  pw.Widget _pdfCell(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
}
