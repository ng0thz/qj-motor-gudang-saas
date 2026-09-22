import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/auth_service.dart';
import '../../core/session.dart';
import '../../core/qj_theme.dart';
import '../../core/qj_anim.dart';
import '../stock/alert_po_page.dart';
import '../stock/closing_report_page.dart';
import '../stock/dashboard_page.dart';
import '../stock/forecast_page.dart';
import '../stock/import_update_page.dart';
import '../stock/label_batch_page.dart';
import '../stock/opname_page.dart';
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
      if (s.canBookPDI && kIsWeb)
        ['Booking PDI', 'Jadwal unit baru (Web)', Icons.event_available, [const Color(0xFFDB2777), const Color(0xFF9D174D)], const PdiBookingPage()],
      ['Closing Harian', 'Laporan A–F + WA', Icons.assessment, [const Color(0xFF7C3AED), const Color(0xFF5B21B6)], const ClosingReportPage()],
      ['Opname', 'Hitung + variance', Icons.fact_check, [const Color(0xFF0284C7), const Color(0xFF075985)], const OpnamePage()],
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
              const SizedBox(height: 14),
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
              // MENU GRID animasi staggered
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: List.generate(menus.length, (i) {
                  final m = menus[i];
                  return StaggerIn(
                    index: i,
                    child: QjMenuCard(
                      title: m[0] as String,
                      subtitle: m[1] as String,
                      icon: m[2] as IconData,
                      gradient: (m[3] as List<Color>),
                      onTap: () => _go(m[4] as Widget),
                    ),
                  );
                }),
              ),
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
