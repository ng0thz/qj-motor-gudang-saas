import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'import_update_page.dart';
import 'scan_page.dart';
import 'rack_master.dart';
import 'rack_picker.dart';
import 'label_print_page.dart';

class OfflineStockPageFull extends StatefulWidget {
  const OfflineStockPageFull({super.key});
  @override
  State<OfflineStockPageFull> createState() => _OfflineStockPageFullState();
}

class _OfflineStockPageFullState extends State<OfflineStockPageFull> {
  List<Map<String,dynamic>> data = [];
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await rootBundle.loadString('assets/data_import_classified.json');
      setState(() => data = List<Map<String,dynamic>>.from(jsonDecode(s)));
    } catch (e) {
      // fallback dari assets/data_import.json
      try {
        final s2 = await rootBundle.loadString('assets/data_import.json');
        setState(() => data = List<Map<String,dynamic>>.from(jsonDecode(s2)));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = data.where((d){
      if(q.isEmpty) return true;
      final lq = q.toLowerCase();
      return d['kode'].toString().toLowerCase().contains(lq) || d['nama'].toString().toLowerCase().contains(lq);
    }).take(100).toList();
    void showDetail(Map<String, dynamic> d) {
      final tier = tierForJenis((d['jenis_part'] ?? 'OTHER').toString(), (d['kategori_moving'] ?? d['kategori'] ?? 'MEDIUM').toString());
      final info = tierInfo(tier);
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d['nama'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Part Code: ${d['kode']}'),
          Text('Motor: ${d['motorType']}'),
          const SizedBox(height: 8),
          Text('Retail: Rp ${d['retail']}  Pajak: Rp ${d['pajakRp']}'),
          Container(color: const Color(0xFF1B2A4A), padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('JUAL', style: TextStyle(color: Colors.white)), Text('Rp ${d['jual']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(8), color: info.color.withOpacity(0.12),
            child: Text('Rak: $tier (Zona ${info.zona} • ${info.desc})', style: TextStyle(fontWeight: FontWeight.bold, color: info.color))),
          Text('Kategori: ${d['kategori_moving'] ?? ''} | Jenis: ${d['jenis_part'] ?? ''}'),
          const Text('Stok: 0 DRAFT - cek real di gudang'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.grid_view), label: const Text('Pilih Rak'), onPressed: () async {
              final alamat = await openRackPicker(context, jenisPart: (d['jenis_part'] ?? 'OTHER').toString(), kategoriMoving: (d['kategori_moving'] ?? 'MEDIUM').toString());
              if (!mounted) return;
              if (alamat != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alamat dipilih: $alamat')));
            })),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('Label PDF'), onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => LabelPrintPage(items: [
                LabelItem(kode: d['kode'].toString(), nama: (d['nama'] ?? '').toString(), jual: int.tryParse(d['jual'].toString()) ?? 0, alamat: tier)
              ])));
            })),
          ]),
        ]),
      ));
    }

    Future<void> doScan() async {
      final code = await openScan(context, title: 'QJ Motor - Scan');
      if (code == null || !mounted) return;
      final found = data.where((e) => e['kode'].toString().toLowerCase() == code.toLowerCase()).toList();
      if (found.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak ditemukan: $code')));
      } else {
        showDetail(found.first);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('QJ Motor - ${data.length} SKU'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan barcode/QR', onPressed: doScan),
          IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Import update harga', onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const ImportUpdatePage()))),
        ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v)=> setState(()=> q=v),
          decoration: InputDecoration(hintText: 'Cari 05523M79K500 ...', prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.qr_code), onPressed: doScan), border: const OutlineInputBorder()))),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (_,i){
          final d = filtered[i];
          return ListTile(title: Text(d['nama']??''), subtitle: Text('${d['kode']} • ${d['motorType']??''}'), trailing: Text('Rp ${d['jual']??''}'), onTap: ()=> showDetail(d));
        })),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: doScan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')),
    );
  }
}
