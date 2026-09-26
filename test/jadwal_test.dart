import 'package:flutter_test/flutter_test.dart';
import 'package:gudang_saas/features/jadwal/jadwal_repository.dart'
    show JadwalMath;

void main() {
  test('Jumat 25 Sep 2026 = Pair 0 (Rangga+Wahyu)', () {
    expect(JadwalMath.pairOf(DateTime(2026, 9, 25)), 0);
    expect(JadwalMath.pairEmails(DateTime(2026, 9, 25)),
        ['ranggaadisaputra024@gmail.com', 'wahyusurya16@icloud.com']);
  });
  test('Sabtu 26 Sep 2026 = Pair 1 (Asahatta+Elvan)', () {
    expect(JadwalMath.pairOf(DateTime(2026, 9, 26)), 1);
  });
  test('Minggu 27 Sep 2026 = OFF (-1)', () {
    expect(JadwalMath.pairOf(DateTime(2026, 9, 27)), -1);
    expect(JadwalMath.pairEmails(DateTime(2026, 9, 27)), isEmpty);
  });
  test('Senin 28 Sep memakai jatah Minggu = Pair 0', () {
    expect(JadwalMath.pairOf(DateTime(2026, 9, 28)), 0);
  });
  test('29 Sep = Pair 1, 30 Sep = Pair 0', () {
    expect(JadwalMath.pairOf(DateTime(2026, 9, 29)), 1);
    expect(JadwalMath.pairOf(DateTime(2026, 9, 30)), 0);
  });
  test('Oktober lanjutan: 1 Okt = Pair 1, 2 Okt = Pair 0', () {
    expect(JadwalMath.pairOf(DateTime(2026, 10, 1)), 1);
    expect(JadwalMath.pairOf(DateTime(2026, 10, 2)), 0);
    expect(JadwalMath.pairOf(DateTime(2026, 10, 3)), 1);
  });
  test('Jumat 25 Sep (P0): Pit 1 = Asahatta, Pit 2 = Elvan', () {
    final m = JadwalMath.penataanSore(DateTime(2026, 9, 25));
    expect(m[1], 'deejayasa63@gmail.com');
    expect(m[2], 'elvanpramudiansyah@gmail.com');
  });
  test('Sabtu 26 Sep (P1): Pit 1 = Wahyu, Pit 2 = Rangga', () {
    final m = JadwalMath.penataanSore(DateTime(2026, 9, 26));
    expect(m[1], 'wahyusurya16@icloud.com');
    expect(m[2], 'ranggaadisaputra024@gmail.com');
  });
  test('Minggu penataan kosong (OFF)', () {
    expect(JadwalMath.penataanSore(DateTime(2026, 9, 27)), isEmpty);
  });
  test('Batas sore: Jumat 17:30, Sabtu 15:30, Minggu kosong', () {
    expect(JadwalMath.batasSore(DateTime(2026, 9, 25)), '17:30');
    expect(JadwalMath.batasSore(DateTime(2026, 9, 26)), '15:30');
    expect(JadwalMath.batasSore(DateTime(2026, 9, 27)), '');
    expect(JadwalMath.batasSore(DateTime(2026, 9, 28)), '17:30');
  });
  test('Minggu 4 Okt OFF, Senin 5 Okt = Pair 0', () {
    expect(JadwalMath.pairOf(DateTime(2026, 10, 4)), -1);
    expect(JadwalMath.pairOf(DateTime(2026, 10, 5)), 0);
    expect(JadwalMath.pairOf(DateTime(2026, 10, 6)), 1);
  });
}
