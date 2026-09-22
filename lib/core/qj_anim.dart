import 'package:flutter/material.dart';

// Kumpulan animasi ringan (transform/opacity saja, aman di HP kentang).
// 1) StaggerIn: kartu masuk fade-slide berurutan (bungkus tiap item, beri index).
// 2) CountUp: angka statistik menghitung naik.
// 3) ShimmerBox: placeholder loading berkilau (pengganti spinner polos).

class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final int baseMs;
  final int stepMs;
  const StaggerIn({super.key, required this.index, required this.child,
    this.baseMs = 0, this.stepMs = 60});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(
      Duration(milliseconds: widget.baseMs + widget.index * widget.stepMs),
      () { if (mounted) _c.forward(); },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class CountUp extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  const CountUp({super.key, required this.value, this.style,
    this.duration = const Duration(milliseconds: 1200)});

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<int> _num;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _num = IntTween(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void didUpdateWidget(CountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _num = IntTween(begin: old.value, end: widget.value)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _num,
      builder: (_, __) => Text('${_num.value}', style: widget.style),
    );
  }
}

class ShimmerBox extends StatefulWidget {
  final double height;
  final double borderRadius;
  const ShimmerBox({super.key, this.height = 64, this.borderRadius = 12});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + _c.value * 2, 0),
            end: Alignment(0.0 + _c.value * 2, 0),
            colors: const [Color(0xFFE9E4DE), Color(0xFFF7F4F0), Color(0xFFE9E4DE)],
          ),
        ),
      ),
    );
  }
}
