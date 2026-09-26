import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/session.dart';
import '../standby/standby_repository.dart';
import '../stock/stock_repository.dart';
import 'jadwal_repository.dart';

// Jadwal Bengkel: piket siang kebersihan + standby 12:00-13:00 (check-off)
// + kebersihan pit sore (pindah dari Standby PDI) + kalender roster bulanan.
// Siklus pasangan: (Rangga+Wahyu) <-> (Asahatta+Elvan), Minggu OFF.
class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});
  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  final repo = JadwalRepo();
  final standbyRepo = StandbyRepo();
  final woRepo = StockRepository();
  bool _reminderShown = false;
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => repo.keyOf(DateTime.now());

  String _nama(Map<String, String> names, String email) =>
      names[email] ?? email.split('@').first;

  Color _pairColor(int p) => p == 0
      ? const Color(0xFF1E3A8A)
      : const Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Jadwal Bengkel'),
        backgroundColor: const Color(0xFF1B2A4A), foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: woRepo.watchTeam(),
        builder: (c, teamSnap) {
          final team = teamSnap.data ?? [];
          final names = <String, String>{};
          for (final t in team) {
            names['${t['email']}'] = '${t['nama'] ?? t['email']}';
          }
          return StreamBuilder<Map<String, dynamic>?>(
            stream: standbyRepo.watchDay(_key),
            builder: (c2, daySnap) {
              final day = daySnap.data;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (day != null) _maybeRemind(day);
              });
              return ListView(padding: const EdgeInsets.all(12), children: [
                _kartuSiang(names),
                const SizedBox(height: 10),
                _sectionHead('Jadwal Kebersihan & Pit Sore jam 17:30', 'Senin–Sabtu', const Color(0xFF16A34A)),
                _pitCard(1, day, names),
                _pitCard(2, day, names),
                const SizedBox(height: 10),
                _kalender(names),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _sectionHead(String t, String c, Color col) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
          child: Text(c, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
      ]));
  }

  // ── Piket siang hari ini ──────────────────────────────────────────────
  Widget _kartuSiang(Map<String, String> names) {
    final s = AuthSession.instance;
    final now = DateTime.now();
    final pair = repo.pairOf(now);
    if (pair < 0) {
      return Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16)),
        child: const Column(children: [
          Text('HARI LIBUR', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Minggu — tidak ada piket siang', style: TextStyle(color: Colors.white)),
        ]));
    }
    final emails = repo.pairEmails(now);
    final boleh = emails.contains(s.email) || s.isKepalaMekanik || s.isOps;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.watchSiang(_key),
      builder: (c, snap) {
        final data = snap.data;
        final check = data?['check'];
        final done = check != null;
        return Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: done
              ? [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]),
            border: Border.all(
              color: done ? const Color(0xFF16A34A) : _pairColor(pair), width: 3),
            borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text('Jadwal Standby Bengkel Siang',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B2A4A))),
            const Text('jam 12:00 - 13:00',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: emails.map((e) =>
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Column(children: [
                CircleAvatar(radius: 26, backgroundColor: _pairColor(pair),
                  child: Text(_nama(names, e)[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(height: 4),
                Text(_nama(names, e).split(' ').first,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ]))).toList()),
            const SizedBox(height: 8),
            Text(done ? '✅ Selesai oleh ${check['oleh']} • ${_jam(check['at'])}'
              : 'Belum check-off',
              style: TextStyle(fontSize: 12,
                color: done ? const Color(0xFF16A34A) : Colors.grey)),
            if (!done && boleh) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                onPressed: () => _checkSiang(pair, emails),
                child: const Text('Sudah dibersihkan')),
            ],
          ]));
      },
    );
  }

  Future<void> _checkSiang(int pair, List<String> emails) async {
    try {
      await repo.checkSiang(key: _key, pair: pair, emails: emails);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Piket siang tercatat')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // ── Kalender roster bulanan ───────────────────────────────────────────
  Widget _kalender(Map<String, String> names) {
    final first = DateTime(_bulan.year, _bulan.month, 1);
    final daysInMonth = DateTime(_bulan.year, _bulan.month + 1, 0).day;
    // Senin = kolom 0.
    final lead = (first.weekday - DateTime.monday) % 7;
    final cells = <Widget>[];
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    for (final h in hari) {
      cells.add(Center(child: Text(h,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))));
    }
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    final todayKey = repo.keyOf(DateTime.now());
    for (var d = 1; d <= daysInMonth; d++) {
      final t = DateTime(_bulan.year, _bulan.month, d);
      final p = repo.pairOf(t);
      final isToday = repo.keyOf(t) == todayKey;
      cells.add(GestureDetector(
        onTap: () => _detailHari(t, names),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: p < 0 ? Colors.red.shade50
              : p == 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
            border: Border.all(
              color: isToday ? const Color(0xFFD92028)
                : p < 0 ? Colors.red.shade200 : Colors.grey.shade300,
              width: isToday ? 2 : 1),
            borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$d', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
              color: p < 0 ? Colors.red : null)),
            Text(p < 0 ? 'OFF' : 'P${p + 1}',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                color: p < 0 ? Colors.red : _pairColor(p))),
          ])),
      ));
    }
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() =>
            _bulan = DateTime(_bulan.year, _bulan.month - 1))),
        Text(DateFormat('MMMM yyyy', 'id_ID').format(_bulan),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B2A4A))),
        IconButton(icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() =>
            _bulan = DateTime(_bulan.year, _bulan.month + 1))),
      ]),
      GridView.count(crossAxisCount: 7, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(), children: cells),
      const SizedBox(height: 6),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _LegendWarna(Color(0xFF1E3A8A), 'P1: Rangga+Wahyu'),
        SizedBox(width: 10),
        _LegendWarna(Color(0xFF7C3AED), 'P2: Asahatta+Elvan'),
      ]),
    ])));
  }

  void _detailHari(DateTime t, Map<String, String> names) {
    final p = repo.pairOf(t);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(t),
        style: const TextStyle(fontSize: 14)),
      content: p < 0
        ? const Text('OFF — Minggu libur, jatah piket pindah ke Senin.')
        : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Piket siang 12:00–13:00 (P${p + 1})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...repo.pairEmails(t).map((e) => Text('• ${_nama(names, e)}')),
          ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
    ));
  }

  // ── Penataan Alat & Tools sore (pindah dari Standby PDI) ──────────────
  // Petugas = anggota pit yang TIDAK piket siang hari ini.
  Widget _pitCard(int pit, Map<String, dynamic>? day, Map<String, String> names) {
    final s = AuthSession.instance;
    final info = day?[pit == 1 ? 'pit1' : 'pit2'];
    final done = info != null;
    final petugas = JadwalMath.penataanSore(DateTime.now())[pit];
    final namaPetugas = petugas == null
        ? (pit == 1 ? StandbyRepo.pit1 : StandbyRepo.pit2)
            .map((e) => _nama(names, e).split(' ').first).join(' + ')
        : _nama(names, petugas);
    final telat = _lewat1730() && !done;
    return Card(color: telat ? Colors.red.shade50 : null, child: ListTile(
      leading: Icon(Icons.handyman,
        color: done ? Colors.green : telat ? Colors.red : Colors.grey),
      title: Text('PIT $pit • $namaPetugas${done ? ' ✅' : ''}${telat ? ' • BELUM DITATA' : ''}',
        style: TextStyle(fontWeight: FontWeight.bold,
          color: telat ? Colors.red : null)),
      subtitle: Text(done ? 'Oleh ${info['oleh']} • ${_jam(info['at'])}'
        : 'Penataan alat & tools • sore sebelum tutup',
        style: const TextStyle(fontSize: 11)),
      trailing: !done && (s.isKepalaMekanik || s.isOps || s.role == 'mekanik')
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: () => standbyRepo.pitCheck(key: _key, pit: pit),
              child: const Text('Sudah dibersihkan', style: TextStyle(color: Colors.white)))
          : null,
    ));
  }

  bool _lewat1730() {
    final n = DateTime.now();
    return n.hour > 17 || (n.hour == 17 && n.minute >= 30);
  }

  void _maybeRemind(Map<String, dynamic> day) {
    if (_reminderShown || !_lewat1730() || !mounted) return;
    final s = AuthSession.instance;
    final bengkel = s.isKepalaMekanik || s.role == 'mekanik' || s.isOps;
    if (!bengkel) return;
    if (day['pit1'] == null || day['pit2'] == null) {
      _reminderShown = true;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('⏰ Kebersihan Pit (17:30)'),
        content: const Text('Sudah lewat 17:30 dan ada pit yang belum check-off. '
          'Pastikan pit dibersihkan sebelum tutup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Ingatkan lagi nanti')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              Navigator.pop(context);
              if (day['pit1'] == null) standbyRepo.pitCheck(key: _key, pit: 1);
              if (day['pit2'] == null) standbyRepo.pitCheck(key: _key, pit: 2);
            },
            child: const Text('Sudah dibersihkan', style: TextStyle(color: Colors.white))),
        ],
      ));
    }
  }

  String _jam(dynamic ts) {
    try {
      // ignore: avoid_dynamic_calls
      final d = (ts as dynamic).toDate() as DateTime;
      return DateFormat('HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }
}

class _LegendWarna extends StatelessWidget {
  final Color warna;
  final String label;
  const _LegendWarna(this.warna, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }
}
