import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/qj_theme.dart';
import 'stock_repository.dart';

// Report Opname: Riwayat -> Detail -> PDF/Excel/Print A4 landscape fit columns.
class OpnameReportPage extends StatelessWidget {
  const OpnameReportPage({super.key});

  String _tgl(dynamic ts) {
    try { return DateFormat('dd/MM/yyyy HH:mm').format((ts as Timestamp).toDate()); }
    catch (_) { return '-'; }
  }

  String _tglShort(dynamic ts) {
    try { return DateFormat('dd/MM yy').format((ts as Timestamp).toDate()); }
    catch (_) { return '-'; }
  }

  @override
  Widget build(BuildContext context) {
    final repo = StockRepository();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Opname'),
        backgroundColor: QjColors.navy, foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.watchOpnameHistory(limit: 50),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada sesi opname.',
              style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final o = list[i];
              final st = '${o['status'] ?? '-'}';
              final zona = (o['scopeZona'] as List?)?.join(',') ?? '-';
              final col = st == 'APPROVED' ? Colors.green
                  : st == 'REJECTED' ? Colors.red
                  : st == 'COUNTING' ? Colors.orange : Colors.grey;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: col.withOpacity(0.15),
                    child: Icon(Icons.assignment, color: col, size: 20)),
                  title: Text('Zona $zona \u2022 $st',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  subtitle: Text(
                    '${o['catatan'] ?? ''}\n${_tgl(o['createdAt'])} \u2022 ${_tgl(o['approvedAt'])}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => OpnameDetailPage(opnameId: o['id'] as String))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Halaman detail satu sesi: tabel variance + ringkasan + aksi ekspor.
class OpnameDetailPage extends StatefulWidget {
  final String opnameId;
  const OpnameDetailPage({super.key, required this.opnameId});
  @override
  State<OpnameDetailPage> createState() => _OpnameDetailPageState();
}

class _OpnameDetailPageState extends State<OpnameDetailPage> {
  final repo = StockRepository();
  Map<String, dynamic>? header;
  List<Map<String, dynamic>> items = [];
  String? _filter; // null=semua, COCOK, LEBIH, KURANG, BELUM
  bool _loading = true;

  // Enrich nama & harga jual (opsional, fallback '-').
  final Map<String, Map<String, dynamic>> _partInfo = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      header = await repo.fetchOpname(widget.opnameId);
      items = await repo.fetchOpnameItems(widget.opnameId);
      // Enrich info part (nama, alamat, jual) — batched 10 per chunk.
      final all = await repo.fetchAll3000();
      for (final p in all) {
        _partInfo[p.kode] = {'nama': p.nama, 'alamat': p.alamat, 'jual': p.harga.jual};
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == null) return items;
    if (_filter == 'BELUM') {
      // Tidak ada di items = belum dihitung; tapi kita hanya bisa filter yang ada.
      return items;
    }
    return items.where((m) => '${m['status']}' == _filter).toList();
  }

  String _fmt(dynamic ts) {
    try { return DateFormat('HH:mm dd/MM').format((ts as Timestamp).toDate()); }
    catch (_) { return '-'; }
  }

  String _tglHeader(dynamic ts) {
    try { return DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format((ts as Timestamp).toDate()); }
    catch (_) { return '-'; }
  }

  // PDF builder A4 landscape, fit columns.
  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final hdr = header;
    final list = _filtered;
    final tgl = _tglHeader(hdr?['createdAt']);
    final zona = (hdr?['scopeZona'] as List?)?.join(', ') ?? '-';
    final status = '${hdr?['status'] ?? '-'}';

    final cocok = items.where((m) => m['status'] == 'COCOK').length;
    final lebih = items.where((m) => m['status'] == 'LEBIH').length;
    final kurang = items.where((m) => m['status'] == 'KURANG').length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
      header: (c) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('QJ Motor Adidaya \u2022 Report Opname',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text('Hal ${c.pageNumber} / ${c.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(height: 1, color: PdfColors.grey300),
      ]),
      footer: (c) => pw.Column(children: [
        pw.Divider(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Halaman ${c.pageNumber}',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ]),
      ]),
      build: (_) => [
        pw.Text('REPORT OPNAME', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Sesi ${widget.opnameId} \u2022 Zona $zona \u2022 Status $status',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text('Dibuat $tgl \u2022 ${hdr?['catatan'] ?? ''}',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _pdfChip('Total', '${items.length}', PdfColors.grey800),
          pw.SizedBox(width: 6),
          _pdfChip('Cocok', '$cocok', PdfColors.green700),
          pw.SizedBox(width: 6),
          _pdfChip('Lebih', '$lebih', PdfColors.orange700),
          pw.SizedBox(width: 6),
          _pdfChip('Kurang', '$kurang', PdfColors.red700),
        ]),
        pw.SizedBox(height: 10),
        // Tabel fit columns.
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
          columnWidths: {
            0: const pw.FixedColumnWidth(22),   // No
            1: const pw.FixedColumnWidth(72),   // Kode
            2: const pw.FlexColumnWidth(2.2),   // Nama
            3: const pw.FixedColumnWidth(52),   // Alamat
            4: const pw.FixedColumnWidth(32),   // Sistem
            5: const pw.FixedColumnWidth(32),   // Fisik
            6: const pw.FixedColumnWidth(36),   // Selisih
            7: const pw.FixedColumnWidth(44),   // Status
            8: const pw.FlexColumnWidth(1.4),   // Penghitung
            9: const pw.FixedColumnWidth(56),   // Jam
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                for (final h in ['No','Kode','Nama','Alamat','Sist','Fisik','Selisih','Status','Penghitung','Jam'])
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      textAlign: h == 'Nama' || h == 'Penghitung' ? pw.TextAlign.left : pw.TextAlign.center)),
              ],
            ),
            for (var idx = 0; idx < list.length; idx++)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                decoration: pw.BoxDecoration(
                  color: idx.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC)),
                children: _pdfRow(idx, list[idx]),
              ),
            if (list.isEmpty)
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Tidak ada data untuk filter ini.',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                for (var k = 1; k < 10; k++) pw.SizedBox(),
              ]),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _pdfTtd('Dihitung oleh', ''),
          _pdfTtd('Diperiksa', ''),
          _pdfTtd('Disetujui (Ops)', '${hdr?['status'] == 'APPROVED' ? 'APPROVED' : ''}'),
        ]),
      ],
    ));
    return doc.save();
  }

  pw.Widget _pdfChip(String l, String v, PdfColor c) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF1F5F9),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      border: pw.Border.all(color: c, width: 0.8),
    ),
    child: pw.Text('$l $v', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: c)),
  );

  List<pw.Widget> _pdfRow(int idx, Map<String, dynamic> m) {
    final kode = '${m['kode'] ?? ''}';
    final info = _partInfo[kode];
    final nama = '${info?['nama'] ?? '-'}';
    final alamat = '${info?['alamat'] ?? '-'}';
    final selisih = (m['selisih'] ?? 0) as int;
    final st = '${m['status'] ?? ''}';
    final c = st == 'COCOK' ? PdfColors.green700 : st == 'LEBIH' ? PdfColors.orange700 : PdfColors.red700;
    return [
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text(kode, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text(nama, style: const pw.TextStyle(fontSize: 6.5))),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text(alamat, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center)),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text('${m['stokSistem'] ?? 0}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text('${m['stokFisik'] ?? 0}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text(selisiLabel(selisih), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: c), textAlign: pw.TextAlign.center)),
      pw.Padding(padding: const pw.EdgeInsets.all(2),
        child: pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(color: c, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
          child: pw.Text(st, style: pw.TextStyle(fontSize: 6, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center))),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text('${m['countedBy'] ?? '-'}', style: const pw.TextStyle(fontSize: 6))),
      pw.Padding(padding: const pw.EdgeInsets.all(3),
        child: pw.Text(_fmtShort(m['countedAt']), style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center)),
    ];
  }

  String selisiLabel(int v) => v == 0 ? '0' : v > 0 ? '+$v' : '$v';

  String _fmtShort(dynamic ts) {
    try { return DateFormat('HH:mm dd/MM').format((ts as Timestamp).toDate()); }
    catch (_) { return '-'; }
  }

  pw.Widget _pdfTtd(String judul, String extra) => pw.Column(children: [
    pw.Text(judul, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    pw.SizedBox(height: 36),
    pw.Container(width: 120, height: 0.8, color: PdfColors.grey400),
    pw.SizedBox(height: 4),
    pw.Text(extra, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
    pw.Text('(tanda tangan)', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
  ]);

  // Excel: header QJ red, auto-fit via lebar kolom.
  Future<Uint8List> _buildExcel() async {
    final wb = xls.Excel.createExcel();
    final sheet = wb['Opname'];
    wb.setDefaultSheet('Opname');

    // Header sheet.
    final hdr = header;
    final meta = [
      ['REPORT OPNAME'],
      ['Sesi', widget.opnameId],
      ['Zona', (hdr?['scopeZona'] as List?)?.join(', ') ?? '-'],
      ['Status', '${hdr?['status'] ?? '-'}'],
      ['Dibuat', _tglHeader(hdr?['createdAt'])],
      ['Catatan', '${hdr?['catatan'] ?? ''}'],
      ['Dicetak', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())],
      [],
    ];
    for (final r in meta) {
      sheet.appendRow(r.map((v) => xls.TextCellValue('$v')).toList());
    }
    // Judul tebal.
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
        xls.CellStyle(bold: true, fontSize: 14, fontColorHex: xls.ExcelColor.fromHexString('#D92028'));

    final cols = ['No','Kode','Nama','Alamat','Sistem','Fisik','Selisih','Status','Penghitung','Jam','Harga Jual'];
    sheet.appendRow(cols.map((c) => xls.TextCellValue(c)).toList());
    final headRow = sheet.rows.length - 1;
    for (var ci = 0; ci < cols.length; ci++) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: ci, rowIndex: headRow));
      cell.cellStyle = xls.CellStyle(
        bold: true, fontColorHex: xls.ExcelColor.white,
        backgroundColorHex: xls.ExcelColor.fromHexString('#D92028'),
        horizontalAlign: xls.HorizontalAlign.Center,
      );
    }

    final list = _filtered;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      final kode = '${m['kode']}';
      final info = _partInfo[kode];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(kode),
        xls.TextCellValue('${info?['nama'] ?? '-'}'),
        xls.TextCellValue('${info?['alamat'] ?? '-'}'),
        xls.IntCellValue((m['stokSistem'] ?? 0) as int),
        xls.IntCellValue((m['stokFisik'] ?? 0) as int),
        xls.IntCellValue((m['selisih'] ?? 0) as int),
        xls.TextCellValue('${m['status']}'),
        xls.TextCellValue('${m['countedBy'] ?? '-'}'),
        xls.TextCellValue(_fmtShort(m['countedAt'])),
        xls.IntCellValue((info?['jual'] ?? 0) as int),
      ]);
    }
    // Lebar kolom agar muat A4 landscape saat print Excel.
    const widths = [5, 15, 30, 14, 8, 8, 9, 10, 22, 14, 12];
    for (var ci = 0; ci < widths.length; ci++) {
      sheet.setColumnWidth(ci, widths[ci].toDouble());
    }
    sheet.setColumnAutoFit(2); // Nama auto.
    final bytes = wb.save();
    return Uint8List.fromList(bytes!);
  }

  Future<void> _saveExcel() async {
    try {
      final bytes = await _buildExcel();
      final name = 'Opname-${widget.opnameId}-${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      // Web: trigger download. Mobile: share/save.
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: name);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel tersimpan: $name')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal Excel: $e')));
    }
  }

  Future<void> _savePdf() async {
    try {
      final bytes = await _buildPdf();
      final name = 'Opname-${widget.opnameId}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF tersimpan: $name')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal PDF: $e')));
    }
  }

  Future<void> _print() async {
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        format: PdfPageFormat.a4.landscape,
        name: 'Opname ${widget.opnameId}',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal print: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hdr = header;
    final total = items.length;
    final cocok = items.where((m) => m['status'] == 'COCOK').length;
    final lebih = items.where((m) => m['status'] == 'LEBIH').length;
    final kurang = items.where((m) => m['status'] == 'KURANG').length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Report ${widget.opnameId.substring(0, 8)}'),
        backgroundColor: QjColors.navy, foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Simpan PDF', icon: const Icon(Icons.picture_as_pdf),
            onPressed: _loading ? null : _savePdf),
          IconButton(tooltip: 'Simpan Excel', icon: const Icon(Icons.table_chart),
            onPressed: _loading ? null : _saveExcel),
          IconButton(tooltip: 'Print', icon: const Icon(Icons.print),
            onPressed: _loading ? null : _print),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Header meta + ringkasan.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                color: QjColors.navy,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sesi ${widget.opnameId} \u2022 Zona ${(hdr?['scopeZona'] as List?)?.join(', ') ?? '-'} '
                    '\u2022 ${hdr?['status'] ?? '-'}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${hdr?['catatan'] ?? ''} \u2022 ${_tglHeader(hdr?['createdAt'])}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _chip('Total $total', Colors.white, QjColors.navy),
                    _chip('Cocok $cocok', Colors.green.shade100, Colors.green.shade800),
                    _chip('Lebih $lebih', Colors.orange.shade100, Colors.orange.shade800),
                    _chip('Kurang $kurang', Colors.red.shade100, Colors.red.shade800),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: QjColors.red, foregroundColor: Colors.white),
                      onPressed: _print, icon: const Icon(Icons.print, size: 16), label: const Text('Print')),
                    OutlinedButton.icon(
                      onPressed: _savePdf, icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Simpan PDF')),
                    OutlinedButton.icon(
                      onPressed: _saveExcel, icon: const Icon(Icons.table_chart, size: 16),
                      label: const Text('Simpan Excel')),
                  ]),
                ]),
              ),
              // Filter status.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  for (final f in [null, 'COCOK', 'LEBIH', 'KURANG'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f ?? 'Semua (${items.length})',
                          style: const TextStyle(fontSize: 12)),
                        selected: _filter == f,
                        selectedColor: QjColors.red.withOpacity(0.15),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('Tidak ada data untuk filter ini.',
                        style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final m = _filtered[i];
                          final kode = '${m['kode']}';
                          final info = _partInfo[kode];
                          final st = '${m['status']}';
                          final col = st == 'COCOK' ? Colors.green
                              : st == 'LEBIH' ? Colors.orange : Colors.red;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(radius: 14, backgroundColor: col.withOpacity(0.15),
                              child: Text(st == 'COCOK' ? '\u2713' : st == 'LEBIH' ? '+' : '-',
                                style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12))),
                            title: Text('$kode \u2022 ${info?['nama'] ?? '-'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Sist ${m['stokSistem']} \u2192 Fisik ${m['stokFisik']} \u2022 ${m['countedBy'] ?? '-'} \u2022 ${_fmt(m['countedAt'])}'
                              '\n${info?['alamat'] ?? '-'}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            isThreeLine: true,
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(6)),
                                child: Text(st, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                              const SizedBox(height: 4),
                              Text('${(m['selisih'] ?? 0) > 0 ? '+' : ''}${m['selisih'] ?? 0}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
                            ]),
                          );
                        },
                      ),
              ),
            ]),
    );
  }

  Widget _chip(String t, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
  );
}
