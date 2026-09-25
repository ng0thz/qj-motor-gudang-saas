import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/auth_service.dart';
import '../../core/session.dart';
import '../../core/qj_theme.dart';
import '../../core/qj_anim.dart';
import '../standby/standby_repository.dart';
import '../stock/alert_po_page.dart';
import '../stock/closing_report_page.dart';
import '../stock/dashboard_page.dart';
import '../stock/forecast_page.dart';
import '../stock/import_update_page.dart';
import '../stock/label_batch_page.dart';
import '../stock/opname_page.dart';
import '../stock/peralatan_page.dart';
import '../stock/stock_page.dart';
import '../stock/stock_repository.dart';
import '../stock/workorder_page.dart';
import '../stock/workorder_track_page.dart';
import '../stock/pdi_booking_page.dart';
import '../standby/standby_page.dart';
import '../users/users_page.dart';

// Landing home QJ Motor: hero + statistik live + menu animasi.
// Responsif: grid 2 kolom (HP) / 4 kolom (desktop), konten max 1100px.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = StockRepository();
  Map<String, String> stats = {'sku': '—', 'menipis': '—', 'wo': '—', 'habis': '—'};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final all = await repo.fetchAll3000();
      final now = DateTime.now();
      final wos = await repo.fetchWOSince(DateTime(now.year, now.month, now.day));
      if (!mounted) return;
      setState(() => stats = {
            'sku': '${all.length}',
            'menipis': '${all.where((p) => p.stok > 0 && p.stok <= p.minStok).length}',
            'wo': '${wos.length}',
            'habis': '${all.where((p) => p.stok == 0).length}',
          });
    } catch (_) {
      // Offline / belum login penuh: biarkan '—'
    }
  }

  void _go(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, a, __) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: page,
          ),
        ),
        transitionsBuilder: (_, a, __, child) => child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AuthSession.instance;
    final tgl = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.now());
    final menus = [
      ['Stok & Scan', 'Cari, scan, IN/OUT', Icons.qr_code_scanner, [const Color(0xFFE1251B), const Color(0xFFB3120F)], const StockPage()],
      ['Work Order', 'FRT jasa otomatis', Icons.build, [const Color(0xFF1B2A4A), const Color(0xFF2E4A7A)], const WorkOrderPage()],
      ['Tracking', 'Riwayat per nopol', Icons.manage_search, [const Color(0xFF0E7C5B), const Color(0xFF0A5C44)], const WorkOrderTrackPage()],
      if (s.canStandby)
        ['Standby PDI', 'Rotasi + SK + pit', Icons.event_available, [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)], const StandbyPage()],
      if (s.canBookPDI)
        ['Booking PDI', 'Jadwal unit baru', Icons.event_available, [const Color(0xFFDB2777), const Color(0xFF9D174D)], const PdiBookingPage()],
      ['Closing Harian', 'Laporan A–F + WA', Icons.assessment, [const Color(0xFF7C3AED), const Color(0xFF5B21B6)], const ClosingReportPage()],
      ['Opname', 'Hitung + variance', Icons.fact_check, [const Color(0xFF0284C7), const Color(0xFF075985)], const OpnamePage()],
      if (s.canPeralatan)
        ['Peralatan', 'Alat bengkel + cek fisik', Icons.handyman, [const Color(0xFF0F766E), const Color(0xFF134E4A)], const PeralatanPage()],
      ['Alert & PO', 'Stok kritis', Icons.warning_amber_rounded, [const Color(0xFFF59E0B), const Color(0xFFB45309)], const AlertPOPage()],
      ['Forecast', 'Prediksi kebutuhan', Icons.trending_up, [const Color(0xFF059669), const Color(0xFF065F46)], const ForecastPage()],
      ['Dashboard', 'Nilai & analitik', Icons.dashboard, [const Color(0xFF475569), const Color(0xFF1E293B)], const DashboardPage()],
      ['Label Bin', 'Cetak QR per rak', Icons.print, [const Color(0xFF0891B2), const Color(0xFF155E75)], const LabelBatchPage()],
      ['Import Data', 'Update CSV + harga', Icons.upload_file, [const Color(0xFF4D7CFE), const Color(0xFF1D4ED8)], const ImportUpdatePage()],
      if (s.isOps)
        ['Kelola User', 'Buat + atur akses', Icons.people, [const Color(0xFF0F766E), const Color(0xFF134E4A)], const UsersPage()],
    ];

    return Scaffold(
      backgroundColor: QjColors.bg,
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/qj_header_logo.png', height: 26,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.two_wheeler, color: Colors.white, size: 22)),
        ]),
        backgroundColor: QjColors.navy,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Akun',
            icon: const Icon(Icons.account_circle),
            onSelected: (v) async {
              if (v == 'logout') await AuthService().logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.email.isEmpty ? 'Tanpa login' : s.email,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${s.role.isEmpty ? '-' : s.role} • ${s.tenantId}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [
                Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Keluar'),
              ])),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [QjColors.red, Colors.transparent], stops: [0.22, 0.22]))),
        ),
      ),
      body: LayoutBuilder(builder: (c, box) {
        final wide = box.maxWidth >= 1000;
        final cols = wide ? 4 : 2;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              // HERO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [QjColors.navy, QjColors.navyDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 44, height: 4,
                        decoration: BoxDecoration(color: QjColors.red, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 10),
                    Text('Halo, ${s.email.isEmpty ? 'Tim Gudang' : s.email.split('@').first} 👋',
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('$tgl • Tenant ${s.tenantId}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  Image.asset('assets/qj_logo_white.png', width: 180,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.two_wheeler, color: Colors.white, size: 48)),
                ]),
              ),
              // BANNER STANDBY PDI (mekanik) + PIL kebersihan 17:30
              if (s.canStandby) _StandbyBanner(email: s.email),
              if (s.canStandby) const SizedBox(height: 10),
              const SizedBox(height: 4),
              // STATS
              Builder(builder: (c2) {
                final isDash = stats['sku'] == '—';
                return GridView.count(
                  crossAxisCount: wide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: isDash
                      ? List.generate(4, (_) => const ShimmerBox(height: 74, borderRadius: 14))
                      : [
                          QjStatCardCount(value: stats['sku']!, label: 'Total SKU', icon: Icons.inventory_2, color: QjColors.navy),
                          QjStatCardCount(value: stats['wo']!, label: 'WO Hari Ini', icon: Icons.build, color: QjColors.red),
                          QjStatCardCount(value: stats['menipis']!, label: 'Stok Menipis', icon: Icons.warning_amber_rounded, color: QjColors.orange),
                          QjStatCardCount(value: stats['habis']!, label: 'Stok Habis', icon: Icons.remove_shopping_cart, color: QjColors.redDark),
                        ],
                );
              }),
              const SizedBox(height: 14),
              const Text('Menu Operasional', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: QjColors.text)),
              const SizedBox(height: 10),
              // MENU GRID animasi staggered (+ badge di Standby PDI)
              Builder(builder: (c2) {
                final standbyIdx = menus.indexWhere((m) => m[0] == 'Standby PDI');
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: List.generate(menus.length, (i) {
                    final m = menus[i];
                    final card = QjMenuCard(
                      title: m[0] as String,
                      subtitle: m[1] as String,
                      icon: m[2] as IconData,
                      gradient: (m[3] as List<Color>),
                      onTap: () => _go(m[4] as Widget),
                    );
                    if (i == standbyIdx && s.canStandby) {
                      return StaggerIn(
                        index: i,
                        child: _StandbyBadgeWrapper(email: s.email, child: card),
                      );
                    }
                    return StaggerIn(index: i, child: card);
                  }),
                );
              }),
              const SizedBox(height: 20),
              Center(child: Image.asset('assets/qj_header_logo_light.png', height: 18,
                errorBuilder: (_, __, ___) =>
                    const Text('QJ Motor • ALWAYS FORWARD',
                        style: TextStyle(fontSize: 11, color: QjColors.muted, letterSpacing: 2)))),
              const SizedBox(height: 6),
              const Center(
                  child: Text('QJ Motor Adidaya • ALWAYS FORWARD',
                      style: TextStyle(fontSize: 10, color: QjColors.muted, letterSpacing: 1.5))),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Banner Standby di Home ──
class _StandbyBanner extends StatelessWidget {
  final String email;
  const _StandbyBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    final repo = StandbyRepo();
    final key = repo.keyOf(DateTime.now());
    // Minggu: jangan tampilkan banner.
    if (DateTime.now().weekday == DateTime.sunday) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.watchDay(key),
      builder: (c, snap) {
        if (!snap.hasData || snap.data == null) return const SizedBox.shrink();
        final day = snap.data!;
        final dist = List<Map<String, dynamic>>.from(day['distribusi'] ?? []);
        final reqs = List<Map<String, dynamic>>.from(day['requests'] ?? []);
        final selesai = List<String>.from(day['selesai'] ?? []);
        final pit1 = day['pit1'];
        final pit2 = day['pit2'];

        // Hitung jatah user hari ini (reguler + request).
        final myDist = dist.where((d) => '${d['email']}' == email).toList();
        final myReq = reqs.where((q) => '${q['email']}' == email).toList();
        final myUnit = myDist.fold<int>(0, (t, d) => t + ((d['unit'] as num?)?.toInt() ?? 0)) +
            myReq.fold<int>(0, (t, q) => t + ((q['unit'] as num?)?.toInt() ?? 0));
        final isSelesai = selesai.contains(email);
        final isSK = myUnit == 0 && dist.isNotEmpty;
        // Pit milik user.
        final inPit1 = StandbyMath.pit1.contains(email);
        final inPit2 = StandbyMath.pit2.contains(email);
        final pitDone = (inPit1 && pit1 != null) || (inPit2 && pit2 != null);
        final lewat1730 = DateTime.now().hour > 17 || (DateTime.now().hour == 17 && DateTime.now().minute >= 30);

        // Prioritas banner: pit telat > PDI belum selesai > SK.
        if (!pitDone && lewat1730 && (inPit1 || inPit2)) {
          final pitNo = inPit1 ? 1 : 2;
          return _bannerCard(
            color: const Color(0xFFDC2626), icon: Icons.cleaning_services,
            title: 'Pit $pitNo belum dibersihkan!',
            subtitle: 'Sudah 17:30 — tap untuk check-off kebersihan.',
            action: 'Buka Standby',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StandbyPage())),
          );
        }
        if (myUnit > 0 && !isSelesai) {
          return _bannerCard(
            color: QjColors.red, icon: Icons.assignment_late,
            title: 'Anda standby $myUnit unit PDI hari ini',
            subtitle: 'Tap untuk selesaikan — hutang/tabungan diperbarui otomatis.',
            action: 'Kerjakan',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StandbyPage())),
          );
        }
        if (myUnit > 0 && isSelesai) {
          return _bannerCard(
            color: QjColors.green, icon: Icons.verified,
            title: 'PDI hari ini selesai \u2713',
            subtitle: '$myUnit unit — terima kasih!',
            action: 'Lihat',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StandbyPage())),
          );
        }
        if (isSK) {
          return _bannerCard(
            color: const Color(0xFFF59E0B), icon: Icons.moped,
            title: 'Anda Servis Kunjung hari ini',
            subtitle: 'Tidak kebagian PDI — standby kunjungan.',
            action: 'Lihat',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StandbyPage())),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _bannerCard({required Color color, required IconData icon, required String title, required String subtitle, required String action, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: QjColors.muted)),
        ])),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: onTap, child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

// Badge merah di pojok kartu Standby PDI.
class _StandbyBadgeWrapper extends StatelessWidget {
  final String email;
  final Widget child;
  const _StandbyBadgeWrapper({required this.email, required this.child});

  @override
  Widget build(BuildContext context) {
    final repo = StandbyRepo();
    final key = repo.keyOf(DateTime.now());
    if (DateTime.now().weekday == DateTime.sunday) return child;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.watchDay(key),
      builder: (c, snap) {
        if (!snap.hasData || snap.data == null) return child;
        final day = snap.data!;
        final dist = List<Map<String, dynamic>>.from(day['distribusi'] ?? []);
        final reqs = List<Map<String, dynamic>>.from(day['requests'] ?? []);
        final selesai = List<String>.from(day['selesai'] ?? []);
        final myUnit = dist.where((d) => '${d['email']}' == email).fold<int>(0, (t, d) => t + ((d['unit'] as num?)?.toInt() ?? 0)) +
            reqs.where((q) => '${q['email']}' == email).fold<int>(0, (t, q) => t + ((q['unit'] as num?)?.toInt() ?? 0));
        if (myUnit == 0 || selesai.contains(email)) return child;
        return Stack(clipBehavior: Clip.none, children: [
          child,
          Positioned(top: -6, right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: QjColors.red, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: QjColors.red.withOpacity(0.4), blurRadius: 6)]),
              child: Text('$myUnit', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ]);
      },
    );
  }
}
