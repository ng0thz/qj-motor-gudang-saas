import 'package:flutter/material.dart';

// Design system QJ Motor — dipakai semua halaman baru.
// Prinsip: premium gelap + aksen merah QJ, kartu putih radius besar,
// hierarki tegas (angka besar, label kecil abu-abu).
class QjColors {
  static const Color red = Color(0xFFE1251B);
  static const Color redDark = Color(0xFFB3120F);
  static const Color navy = Color(0xFF1B2A4A);
  static const Color navyDark = Color(0xFF101B31);
  static const Color bg = Color(0xFFF4F6F9);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF1B2A4A);
  static const Color muted = Color(0xFF8A94A6);
  static const Color green = Color(0xFF1FA855);
  static const Color orange = Color(0xFFF59E0B);
}

ThemeData qjTheme() {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: QjColors.navy);
  return base.copyWith(
    scaffoldBackgroundColor: QjColors.bg,
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

// Kartu statistik kecil (angka besar + label).
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
