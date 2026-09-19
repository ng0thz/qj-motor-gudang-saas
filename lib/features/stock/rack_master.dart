import 'package:flutter/material.dart';

// Master Rak 5 tier - urut dari depan (pintu) ke belakang
// VERY_FAST paling depan, VERY_SLOW paling belakang
class RackTier {
  final String tier; // VERY_FAST, FAST, MEDIUM, SLOW, VERY_SLOW
  final String zona; // A, B, C, D, E
  final Color color;
  final String rakAwal;
  final String rakAkhir;
  final String desc;
  const RackTier(this.tier, this.zona, this.color, this.rakAwal, this.rakAkhir, this.desc);
}

const List<RackTier> rackTiers = [
  RackTier('VERY_FAST', 'A', Color(0xFFC62828), 'A-01', 'A-10', 'Oli, Busi, Kampas - keluar tiap jam'),
  RackTier('FAST', 'B', Color(0xFFEF6C00), 'B-01', 'B-10', 'Filter, Belt, Brake pad - harian'),
  RackTier('MEDIUM', 'C', Color(0xFFF9A825), 'C-01', 'C-10', 'Baut, Kabel, Lampu - mingguan'),
  RackTier('SLOW', 'D', Color(0xFF2E7D32), 'D-01', 'D-10', 'Body, Cover - bulanan'),
  RackTier('VERY_SLOW', 'E', Color(0xFF1565C0), 'E-01', 'E-10', 'Crankcase, Frame - jarang'),
];

// Mapping jenis barang -> tier (berdasarkan jenis_part dari klasifikasi)
String tierForJenis(String jenisPart, String kategoriMoving) {
  final j = jenisPart.toUpperCase();
  final k = kategoriMoving.toUpperCase();
  // Very fast: consumable cepat habis
  if (['OIL_FLUID', 'ELECTRICAL'].contains(j) && k == 'FAST') return 'VERY_FAST';
  if (j == 'BRAKE' && k == 'FAST') return 'VERY_FAST';
  if (k == 'FAST') return 'FAST';
  if (k == 'MEDIUM') return 'MEDIUM';
  if (k == 'SLOW' && ['BODY', 'SUSPENSION'].contains(j)) return 'SLOW';
  if (k == 'SLOW') return 'VERY_SLOW';
  // fallback by jenis
  if (['BODY'].contains(j)) return 'SLOW';
  if (['ENGINE'].contains(j)) return 'VERY_SLOW';
  if (['FASTENER'].contains(j)) return 'MEDIUM';
  return 'MEDIUM';
}

RackTier tierInfo(String tier) {
  return rackTiers.firstWhere((e) => e.tier == tier, orElse: () => rackTiers[2]);
}

// Format alamat: ZONA-Rak-Level-Bin, contoh A-02-04-M05
String buildAlamat(String zona, String rakNo, String level, String bin) {
  return '$zona-$rakNo-$level-$bin';
}

// Contoh: parse "A-02-04-M05" -> zona A, rak 02, level 04, bin M05
Map<String, String> parseAlamat(String alamat) {
  final p = alamat.split('-');
  if (p.length < 4) return {'zona': '', 'rak': '', 'level': '', 'bin': ''};
  return {'zona': p[0], 'rak': p[1], 'level': p[2], 'bin': p.sublist(3).join('-')};
}
