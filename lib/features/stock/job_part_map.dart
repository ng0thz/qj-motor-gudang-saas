// Mapping PART -> JOB (arah balik). PDF tidak punya tabel ini,
// jadi dibangun dari kategori + override manual fast moving.
// Struktur: faultCode -> {keywords nama part, kode part eksplisit}
class JobPartRule {
  final String faultCode;
  final List<String> keywords; // cocok ke nama part (uppercase contains)
  final List<String> partCodes; // kode part eksplisit
  JobPartRule({required this.faultCode, this.keywords = const [], this.partCodes = const []});
}

// Override manual fast moving QJ Motor
final List<JobPartRule> jobPartRules = [
  JobPartRule(faultCode: '1615', keywords: ['SPARK PLUG', 'BUSI'], partCodes: ['2990NGK00001', '2990NGK00002', '299074660000']),
  JobPartRule(faultCode: '1511', keywords: ['BRAKE PAD', 'KAMPAS REM', 'PAD ASSY BRAKE'], partCodes: ['45110NA70000', '55110NA70000', '45110T400000']),
  JobPartRule(faultCode: '1512', keywords: ['BRAKE PAD', 'KAMPAS REM'], partCodes: []),
  JobPartRule(faultCode: '1602', keywords: ['CLUTCH ASSY', 'KAMPAS KOPLING', 'CLUTCH PLATE', 'FRICTION PLATE'], partCodes: []),
  JobPartRule(faultCode: '1302', keywords: ['AIR FILTER', 'FILTER ELEMENT', 'FILTER UDARA'], partCodes: ['49200N510000', '49100N590000']),
  JobPartRule(faultCode: '2005', keywords: ['IGNITION COIL', 'KOIL'], partCodes: []),
];

// Fallback kategori: part ENGINE -> job ENGINE, dst.
String jobCategoryForPart(String jenisPart) {
  final j = jenisPart.toUpperCase();
  if (['ENGINE', 'OIL_FLUID', 'DRIVE'].contains(j)) return 'ENGINE';
  if (['BRAKE'].contains(j)) return 'FRAME';
  if (['ELECTRICAL'].contains(j)) return 'ELECTRICAL';
  if (['BODY', 'SUSPENSION', 'FASTENER', 'COOLING'].contains(j)) return 'FRAME';
  return '';
}

// Cari fault codes yang cocok untuk sebuah part
List<String> suggestJobsForPart({required String kode, required String nama, required String jenisPart}) {
  final n = nama.toUpperCase();
  final out = <String>[];
  for (final r in jobPartRules) {
    if (r.partCodes.contains(kode)) { out.add(r.faultCode); continue; }
    if (r.keywords.any((k) => n.contains(k))) out.add(r.faultCode);
  }
  return out.toSet().toList();
}
