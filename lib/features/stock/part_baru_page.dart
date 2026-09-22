import 'package:flutter/material.dart';
import 'stock_repository.dart';
import '../../core/session.dart';

// Form pendaftaran part BARU dari hasil scan kode tak dikenal.
// Kode hasil scan sudah terisi otomatis. Gated: canCreatePart.
class PartBaruPage extends StatefulWidget {
  final String kodeAwal;
  const PartBaruPage({super.key, required this.kodeAwal});
  @override
  State<PartBaruPage> createState() => _PartBaruPageState();
}

class _PartBaruPageState extends State<PartBaruPage> {
  final repo = StockRepository();
  late final TextEditingController kodeCtrl;
  final namaCtrl = TextEditingController();
  final motorCtrl = TextEditingController();
  final alamatCtrl = TextEditingController();
  final retailCtrl = TextEditingController(text: '0');
  final minCtrl = TextEditingController(text: '5');
  final stokCtrl = TextEditingController(text: '0');
  String jenis = 'OTHER';
  bool saving = false;

  static const jenisList = [
    'ENGINE', 'BRAKE', 'BODY', 'ELECTRICAL', 'SUSPENSION',
    'TRANSMISSION', 'FUEL', 'COOLING', 'TOOLS', 'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    kodeCtrl = TextEditingController(text: widget.kodeAwal);
  }

  Future<void> _simpan() async {
    if (!AuthSession.instance.canCreatePart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya Staff Gudang / Ops yang boleh daftar part baru.')));
      return;
    }
    if (namaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama part wajib diisi.')));
      return;
    }
    setState(() => saving = true);
    try {
      // Cegah duplikat: pastikan kode belum ada
      final existing = await repo.getByBarcode(kodeCtrl.text.trim());
      if (existing != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kode sudah terdaftar: ${existing.nama}')));
        setState(() => saving = false);
        return;
      }
      await repo.createPart(
        kode: kodeCtrl.text,
        nama: namaCtrl.text,
        motorType: motorCtrl.text,
        jenisPart: jenis,
        alamat: alamatCtrl.text,
        retail: int.tryParse(retailCtrl.text) ?? 0,
        minStok: int.tryParse(minCtrl.text) ?? 5,
        stokAwal: int.tryParse(stokCtrl.text) ?? 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Part baru tersimpan: ${kodeCtrl.text.trim()}')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Part Baru'),
        backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Kode hasil scan sudah terisi otomatis. Part Code = barcode label.',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(controller: kodeCtrl, decoration: const InputDecoration(
          labelText: 'Part Code / Barcode *', border: OutlineInputBorder(),
          helperText: 'Inilah yang ditempel sebagai QR label di bin')),
        const SizedBox(height: 12),
        TextField(controller: namaCtrl, decoration: const InputDecoration(
          labelText: 'Nama part *', border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.characters),
        const SizedBox(height: 12),
        TextField(controller: motorCtrl, decoration: const InputDecoration(
          labelText: 'Motor type (mis. SRV 250 AMT)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: jenis,
          decoration: const InputDecoration(labelText: 'Jenis part', border: OutlineInputBorder()),
          items: jenisList.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
          onChanged: (v) => setState(() => jenis = v ?? 'OTHER'),
        ),
        const SizedBox(height: 12),
        TextField(controller: alamatCtrl, decoration: const InputDecoration(
          labelText: 'Alamat rak (mis. A-02-04-M05)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: retailCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Harga retail Rp', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Min stok', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: stokCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Stok awal fisik (0 jika opname dulu)',
            border: OutlineInputBorder(), helperText: 'Stok awal tercatat sebagai IN + jejak audit')),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: saving ? null : _simpan,
          icon: saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(saving ? 'Menyimpan...' : 'Simpan Part Baru'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ]),
    );
  }
}
