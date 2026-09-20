import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_repository.dart';

void openHistory(BuildContext context, String kode) {
  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) {
    return SizedBox(height: 500, child: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Text('History $kode', style: const TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: StockRepository().history(kode),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const Center(child: Text('Belum ada mutasi'));
          final fmt = DateFormat('dd/MM HH:mm');
          return ListView.separated(
            itemCount: s.data!.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = s.data![i];
              final ts = m['timestamp'];
              final tgl = ts == null ? '-' : fmt.format((ts as dynamic).toDate());
              return ListTile(
                dense: true,
                leading: Chip(label: Text('${m['tipe']}', style: const TextStyle(fontSize: 10))),
                title: Text('Qty ${m['qty']} • ${m['catatan'] ?? m['kendaraan']?['nopol'] ?? ''}', style: const TextStyle(fontSize: 12)),
                subtitle: Text('${m['alamatBaru'] ?? ''} ${m['woId'] ?? ''} • ${m['oleh'] ?? ''}', style: const TextStyle(fontSize: 11)),
                trailing: Text(tgl, style: const TextStyle(fontSize: 11)),
              );
            },
          );
        },
      )),
    ]));
  });
}
