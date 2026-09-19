import 'package:flutter/material.dart';
import 'rack_master.dart';

// Picker alamat rak: auto suggest tier dari jenis barang, user bisa ubah manual
// Return alamat string "A-02-04-M05"
class RackPicker extends StatefulWidget {
  final String jenisPart;
  final String kategoriMoving;
  final String initialAlamat;
  const RackPicker({super.key, required this.jenisPart, required this.kategoriMoving, this.initialAlamat = ''});

  @override
  State<RackPicker> createState() => _RackPickerState();
}

class _RackPickerState extends State<RackPicker> {
  late String tier;
  late String zona;
  String rak = '02';
  String level = '04';
  String bin = 'M05';

  @override
  void initState() {
    super.initState();
    tier = tierForJenis(widget.jenisPart, widget.kategoriMoving);
    zona = tierInfo(tier).zona;
    if (widget.initialAlamat.isNotEmpty) {
      final p = parseAlamat(widget.initialAlamat);
      if (p['zona']!.isNotEmpty) { zona = p['zona']!; rak = p['rak']!; level = p['level']!; bin = p['bin']!; }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = tierInfo(tier);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rak disarankan: $tier (${info.zona} • ${info.desc})', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: rackTiers.map((t) => ChoiceChip(
          label: Text(t.tier, style: const TextStyle(fontSize: 11)),
          selected: tier == t.tier,
          onSelected: (_) => setState(() { tier = t.tier; zona = t.zona; }),
        )).toList()),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: zona, decoration: const InputDecoration(labelText: 'Zona'), items: ['A','B','C','D','E'].map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(), onChanged: (v) => setState(() => zona = v!))),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(initialValue: rak, decoration: const InputDecoration(labelText: 'Rak (01-10)'), onChanged: (v) => rak = v)),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(initialValue: level, decoration: const InputDecoration(labelText: 'Level'), onChanged: (v) => level = v)),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(initialValue: bin, decoration: const InputDecoration(labelText: 'Bin'), onChanged: (v) => bin = v)),
        ]),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(10), color: const Color(0xFF1B2A4A),
          child: Text('Alamat: ${buildAlamat(zona, rak, level, bin)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context, buildAlamat(zona, rak, level, bin)), child: const Text('Pilih Alamat'))),
      ]),
    );
  }
}

Future<String?> openRackPicker(BuildContext context, {required String jenisPart, required String kategoriMoving, String initialAlamat = ''}) {
  return showModalBottomSheet<String>(context: context, isScrollControlled: true,
    builder: (_) => RackPicker(jenisPart: jenisPart, kategoriMoving: kategoriMoving, initialAlamat: initialAlamat));
}
