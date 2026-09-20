import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';

// Forecasting sederhana untuk sparepart bengkel:
// - Rata-rata harian dari OUT 90 hari terakhir (SMA)
// - Proyeksi kebutuhan 30 hari + safety stock (lead time)
// - Estimasi hari stok habis + trend bulan terakhir vs sebelumnya
class ForecastResult {
  final double avgDaily;
  final int forecast30;
  final int safetyStock;
  final int suggestOrder;
  final int daysOfStock;
  final double trendPct; // + naik, - turun, vs 30 hari sebelumnya
  final int out90;
  ForecastResult({
    required this.avgDaily, required this.forecast30, required this.safetyStock,
    required this.suggestOrder, required this.daysOfStock, required this.trendPct, required this.out90,
  });
}

class ForecastService {
  final _fs = FirebaseService.instance;

  Future<ForecastResult> forecastFor(String kode, {required int stokSaatIni, int leadTimeDays = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    final snap = await _fs.col('stock_movements')
        .where('kode_part', isEqualTo: kode)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    int out90 = 0;
    int out30 = 0;
    int outPrev30 = 0; // hari 31-60 untuk trend
    final day30 = now.subtract(const Duration(days: 30));
    final day60 = now.subtract(const Duration(days: 60));
    for (final d in snap.docs) {
      final m = d.data();
      if (m['tipe'] != 'OUT') continue;
      final ts = m['timestamp'];
      if (ts == null) continue;
      final t = (ts as Timestamp).toDate();
      final qty = (m['qty'] ?? 0) as int;
      out90 += qty;
      if (t.isAfter(day30)) out30 += qty;
      else if (t.isAfter(day60)) outPrev30 += qty;
    }

    final avgDaily = out90 / 90.0;
    final forecast30 = (avgDaily * 30).round();
    final safetyStock = (avgDaily * leadTimeDays * 0.5).ceil();
    final need = forecast30 + safetyStock - stokSaatIni;
    final daysOfStock = avgDaily <= 0 ? 9999 : (stokSaatIni / avgDaily).floor();
    double trendPct = 0;
    if (outPrev30 > 0) {
      trendPct = ((out30 - outPrev30) / outPrev30) * 100;
    } else if (out30 > 0) {
      trendPct = 100;
    }

    return ForecastResult(
      avgDaily: avgDaily,
      forecast30: forecast30,
      safetyStock: safetyStock,
      suggestOrder: need > 0 ? need : 0,
      daysOfStock: daysOfStock,
      trendPct: trendPct,
      out90: out90,
    );
  }
}
