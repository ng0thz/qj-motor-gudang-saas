import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Cetak label bin box via PDF
// Satu label: Kode, Nama, Harga Jual, Alamat Rak-Bin, QR isi kode
class LabelItem {
  final String kode;
  final String nama;
  final int jual;
  final String alamat;
  LabelItem({required this.kode, required this.nama, required this.jual, required this.alamat});
}

class LabelPrintPage extends StatelessWidget {
  final List<LabelItem> items;
  const LabelPrintPage({super.key, required this.items});

  Future<void> _printPdf(BuildContext context) async {
    final doc = pw.Document();
    // 4 label per halaman A4 (2x2), ukuran label bin 100x60mm
    const perPage = 4;
    for (var i = 0; i < items.length; i += perPage) {
      final chunk = items.skip(i).take(perPage).toList();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12),
        build: (c) => pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          children: chunk.map((it) => pw.Container(
            padding: const pw.EdgeInsets.all(8),
            margin: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(it.kode, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(it.nama, style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 4),
                pw.Text('Rp ${it.jual}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(it.alamat, style: const pw.TextStyle(fontSize: 10)),
              ])),
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: it.kode, width: 70, height: 70),
            ]),
          )).toList(),
        ),
      ));
    }
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QJ Motor - Label ${items.length} Bin'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _printPdf(context))]),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final it = items[i];
          return ListTile(
            title: Text(it.nama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${it.kode} • ${it.alamat}'),
            trailing: Text('Rp ${it.jual}', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _printPdf(context), icon: const Icon(Icons.print), label: const Text('Cetak PDF')),
    );
  }
}
