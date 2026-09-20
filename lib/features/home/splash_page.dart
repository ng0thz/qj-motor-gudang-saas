import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/qj_theme.dart';
import '../auth/auth_gate.dart';

// Splash animasi: logo zoom+fade, garis kecepatan merah, tagline mengetik.
// Lalu lanjut ke AuthGate (login -> home, atau offline).
class SplashPage extends StatefulWidget {
  final bool firebaseOk;
  const SplashPage({super.key, required this.firebaseOk});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _lines;
  int _taglineCount = 0;
  Timer? _tagTimer;

  static const _tagline = 'ALWAYS FORWARD';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.4, curve: Curves.easeIn));
    _lines = CurvedAnimation(parent: _c, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _c.forward();
    _tagTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (_taglineCount >= _tagline.length) {
        t.cancel();
        return;
      }
      setState(() => _taglineCount++);
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AuthGate(firebaseOk: widget.firebaseOk)),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _tagTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QjColors.navyDark,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(children: [
          // Garis kecepatan merah (speed lines) khas logo QJ
          Positioned.fill(
            child: CustomPaint(painter: _SpeedLines(progress: _lines.value)),
          ),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Opacity(
              opacity: _logoFade.value,
              child: Transform.scale(
                scale: 0.6 + 0.4 * _logoScale.value,
                child: Image.asset(
                  'assets/qjmotor_logo_transparent.png',
                  height: 110,
                  errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, color: QjColors.red, size: 90),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _tagline.substring(0, _taglineCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _c.value,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(QjColors.red),
                minHeight: 3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ])),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Text(
              widget.firebaseOk ? '' : 'MODE OFFLINE',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 3),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SpeedLines extends CustomPainter {
  final double progress;
  _SpeedLines({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = QjColors.red.withOpacity(0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.32 + i * 0.09);
      final full = size.width * (0.55 - i * 0.06);
      final w = full * progress;
      final x0 = size.width - w - 24;
      canvas.drawLine(Offset(x0, y), Offset(x0 + w, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLines old) => old.progress != progress;
}
