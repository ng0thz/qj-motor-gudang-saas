import 'package:flutter/material.dart';
import 'stock_model.dart';
import 'stock_repository.dart';
import 'scan_page.dart';
import 'rack_master.dart';
import 'rack_picker.dart';
import 'label_print_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final repo = StockRepository();
  final ctrlSearch = TextEditingController();

  void _scanBarcode() async {
    final code = await openScan(context, title: 'QJ Motor - Scan');
    if (code == null || !mounted) return;
    final part = await repo.getByBarcode(code);
    if (!mounted) return;
    if (part == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak ditemukan: $code')));
    } else {
      _showDetail(part);
    }
  }

  void _showDetail(Sparepart p) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Chip(label: Text(p.kategori), backgroundColor: p.isMenipis? Colors.orange.shade100 : Colors.green.shade100),
          ]),
          const SizedBox(height: 8),
          Text('Part Code: ${p.kode} • Motor: ${p.motorType}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(),
          Row(children: [
            _info('Stok', '${p.stok}', p.isMenipis? Colors.red: Colors.green),
            _info('Min', '${p.minStok}', Colors.grey),
            _info('Alamat', p.alamat, Colors.blue),
          ]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Harga', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Retail: Rp ${p.harga.retail}'), Text('Pajak 11%: Rp ${p.harga.pajakRp}'),
              ]),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF1B2A4A), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('HARGA JUAL', style: TextStyle(color: Colors.white, fontSize: 11)),
                  Text('Rp ${p.harga.jual}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
              ),
              Text('Modal: Rp ${p.harga.modal} (hanya Staff Gudang)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
          if (p.substitusi.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Substitusi', style: TextStyle(fontWeight: FontWeight.bold)),
            ...p.substitusi.map((s)=> ListTile(dense:true, title: Text('${s.kode} - ${s.nama}'), subtitle: Text('${s.status}: ${s.catatan}'), trailing: const Icon(Icons.swap_horiz))),
          ],
          if (p.kompatibel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Kompatibel: ${p.kompatibel.join(", ")}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(8), color: tierInfo(tierForJenis(p.jenisPart, p.kategori)).color.withOpacity(0.12),
            child: Text('Rak: ${tierForJenis(p.jenisPart, p.kategori)} (Zona ${tierInfo(tierForJenis(p.jenisPart, p.kategori)).zona}) • ${p.alamat.isEmpty ? 'Belum ada alamat' : p.alamat}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: ()=> _inOut(p, 'IN'), icon: const Icon(Icons.add), label: const Text('IN +'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: ()=> _inOut(p, 'OUT'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), icon: const Icon(Icons.remove), label: const Text('OUT -'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.grid_view), label: const Text('Pilih Rak'), onPressed: () async {
              final alamat = await openRackPicker(context, jenisPart: p.jenisPart, kategoriMoving: p.kategori, initialAlamat: p.alamat);
              if (alamat != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alamat: $alamat')));
            })),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('Label PDF'), onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => LabelPrintPage(items: [
                LabelItem(kode: p.kode, nama: p.nama, jual: p.harga.jual, alamat: p.alamat.isEmpty ? tierForJenis(p.jenisPart, p.kategori) : p.alamat)
              ])));
            })),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: (){}, child: const Text('History • Pindah Rak'))),
        ]),
      );
    });
  }

  Widget _info(String label, String val, Color c) {
    return Expanded(child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
    ]));
  }

  void _inOut(Sparepart p, String tipe) async {
    final qtyCtrl = TextEditingController(text: '1');
    final nopolCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('$tipe - ${p.kode}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qty'), keyboardType: TextInputType.number),
        if (tipe=='OUT') TextField(controller: nopolCtrl, decoration: const InputDecoration(labelText: 'Nopol B 1234 ABC *wajib')),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: () async {
          final qty = int.tryParse(qtyCtrl.text) ?? 1;
          await repo.addMovement(kode: p.kode, qty: qty, tipe: tipe, nopol: nopolCtrl.text);
          if (mounted) { Navigator.pop(context); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$tipe $qty berhasil'))); }
        }, child: const Text('Simpan')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gudang SaaS - 500 SKU'),
        backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _scanBarcode, icon: const Icon(Icons.qr_code_scanner))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          controller: ctrlSearch, decoration: InputDecoration(
            hintText: 'Cari Part Code / Nama / Motor Type AX180...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.qr_code), onPressed: _scanBarcode),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ), onChanged: (v)=> setState((){}),
        )),
        // 3000 SKU: load 50 awal, search filter di memory (3MB masih ringan)
        Expanded(child: StreamBuilder<List<Sparepart>>(
          stream: repo.watchAll(limit: 50),
          builder: (c,snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var list = snap.data!;
            // Untuk 3000 SKU: jika search, load semua 3000 ke memory (sekali) lalu filter client
            // Prod: ganti dengan Algolia/Typesense jika 3000 terasa lambat
            return FutureBuilder<List<Sparepart>>(
              future: ctrlSearch.text.isNotEmpty ? repo.fetchAll3000() : Future.value(list),
              builder: (c2, snap2) {
                var display = snap2.data ?? list;
                final q = ctrlSearch.text.toLowerCase();
                if (q.isNotEmpty) {
                  display = display.where((p)=> p.kode.toLowerCase().contains(q) || p.nama.toLowerCase().contains(q) || p.motorType.toLowerCase().contains(q)).toList();
                }
                if (display.isEmpty) return const Center(child: Text('Belum ada data. Import Excel 3000 SKU.'));
                return Column(children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text('${display.length} SKU tampil (dari 3000 max) • ${list.length} stream awal', style: const TextStyle(fontSize: 10, color: Colors.grey))),
                  Expanded(child: ListView.separated(
                    itemCount: display.length,
                    separatorBuilder: (_,__)=> const Divider(height:1),
                    itemBuilder: (_,i){
                      final p = display[i];
                      return ListTile(
                        onTap: ()=> _showDetail(p),
                        leading: CircleAvatar(backgroundColor: p.isHabis? Colors.red.shade100 : p.isMenipis? Colors.orange.shade100 : Colors.green.shade100,
                          child: Text(p.kode.length>=2? p.kode.substring(0,2): p.kode, style: const TextStyle(fontSize: 10))),
                        title: Text(p.nama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('${p.kode} • ${p.motorType} • ${p.alamat}', style: const TextStyle(fontSize: 11)),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Rp ${p.harga.jual}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Stok ${p.stok}', style: TextStyle(fontSize: 11, color: p.isMenipis? Colors.red: Colors.green, fontWeight: FontWeight.bold)),
                        ]),
                      );
                    },
                  )),
                ]);
              },
            );
          },
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _scanBarcode, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')),
    );
  }
}
