import 'package:flutter_test/flutter_test.dart';
import 'package:gudang_saas/features/standby/standby_repository.dart'
    show StandbyMath;

void main() {
  const d = 'deejayasa63@gmail.com';
  const a = 'wahyusurya16@icloud.com';
  const b = 'ranggaadisaputra024@gmail.com';

  test('jangkar Senin 21 Sep 2026 = D (Asahatta)', () {
    expect(StandbyMath.rotasiHariIni(DateTime(2026, 9, 21)),
        [d, a, b, 'elvanpramudiansyah@gmail.com']);
  });
  test('Selasa 22 Sep 2026 = A dulu', () {
    expect(StandbyMath.rotasiHariIni(DateTime(2026, 9, 22)).first, a);
  });
  test('4 unit dibagi D:3 A:1', () {
    final o = StandbyMath.distribute(
        units: 4, tab: {}, hutang: {}, now: DateTime(2026, 9, 21));
    final m = {for (final x in (o['dist'] as List)) x['email']: x['unit']};
    expect(m[d], 3);
    expect(m[a], 1);
  });
  test('tabungan dipakai duluan', () {
    final o = StandbyMath.distribute(
        units: 4, tab: {a: 2}, hutang: {}, now: DateTime(2026, 9, 22));
    final dist = o['dist'] as List;
    expect(dist.first['email'], a);
    expect(dist.first['dariTabungan'], true);
  });
  test('hutang 2 memangkas jatah jadi 1 dan lunas', () {
    final o = StandbyMath.distribute(
        units: 4, tab: {}, hutang: {d: 2}, now: DateTime(2026, 9, 21));
    final m = {for (final x in (o['dist'] as List)) x['email']: x['unit']};
    expect(m[d], 1);
    expect((o['hutangBaru'] as Map)[d], 0);
  });
  test('hutang 5: jatah 0, sisa 2', () {
    final o = StandbyMath.distribute(
        units: 4, tab: {}, hutang: {d: 5}, now: DateTime(2026, 9, 21));
    final m = {for (final x in (o['dist'] as List)) x['email']: (x['unit'] as int)};
    expect(m[d] ?? 0, 0);
    expect((o['hutangBaru'] as Map)[d], 2);
  });
  test('kurang dari 3 menabung (tanpa utang)', () {
    final o = StandbyMath.distribute(
        units: 4, tab: {}, hutang: {}, now: DateTime(2026, 9, 21));
    expect((o['tabBaru'] as Map)[a], 2); // A dapat 1 -> tabung 2
  });
}
