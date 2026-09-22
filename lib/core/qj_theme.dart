import 'package:flutter/material.dart';

// Design system QJ Motor — dipakai semua halaman baru.
// Rebrand: merah resmi QJ #D92028 + carbon + paper hangat.
// Merah dipakai hemat (CTA, status aktif, aksen); struktur carbon agar elegan.
class QjColors {
  static const Color red = Color(0xFFD92028);
  static const Color redLight = Color(0xFFF0323B);
  static const Color redDark = Color(0xFFA3121A);
  static const Color navy = Color(0xFF14171C); // carbon (nama dipertahankan agar 30+ file tak berubah)
  static const Color navyDark = Color(0xFF0B0D10);
  static const Color bg = Color(0xFFF5F4F2); // paper hangat
  static const Color card = Colors.white;
  static const Color text = Color(0xFF14171C);
  static const Color muted = Color(0xFF8A8F98);
  static const Color green = Color(0xFF1FA855);
  static const Color orange = Color(0xFFF59E0B);

  // Gradien tombol/hero merah khas QJ.
  static const LinearGradient redGradient = LinearGradient(
    colors: [redLight, red, redDark],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient carbonGradient = LinearGradient(
    colors: [navy, navyDark],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

ThemeData qjTheme() {
  const fadeSlide = FadeUpwardsPageTransitionsBuilder();
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: QjColors.red);
  return base.copyWith(
    scaffoldBackgroundColor: QjColors.bg,
    // Transisi halaman fade-slide 200ms agar tidak kaku (semua platform).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: fadeSlide,
      TargetPlatform.iOS: fadeSlide,
      TargetPlatform.linux: fadeSlide,
      TargetPlatform.macOS: fadeSlide,
      TargetPlatform.windows: fadeSlide,
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: QjColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardTheme(
      color: QjColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: QjColors.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// Kartu menu dengan gradien + ikon — dipakai landing home.
class QjMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const QjMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: gradient.last.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
        ]),
      ),
    );
  }
}

// Kartu statistik — versi hitung tetap + versi count-up animasi.
class QjStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const QjStatCard({super.key, required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: QjColors.muted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class QjStatCardCount extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const QjStatCardCount({super.key, required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          n == null
              ? Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color))
              : TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: n),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text('$v',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
                ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: QjColors.muted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
