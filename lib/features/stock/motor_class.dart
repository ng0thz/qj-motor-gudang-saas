// Klasifikasi motor QJ Motor berdasar CC: KECIL (<=200), MEDIUM (250), HIGH (>=600).
// Dipakai di: dropdown WO (grup), fallback harga FRT, filter stok, laporan per kelas.
class MotorInfo {
  final String model;
  final String kelas; // KECIL|MEDIUM|HIGH
  final int cc;
  const MotorInfo(this.model, this.kelas, this.cc);
}

const List<MotorInfo> motorMaster = [
  MotorInfo('VIENTO 180', 'KECIL', 180),
  MotorInfo('CITO 150', 'KECIL', 150),
  MotorInfo('FORT 180 ADV', 'KECIL', 180),
  MotorInfo('SRV 200', 'KECIL', 200),
  MotorInfo('FORT 250', 'MEDIUM', 250),
  MotorInfo('FORT 250 ADV', 'MEDIUM', 250),
  MotorInfo('FORT 250 R - PRO', 'MEDIUM', 250),
  MotorInfo('SRV 250 AMT', 'MEDIUM', 250),
  MotorInfo('SRV 250 LIBERO', 'MEDIUM', 250),
  MotorInfo('TOURINO 250 DX', 'MEDIUM', 250),
  MotorInfo('SRV 600 V', 'HIGH', 600),
  MotorInfo('SRK 800 RR', 'HIGH', 800),
  MotorInfo('TOURINO 700 SX', 'HIGH', 700),
  MotorInfo('SRK 250 RA', 'MEDIUM', 250),
];

String kelasOf(String model) {
  final m = model.toUpperCase().trim();
  for (final e in motorMaster) {
    if (m == e.model || m.contains(e.model) || e.model.contains(m)) return e.kelas;
  }
  // Fallback dari angka CC di nama (mis. "AX 180")
  final num = RegExp(r'(\d{2,4})').firstMatch(m);
  if (num != null) {
    final cc = int.tryParse(num.group(1)!) ?? 0;
    if (cc <= 200) return 'KECIL';
    if (cc <= 300) return 'MEDIUM';
    if (cc >= 500) return 'HIGH';
  }
  return 'MEDIUM';
}

List<String> modelsOfKelas(String kelas) =>
    motorMaster.where((e) => e.kelas == kelas).map((e) => e.model).toList();

// Model representatif untuk harga FRT (tabel FRT hanya punya 4 model)
String frtModelFor(String model) {
  const frtModels = ['FORT 250', 'SRV 250 AMT', 'SRV 600 V', 'SRK 800 RR'];
  if (frtModels.contains(model)) return model;
  switch (kelasOf(model)) {
    case 'KECIL':
      return 'FORT 250';
    case 'HIGH':
      return 'SRV 600 V';
    default:
      return model.contains('SRV') ? 'SRV 250 AMT' : 'FORT 250';
  }
}

// Cek apakah string motorType/kompatibel cocok dengan kelas
bool motorTypeIsKelas(String motorType, String kelas) {
  final t = motorType.toUpperCase();
  return modelsOfKelas(kelas).any((m) => t.contains(m));
}
