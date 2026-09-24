import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/session.dart';
import '../stock/stock_repository.dart';
import 'standby_repository.dart';

class StandbyPage extends StatefulWidget {
  const StandbyPage({super.key});
  @override
  State<StandbyPage> createState() => _StandbyPageState();
}

class _StandbyPageState extends State<StandbyPage> {
  final repo = StandbyRepo();
  final woRepo = StockRepository();
  bool _reminderShown = false;
  bool _notifShown = false;
  final Map<String, Map<String, dynamic>> _woCache = {};

  bool get _isMinggu => DateTime.now().weekday == DateTime.sunday;
  String get _key => repo.keyOf(DateTime.now());

  String _nama(Map<String, String> names, String email) =>
      names[email] ?? email.split('@').first;

  @override
  Widget build(BuildContext context) {
    final s = AuthSession.instance;
    if (_isMinggu) {
      return Scaffold(
        backgroundColor: const Color(0xFFDC2626),
        body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('HARI LIBUR', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          Text('Semua mekanik OFF — Tidak ada jadwal', style: TextStyle(color: Colors.white, fontSize: 18)),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Standby PDI • ${DateFormat('EEEE d/MM', 'id_ID').format(DateTime.now())}'),
        backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'History', icon: const Icon(Icons.history),
            onPressed: () => _history()),
          if (s.isOps) IconButton(tooltip: 'Generate / ubah unit',
            icon: const Icon(Icons.refresh), onPressed: () => _generate()),
        ],
      ),
      floatingActionButton: (s.canBookPDI)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
              onPressed: () => _request(),
              icon: const Icon(Icons.add), label: const Text('PDI Request'))
          : null,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: repo.watchDay(_key),
        builder: (c, snap) {
          if (!snap.hasData || snap.data == null) return _emptyDay(s);
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: woRepo.watchTeam(),
            builder: (c2, teamSnap) {
              final team = teamSnap.data ?? [];
              final names = <String, String>{};
              for (final t in team) {
                names['${t['email']}'] = '${t['nama'] ?? t['email']}';
              }
              return _board(s, snap.data!, names);
            },
          );
        },
      ),
    );
  }

  Widget _emptyDay(AuthSession s) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.event_available, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Belum ada jadwal standby hari ini.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Ops tekan Generate (icon refresh) — unit otomatis = antrean PDI.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        if (s.isOps) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            onPressed: () => _generate(),
            icon: const Icon(Icons.bolt), label: const Text('Generate Sekarang')),
        ],
      ])));
  }

  Widget _board(AuthSession s, Map<String, dynamic> day, Map<String, String> names) {
    final dist = List<Map<String, dynamic>>.from(day['distribusi'] ?? []);
    final reqs = List<Map<String, dynamic>>.from(day['requests'] ?? []);
    final selesai = List<String>.from(day['selesai'] ?? []);
    final tab = Map<String, dynamic>.from(day['tabungan'] ?? {});
    final hut = Map<String, dynamic>.from(day['hutang'] ?? {});
    final units = (day['units'] as num?)?.toInt() ?? 0;
    final me = s.email;

    final distEmails = dist.map((d) => '${d['email']}').toSet();
    final skEmails = StandbyRepo.rotasiEmail.where((e) => !distEmails.contains(e)).toList();

    // Kumpulkan semua WO IDs untuk fetch status.
    final allWoIds = <String>{};
    for (final d in dist) {
      allWoIds.addAll(((d['woIds'] as List?) ?? []).cast<String>());
    }
    for (final q in reqs) {
      allWoIds.addAll(((q['woIds'] as List?) ?? []).cast<String>());
    }
    _loadWOStatuses(allWoIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRemind(day);
      _maybeNotifyPDI(dist, reqs, me);
    });

    return ListView(padding: const EdgeInsets.all(12), children: [
      // Notifikasi in-app: PDI baru menunggu diambil.
      ..._notifBanner(dist, reqs, me, names),
      // HERO utama
      if (dist.isNotEmpty) _hero(s, dist.first, selesai, names, tab, hut, me),
      if (dist.length > 1) ...[
        const SizedBox(height: 10),
        ...dist.skip(1).map((d) => _tambahan(s, d, selesai, names, me)),
      ],
      if (units == 0 && dist.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(16),
          child: Text('Tidak ada PDI reguler hari ini.', style: TextStyle(color: Colors.grey)))),
      // Request khusus
      if (reqs.isNotEmpty) ...[
        const SizedBox(height: 10),
        _sectionHead('🟣 PDI KHUSUS / REQUEST', '${reqs.fold<int>(0, (t, q) => t + ((q['unit'] as num?)?.toInt() ?? 0))} unit', const Color(0xFF7C3AED)),
        ...reqs.map((q) => _requestCard(s, q, selesai, names, me)),
      ],
      const SizedBox(height: 10),
      _sectionHead('🟠 SERVIS KUNJUNG', '${skEmails.length} mekanik', const Color(0xFFF59E0B)),
      skEmails.isEmpty
          ? const Card(child: Padding(padding: EdgeInsets.all(12),
              child: Text('Semua mekanik pegang PDI.', style: TextStyle(color: Colors.grey))))
          : Wrap(spacing: 8, runSpacing: 8, children: skEmails.map((e) {
              final sk = Map<String, dynamic>.from(day['sk'] ?? {});
              final st = '${sk[e] ?? ''}';
              final mine = e == me;
              final boleh = mine || s.isKepalaMekanik || s.isOps;
              return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                CircleAvatar(backgroundColor: const Color(0xFFF59E0B),
                  child: Text(_nama(names, e)[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(height: 6),
                Text(_nama(names, e), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if ((tab[e] ?? 0) > 0) Chip(label: Text('Tabungan ${tab[e]}'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.green.shade100,
                  labelStyle: const TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Text(st == 'jalan' ? '🛵 Sedang jalan' : st == 'kembali' ? '✅ Kembali' : 'Standby',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (boleh) TextButton(
                  onPressed: () => repo.skStatus(
                    key: _key, email: e, status: st == 'jalan' ? 'kembali' : 'jalan'),
                  child: Text(st == 'jalan' ? 'Tandai kembali' : 'Berangkat')),
              ])));
            }).toList()),
      const SizedBox(height: 10),
      _sectionHead('🟢 KEBERSIHAN PIT — SORE', 'Senin–Sabtu', const Color(0xFF16A34A)),
      _pitCard(1, day, names, s),
      _pitCard(2, day, names, s),
      const SizedBox(height: 10),
      _nextStrip(names, tab),
      const SizedBox(height: 10),
      _saldo(tab, hut, names),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IN-APP NOTIFICATION (gratis, tanpa FCM/Blaze)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadWOStatuses(Set<String> ids) async {
    for (final id in ids) {
      if (_woCache.containsKey(id)) continue;
      try {
        final snap = await woRepo.streamWODoc(id).first;
        if (snap.exists && snap.data() != null) {
          _woCache[id] = snap.data()!;
        }
      } catch (_) {}
    }
  }

  void _maybeNotifyPDI(List<Map<String, dynamic>> dist, List<Map<String, dynamic>> reqs, String me) {
    if (_notifShown || !mounted) return;
    // Cari WO OPEN yang ditugaskan ke saya.
    final myOpenWo = <String>[];
    for (final d in dist) {
      if ('${d['email']}' != me) continue;
      for (final id in ((d['woIds'] as List?) ?? []).cast<String>()) {
        final wo = _woCache[id];
        if (wo != null && '${wo['status']}'.toUpperCase() == 'OPEN') {
          myOpenWo.add(id);
        }
      }
    }
    for (final q in reqs) {
      if ('${q['email']}' != me) continue;
      for (final id in ((q['woIds'] as List?) ?? []).cast<String>()) {
        final wo = _woCache[id];
        if (wo != null && '${wo['status']}'.toUpperCase() == 'OPEN') {
          myOpenWo.add(id);
        }
      }
    }
    if (myOpenWo.isEmpty) return;
    _notifShown = true;
    // Tampilkan dialog notifikasi in-app.
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('📥 PDI Baru untuk Anda!', style: TextStyle(color: Color(0xFFDC2626))),
      content: Text('Anda memiliki ${myOpenWo.length} unit PDI yang menunggu diambil.\n\n'
        'Tekan tombol "📥 Ambil PDI" untuk memulai pengerjaan.\n'
        'Durasi pengerjaan akan tercatat otomatis.'),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Lihat Papan', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  List<Widget> _notifBanner(List<Map<String, dynamic>> dist, List<Map<String, dynamic>> reqs,
      String me, Map<String, String> names) {
    int openCount = 0;
    for (final d in dist) {
      if ('${d['email']}' != me) continue;
      for (final id in ((d['woIds'] as List?) ?? []).cast<String>()) {
        final wo = _woCache[id];
        if (wo != null && '${wo['status']}'.toUpperCase() == 'OPEN') openCount++;
      }
    }
    for (final q in reqs) {
      if ('${q['email']}' != me) continue;
      for (final id in ((q['woIds'] as List?) ?? []).cast<String>()) {
        final wo = _woCache[id];
        if (wo != null && '${wo['status']}'.toUpperCase() == 'OPEN') openCount++;
      }
    }
    if (openCount == 0) return [];
    return [
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)]),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📥 $openCount PDI baru menunggu diambil!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('Tap tombol "Ambil PDI" di kartu Anda untuk mulai.',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text('$openCount', style: const TextStyle(color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold, fontSize: 18))),
        ])),
      const SizedBox(height: 10),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AMBIL PDI + DURASI
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _ambilPDI(List<String> woIds) async {
    if (woIds.isEmpty) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('📥 Ambil PDI', style: TextStyle(color: Color(0xFF1E3A8A))),
      content: Text('Ambil ${woIds.length} unit PDI?\n\n'
        'Durasi pengerjaan mulai dihitung sekarang.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('📥 Ambil Sekarang', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true || !mounted) return;
    var n = 0;
    for (final id in woIds) {
      try {
        final r = await woRepo.ambilPDI(id);
        if (r == 'ok') n++;
      } catch (_) {}
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(n > 0 ? '✅ $n PDI diambil — durasi mulai dihitung' : 'Sudah diambil sebelumnya')));
  }

  String _durasiStr(Map<String, dynamic>? wo) {
    if (wo == null) return '';
    final ambilAt = wo['ambilAt'];
    if (ambilAt == null) return '';
    try {
      final ambilDt = (ambilAt as dynamic).toDate() as DateTime;
      final selesaiAt = wo['selesaiAt'];
      final endDt = selesaiAt != null ? (selesaiAt as dynamic).toDate() as DateTime : DateTime.now();
      final menit = endDt.difference(ambilDt).inMinutes;
      if (menit < 60) return '$menit m';
      return '${menit ~/ 60}j ${menit % 60}m';
    } catch (_) {
      return '';
    }
  }

  // Ambil semua WO IDs untuk satu email dari distribusi + requests.
  List<String> _woIdsForEmail(Map<String, dynamic> day, String email) {
    final dist = List<Map<String, dynamic>>.from(day['distribusi'] ?? []);
    final reqs = List<Map<String, dynamic>>.from(day['requests'] ?? []);
    final ids = <String>[];
    for (final d in dist.where((e) => '${e['email']}' == email)) {
      ids.addAll(((d['woIds'] as List?) ?? []).cast<String>());
    }
    for (final q in reqs.where((e) => '${e['email']}' == email)) {
      ids.addAll(((q['woIds'] as List?) ?? []).cast<String>());
    }
    return ids;
  }

  // Status gabungan dari semua WO untuk satu mekanik.
  String _combinedStatus(List<String> woIds) {
    if (woIds.isEmpty) return 'OPEN';
    var hasOpen = false;
    var hasProses = false;
    for (final id in woIds) {
      final wo = _woCache[id];
      if (wo == null) { hasOpen = true; continue; }
      final st = '${wo['status']}'.toUpperCase();
      if (st == 'OPEN') hasOpen = true;
      if (st == 'PROSES') hasProses = true;
    }
    if (hasProses) return 'PROSES';
    if (hasOpen) return 'OPEN';
    return 'SELESAI';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

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

  bool _bolehSelesai(AuthSession s, String email) =>
      email == s.email || s.isKepalaMekanik || s.isOps;

  Widget _hero(AuthSession s, Map<String, dynamic> d, List<String> selesai,
      Map<String, String> names, Map<String, dynamic> tab, Map<String, dynamic> hut, String me) {
    final email = '${d['email']}';
    final done = selesai.contains(email);
    final unit = (d['unit'] as num?)?.toInt() ?? 0;
    final h = ((hut[email] as num?)?.toInt() ?? 0);
    final woIds = _woIdsForEmail({'distribusi': [d]}, email);
    final status = _combinedStatus(woIds);
    final durasi = _durasiStr(_woCache.isNotEmpty ? _woCache[woIds.firstOrNull ?? ''] : null);
    final isAmbil = status == 'PROSES';

    return Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: done
          ? [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]
          : isAmbil
            ? [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)]
            : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]),
        border: Border.all(
          color: done ? const Color(0xFF16A34A) : isAmbil ? const Color(0xFFF59E0B) : const Color(0xFF93C5FD),
          width: 4),
        borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        CircleAvatar(radius: 40,
          backgroundColor: done ? const Color(0xFF16A34A) : isAmbil ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
          child: Text(_nama(names, email)[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Text('${_nama(names, email)}${done ? ' ✅' : isAmbil ? ' ⏱' : ''}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
        Text('$unit unit PDI${d['dariTabungan'] == true ? ' (dari tabungan)' : ''}'
          '${h > 0 ? ' • hutang $h' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
        if (durasi.isNotEmpty && isAmbil)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('⏱ Durasi: $durasi',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontSize: 13))),
        const SizedBox(height: 12),
        if (_bolehSelesai(s, email) && !done && status == 'OPEN')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
            onPressed: () => _ambilPDI(woIds),
            child: const Text('📥 Ambil PDI', style: TextStyle(fontSize: 16))),
        if (_bolehSelesai(s, email) && !done && isAmbil)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
            onPressed: () => _complete(email),
            child: const Text('✓ Selesai PDI', style: TextStyle(fontSize: 16))),
        if (done)
          const Text('✅ PDI Selesai', style: TextStyle(fontSize: 14, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
      ]));
  }

  Widget _tambahan(AuthSession s, Map<String, dynamic> d, List<String> selesai,
      Map<String, String> names, String me) {
    final email = '${d['email']}';
    final done = selesai.contains(email);
    final woIds = _woIdsForEmail({'distribusi': [d]}, email);
    final status = _combinedStatus(woIds);
    final durasi = _durasiStr(_woCache.isNotEmpty ? _woCache[woIds.firstOrNull ?? ''] : null);
    final isAmbil = status == 'PROSES';

    return Card(child: ListTile(
      leading: CircleAvatar(
        backgroundColor: done ? const Color(0xFF16A34A) : isAmbil ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B),
        child: Text(_nama(names, email)[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      title: Text('${_nama(names, email)}${done ? ' ✅' : isAmbil ? ' ⏱' : ''}',
        style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${d['unit']} unit PDI${d['dariTabungan'] == true ? ' (dari tabungan)' : ''}'
        '${durasi.isNotEmpty && isAmbil ? ' • Durasi: $durasi' : ''}'),
      trailing: _bolehSelesai(s, email)
          ? (done ? null : (status == 'OPEN'
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  onPressed: () => _ambilPDI(woIds),
                  child: const Text('📥 Ambil'))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                  onPressed: () => _complete(email),
                  child: const Text('✓ Selesai'))))
          : null,
    ));
  }

  Widget _requestCard(AuthSession s, Map<String, dynamic> q, List<String> selesai,
      Map<String, String> names, String me) {
    final email = '${q['email']}';
    final woIds = ((q['woIds'] as List?) ?? []).cast<String>();
    final status = _combinedStatus(woIds);
    final durasi = _durasiStr(_woCache.isNotEmpty ? _woCache[woIds.firstOrNull ?? ''] : null);
    final isAmbil = status == 'PROSES';
    return Card(color: const Color(0xFFEDE9FE), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF7C3AED),
        child: Icon(isAmbil ? Icons.timer : Icons.star, color: Colors.white, size: 20)),
      title: Text('${q['nama'] ?? _nama(names, email)} • ${q['unit']} unit request'
        '${isAmbil ? ' ⏱' : ''}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('${q['ket'] ?? ''}\n+${q['unit']} hutang tabungan'
        '${durasi.isNotEmpty ? '\n⏱ Durasi: $durasi' : ''}'.trim(),
        style: const TextStyle(fontSize: 11)),
      isThreeLine: true,
      trailing: _bolehSelesai(s, email)
          ? (status == 'OPEN'
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  onPressed: () => _ambilPDI(woIds), child: const Text('📥 Ambil'))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                  onPressed: () => _complete(email), child: const Text('✓ Selesai')))
          : null,
    ));
  }

  Widget _pitCard(int pit, Map<String, dynamic> day, Map<String, String> names, AuthSession s) {
    final info = day[pit == 1 ? 'pit1' : 'pit2'];
    final done = info != null;
    final anggota = (pit == 1 ? StandbyRepo.pit1 : StandbyRepo.pit2)
        .map((e) => _nama(names, e).split(' ').first).join(' + ');
    final telat = _lewat1730() && !done;
    return Card(color: telat ? Colors.red.shade50 : null, child: ListTile(
      leading: Icon(Icons.cleaning_services,
        color: done ? Colors.green : telat ? Colors.red : Colors.grey),
      title: Text('PIT $pit • $anggota${done ? ' ✅' : ''}${telat ? ' • BELUM DIBERSIHKAN' : ''}',
        style: TextStyle(fontWeight: FontWeight.bold,
          color: telat ? Colors.red : null)),
      subtitle: Text(done ? 'Oleh ${info['oleh']} • ${_jam(info['at'])}' : 'Sore sebelum tutup',
        style: const TextStyle(fontSize: 11)),
      trailing: !done && (s.isKepalaMekanik || s.isOps || s.role == 'mekanik')
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: () => repo.pitCheck(key: _key, pit: pit),
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
              if (day['pit1'] == null) repo.pitCheck(key: _key, pit: 1);
              if (day['pit2'] == null) repo.pitCheck(key: _key, pit: 2);
            },
            child: const Text('Sudah dibersihkan', style: TextStyle(color: Colors.white))),
        ],
      ));
    }
  }

  Widget _nextStrip(Map<String, String> names, Map<String, dynamic> tab) {
    final now = DateTime.now();
    final items = <Widget>[];
    var offset = 0;
    while (items.length < 4 && offset < 8) {
      final t = now.add(Duration(days: offset));
      if (t.weekday == DateTime.sunday) { offset++; continue; }
      final idx = (repo.rotasiHariIni(t)).first;
      items.add(ListTile(dense: true,
        leading: CircleAvatar(backgroundColor: const Color(0xFF0891B2),
          child: Text(_nama(names, idx)[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(_nama(names, idx), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(offset == 0 ? 'Hari ini' :
          DateFormat('EEEE d/MM', 'id_ID').format(t)),
        trailing: ((tab[idx] as num?)?.toInt() ?? 0) > 0
            ? Chip(label: Text('+${tab[idx]} tabungan'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.green.shade100,
                labelStyle: const TextStyle(fontSize: 10))
            : null,
      ));
      offset++;
    }
    return Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text('📅 NEXT — Giliran Berikutnya',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E7490)))),
      ...items,
      const SizedBox(height: 8),
    ]));
  }

  Widget _saldo(Map<String, dynamic> tab, Map<String, dynamic> hut, Map<String, String> names) {
    final parts = <String>[];
    for (final e in StandbyRepo.rotasiEmail) {
      final t = (tab[e] as num?)?.toInt() ?? 0;
      final h = (hut[e] as num?)?.toInt() ?? 0;
      if (t > 0) parts.add('${_nama(names, e).split(' ').first}: +$t tabungan');
      if (h > 0) parts.add('${_nama(names, e).split(' ').first}: −$h hutang');
    }
    return Card(child: Padding(padding: const EdgeInsets.all(14),
      child: Text(parts.isEmpty ? 'Saldo tabungan/hutang: —' : 'Saldo: ${parts.join(' • ')}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
          color: Color(0xFF1E3A8A)))));
  }

  String _jam(dynamic ts) {
    try {
      final d = (ts as dynamic).toDate() as DateTime;
      return DateFormat('HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, String>?> _inputRangkaMesinPerUnit(String nama) async {
    final rangkaCtrl = TextEditingController();
    final mesinCtrl = TextEditingController();
    final ok1 = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('Selesai PDI — $nama', style: const TextStyle(fontSize: 14)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: rangkaCtrl, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'No. Rangka *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: mesinCtrl, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'No. Mesin *', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lanjut')),
      ],
    ));
    if (ok1 != true) return null;
    final rangka = rangkaCtrl.text.trim().toUpperCase();
    final mesin = mesinCtrl.text.trim().toUpperCase();
    if (rangka.isEmpty || mesin.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rangka & Mesin wajib diisi.')));
      return _inputRangkaMesinPerUnit(nama);
    }
    final ok2 = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Konfirmasi 1/2', style: TextStyle(fontSize: 14)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rangka: $rangka', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Mesin: $mesin', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Sudah benar?', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Perbaiki')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Benar')),
      ],
    ));
    if (ok2 != true) return _inputRangkaMesinPerUnit(nama);
    final verifyCtrl = TextEditingController();
    final ok3 = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Verifikasi 2/2', style: TextStyle(fontSize: 14)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Ketik ulang No. Rangka:', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        TextField(controller: verifyCtrl, autofocus: true, textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: rangka, border: const OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () {
          final v = verifyCtrl.text.trim().toUpperCase();
          Navigator.pop(context, v == rangka);
        }, child: const Text('Verifikasi')),
      ],
    ));
    if (ok3 != true) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifikasi gagal — ulangi.')));
      return _inputRangkaMesinPerUnit(nama);
    }
    return {'noRangka': rangka, 'noMesin': mesin};
  }

  Future<void> _complete(String email) async {
    final snap = await repo.watchDay(_key).first;
    if (snap == null) return;
    final dist = List<Map<String, dynamic>>.from(snap['distribusi'] ?? []);
    final reqs = List<Map<String, dynamic>>.from(snap['requests'] ?? []);
    final woIds = <String>[];
    for (final d in dist.where((e) => '${e['email']}' == email)) {
      woIds.addAll(((d['woIds'] as List?) ?? []).cast<String>());
    }
    for (final q in reqs.where((e) => '${e['email']}' == email)) {
      woIds.addAll(((q['woIds'] as List?) ?? []).cast<String>());
    }
    if (woIds.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada WO PDI untuk diselesaikan.')));
      return;
    }
    final selesai = List<String>.from(snap['selesai'] ?? []);
    if (selesai.contains(email)) {
      try {
        await repo.batalSelesai(key: _key, email: email);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dibatalkan.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
      return;
    }
    final perWo = <String, Map<String, String>>{};
    for (final id in woIds) {
      try {
        final wo = await woRepo.streamWODoc(id).first;
        if (wo.data()?['status'] == 'SELESAI') continue;
      } catch (_) {}
      final data = await _inputRangkaMesinPerUnit(email.split('@').first);
      if (data == null) return;
      perWo[id] = data;
    }
    if (perWo.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua WO sudah selesai.')));
      return;
    }
    try {
      final n = await repo.completeMekanikWithRangka(key: _key, email: email, perWo: perWo);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $n PDI selesai — rangka/mesin tercatat')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _generate() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Generate standby hari ini'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Kosongkan = otomatis sejumlah antrean PDI.',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(controller: ctrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Unit manual (opsional)',
            border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
      ],
    ));
    if (ok != true || !mounted) return;
    try {
      final u = int.tryParse(ctrl.text.trim());
      await repo.generateDay(unitsOverride: u);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal standby dibuat')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _request() async {
    String? email;
    final unitCtrl = TextEditingController(text: '1');
    final ketCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('🟣 Tambah PDI Request', style: TextStyle(color: Color(0xFF7C3AED))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: woRepo.watchTeam(),
            builder: (c2, s2) {
              final meks = (s2.data ?? []).where((t) =>
                t['role'] == 'mekanik' || t['role'] == 'kepala_mekanik').toList();
              return DropdownButtonFormField<String>(
                value: email,
                decoration: const InputDecoration(
                  labelText: 'Pilih mekanik', border: OutlineInputBorder()),
                items: meks.map((m) => DropdownMenuItem(
                  value: '${m['email']}', child: Text('${m['nama']}', style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setD(() => email = v),
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(controller: unitCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah unit',
              helperText: 'Memotong antrean + tercatat hutang',
              border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: ketCtrl,
            decoration: const InputDecoration(labelText: 'Keterangan (opsional)',
              border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tambah', style: TextStyle(color: Colors.white))),
        ],
      )));
    if (ok != true || email == null || !mounted) return;
    try {
      final team = await woRepo.watchTeam().first;
      final m = team.firstWhere((t) => t['email'] == email, orElse: () => {});
      await repo.requestUnits(
        email: email!, nama: '${m['nama'] ?? email}',
        unit: int.tryParse(unitCtrl.text) ?? 1, ket: ketCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request ditambahkan + hutang tercatat')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _history() async {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('📜 History Standby (30 hari)'),
      content: SizedBox(width: 420, height: 380, child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.watchHistory(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const Center(child: Text('Belum ada history.'));
          return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
            final h = s.data![i];
            final dist = List<Map<String, dynamic>>.from(h['distribusi'] ?? []);
            return ListTile(dense: true,
              title: Text('${h['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(dist.map((d) =>
                '${(d['nama'] ?? '').toString().split(' ').first} ${d['unit']}').join(', '),
                style: const TextStyle(fontSize: 11)),
              trailing: Text('${h['units'] ?? 0} unit', style: const TextStyle(fontSize: 11)),
            );
          });
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
    ));
  }
}
