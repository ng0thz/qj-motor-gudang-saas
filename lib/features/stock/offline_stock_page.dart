import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'import_update_page.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('QJ Motor - ${data.length} SKU'), backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Import update harga', onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const ImportUpdatePage())))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v)=> setState(()=> q=v), decoration: const InputDecoration(hintText: 'Cari 05523M79K500 ...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (_,i){
          final d = filtered[i];
          return ListTile(title: Text(d['nama']??''), subtitle: Text('${d['kode']} • ${d['motorType']??''}'), trailing: Text('Rp ${d['jual']??''}'), onTap: (){
            showModalBottomSheet(context: context, builder: (_)=> Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['nama']??'', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Part Code: ${d['kode']}'),
              Text('Motor: ${d['motorType']}'),
              const SizedBox(height:8),
              Text('Retail: Rp ${d['retail']}  Pajak: Rp ${d['pajakRp']}'),
              Container(color: const Color(0xFF1B2A4A), padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('JUAL', style: TextStyle(color: Colors.white)), Text('Rp ${d['jual']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
              Text('Kategori: ${d['kategori_moving']??''} | Jenis: ${d['jenis_part']??''}'),
              Text('Stok: 0 DRAFT - cek real di gudang'),
            ])));
          });
        })),
      ]),
    );
  }
}
