import 'package:cloud_firestore/cloud_firestore.dart';

// Master FRT QJMOTOR: JOB -> JASA per model.
// 2 tipe (dokumen beda): warranty (LIST FRT WARRANTY CLAIM) & service (LIST FRT SERVICE retail).
// WORK/HOUR = 0 + PRICE = - artinya TIDAK BERLAKU untuk model itu -> disembunyikan di UI.
class FrtEntry {
  final String faultCode; // '' bila tidak ada (mis. Service Tune Up)
  final String category; // ELECTRICAL | ENGINE | FRAME
  final String job;
  final Map<String, double> hours; // model -> jam
  final Map<String, int> price; // model -> rupiah

  FrtEntry({required this.faultCode, required this.category, required this.job, required this.hours, required this.price});

  static const models = ['FORT 250', 'SRV 250 AMT', 'SRV 600 V', 'SRK 800 RR'];

  // Model di luar tabel (mis. VIENTO 180) difallback ke representatif kelasnya.
  // Import di bawah agar tidak circular: dipanggil via helper di motor_class.
  bool appliesTo(String model) => priceFor(model) > 0;
  int priceFor(String model) {
    if ((price[model] ?? 0) > 0) return price[model]!;
    // Fallback kelas: KECIL->FORT 250, HIGH->SRV 600 V, MEDIUM->SRV 250 AMT/FORT 250
    final m = model.toUpperCase();
    if (RegExp(r'180|150|200|VIENTO|CITO').hasMatch(m)) return price['FORT 250'] ?? 0;
    if (RegExp(r'600|800|700').hasMatch(m)) return price['SRV 600 V'] ?? 0;
    if (m.contains('SRV')) return price['SRV 250 AMT'] ?? 0;
    return price['FORT 250'] ?? 0;
  }

  Map<String, dynamic> toMap() => {
    'faultCode': faultCode, 'category': category, 'job': job,
    'hours': hours, 'price': price,
  };

  factory FrtEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return FrtEntry(
      faultCode: m['faultCode'] ?? d.id,
      category: m['category'] ?? '',
      job: m['job'] ?? '',
      hours: Map<String, double>.from((m['hours'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
      price: Map<String, int>.from((m['price'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
    );
  }
}

// Seed contoh dari PDF (digitasi penuh via Import CSV di halaman FRT).
// Format CSV: fault_code,category,job,fort250_hour,fort250_price,srv250_hour,srv250_price,srv600_hour,srv600_price,srk800_hour,srk800_price
// PRICE '-' / kosong = 0 (tidak berlaku).
final List<FrtEntry> seedWarranty = [
  FrtEntry(faultCode: '1615', category: 'ENGINE', job: 'Spark Plug',
    hours: {'FORT 250': 0.4, 'SRV 250 AMT': 0.5, 'SRV 600 V': 0.5, 'SRK 800 RR': 0.5},
    price: {'FORT 250': 30000, 'SRV 250 AMT': 37500, 'SRV 600 V': 62500, 'SRK 800 RR': 62500}),
  FrtEntry(faultCode: '1511', category: 'FRAME', job: 'Brake Pad Assy @each(Front)',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.25, 'SRV 600 V': 0.25, 'SRK 800 RR': 0.25},
    price: {'FORT 250': 18750, 'SRV 250 AMT': 18750, 'SRV 600 V': 31250, 'SRK 800 RR': 31250}),
  FrtEntry(faultCode: '1512', category: 'FRAME', job: 'Brake Pad Assy @each(Front)',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.25, 'SRV 600 V': 0.25, 'SRK 800 RR': 0.25},
    price: {'FORT 250': 18750, 'SRV 250 AMT': 18750, 'SRV 600 V': 31250, 'SRK 800 RR': 31250}),
  FrtEntry(faultCode: '1602', category: 'ENGINE', job: 'Clutch Assy',
    hours: {'FORT 250': 0.4, 'SRV 250 AMT': 0.5, 'SRV 600 V': 0.5, 'SRK 800 RR': 0.5},
    price: {'FORT 250': 30000, 'SRV 250 AMT': 37500, 'SRV 600 V': 62500, 'SRK 800 RR': 62500}),
  FrtEntry(faultCode: '2005', category: 'ELECTRICAL', job: 'Ignition Coil',
    hours: {'FORT 250': 0.4, 'SRV 250 AMT': 0.5, 'SRV 600 V': 0.5, 'SRK 800 RR': 0.5},
    price: {'FORT 250': 30000, 'SRV 250 AMT': 37500, 'SRV 600 V': 62500, 'SRK 800 RR': 62500}),
  FrtEntry(faultCode: '1302', category: 'FRAME', job: 'Air Filter Element',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.25, 'SRV 600 V': 0.4, 'SRK 800 RR': 0.4},
    price: {'FORT 250': 18750, 'SRV 250 AMT': 18750, 'SRV 600 V': 50000, 'SRK 800 RR': 50000}),
  FrtEntry(faultCode: '2102', category: 'ELECTRICAL', job: 'Brake Light Switch (Front)',
    hours: {'FORT 250': 0.15, 'SRV 250 AMT': 0.15, 'SRV 600 V': 0.25, 'SRK 800 RR': 0.15},
    price: {'FORT 250': 11250, 'SRV 250 AMT': 11250, 'SRV 600 V': 31250, 'SRK 800 RR': 18750}),
  FrtEntry(faultCode: '2119', category: 'ELECTRICAL', job: 'Horn',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.25, 'SRV 600 V': 0.25, 'SRK 800 RR': 0.25},
    price: {'FORT 250': 18750, 'SRV 250 AMT': 18750, 'SRV 600 V': 31250, 'SRK 800 RR': 31250}),
];

final List<FrtEntry> seedService = [
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'Service Tune Up',
    hours: {'FORT 250': 1, 'SRV 250 AMT': 1, 'SRV 600 V': 1, 'SRK 800 RR': 1},
    price: {'FORT 250': 120000, 'SRV 250 AMT': 120000, 'SRV 600 V': 250000, 'SRK 800 RR': 300000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P Kampas Rem Depan',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.25, 'SRV 600 V': 0.25, 'SRK 800 RR': 0.25},
    price: {'FORT 250': 30000, 'SRV 250 AMT': 30000, 'SRV 600 V': 62500, 'SRK 800 RR': 75000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P Kampas Rem Belakang',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.25, 'SRV 600 V': 0.25, 'SRK 800 RR': 0.25},
    price: {'FORT 250': 30000, 'SRV 250 AMT': 30000, 'SRV 600 V': 62500, 'SRK 800 RR': 75000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P Kampas Kopling',
    hours: {'FORT 250': 0.4, 'SRV 250 AMT': 0.5, 'SRV 600 V': 0.5, 'SRK 800 RR': 0.5},
    price: {'FORT 250': 48000, 'SRV 250 AMT': 60000, 'SRV 600 V': 125000, 'SRK 800 RR': 150000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P V-Belt',
    hours: {'FORT 250': 0.4, 'SRV 250 AMT': 0.75, 'SRV 600 V': 0.75, 'SRK 800 RR': 0.75},
    price: {'FORT 250': 48000, 'SRV 250 AMT': 90000, 'SRV 600 V': 187500, 'SRK 800 RR': 225000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P Throttle Body',
    hours: {'FORT 250': 0.25, 'SRV 250 AMT': 0.4, 'SRV 600 V': 0.4, 'SRK 800 RR': 0.4},
    price: {'FORT 250': 30000, 'SRV 250 AMT': 48000, 'SRV 600 V': 100000, 'SRK 800 RR': 120000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P Rantai Keteng',
    hours: {'FORT 250': 0.75, 'SRV 250 AMT': 1.25, 'SRV 600 V': 1.5, 'SRK 800 RR': 1.75},
    price: {'FORT 250': 90000, 'SRV 250 AMT': 150000, 'SRV 600 V': 375000, 'SRK 800 RR': 525000}),
  FrtEntry(faultCode: '', category: 'SERVICE', job: 'B/P Crankshaft',
    hours: {'FORT 250': 1.5, 'SRV 250 AMT': 2, 'SRV 600 V': 2.5, 'SRK 800 RR': 3.5},
    price: {'FORT 250': 180000, 'SRV 250 AMT': 240000, 'SRV 600 V': 625000, 'SRK 800 RR': 1050000}),
];
