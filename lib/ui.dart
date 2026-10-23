import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'i18n.dart';
import 'main.dart' show app;

Color fg(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color muted(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF8D8D8D) : const Color(0xFF6E6E6E);
Color line(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFE1E1E1);
Color card(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : Colors.white;
Color soft(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF181818) : const Color(0xFFEFEFEF);

// Warm ember accent used sparingly on top of the black and white look.
Color accent(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFFF0804A) : const Color(0xFFD9602A);

/// A light tap on the phone for key actions. Can be turned off in Settings.
void buzz([bool strong = false]) {
  if (app.set['haptics'] == false) return;
  if (strong) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.selectionClick();
  }
}

/// Calm backdrop: a deep gradient with a warm glow that slowly breathes.
class Ambient extends StatefulWidget {
  final Widget child;
  const Ambient({super.key, required this.child});
  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = accent(context);
    final still = MediaQuery.of(context).disableAnimations;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: still ? const AlwaysStoppedAnimation<double>(0.5) : _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(still ? 0.5 : _c.value);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark ? const [Color(0xFF120D0A), Color(0xFF060505), Color(0xFF040404)] : const [Color(0xFFFFF1E6), Color(0xFFF7F1EC), Color(0xFFF1EEEB)],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.9 - 0.25 * t, -1.0 + 0.1 * t),
                      radius: 0.9 + 0.25 * t,
                      colors: [a.withOpacity((dark ? 0.22 : 0.20) + 0.06 * t), Colors.transparent],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-1.0 + 0.2 * t, 1.05),
                        radius: 0.85,
                        colors: [a.withOpacity(dark ? 0.09 : 0.08), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool dark;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.dark = false});
  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final a = accent(context);
    final deco = dark
        ? BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF17110D), Color(0xFF0A0A0A)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: a.withOpacity(0.28)),
            boxShadow: [BoxShadow(color: a.withOpacity(0.10), blurRadius: 28, offset: const Offset(0, 10))],
          )
        : BoxDecoration(
            gradient: night
                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xCC1B1612), Color(0xCC0E0C0B)])
                : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xE6FFFFFF), Color(0xD9FFF8F1)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: night ? const Color(0x24FFFFFF) : const Color(0xFFEBDDD0)),
            boxShadow: night ? null : const [BoxShadow(color: Color(0x14B45A28), blurRadius: 22, offset: Offset(0, 8))],
          );
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: deco,
      child: dark ? DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child) : child,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, w) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: w)),
      child: body,
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String t;
  final bool onDark;
  const Eyebrow(this.t, {super.key, this.onDark = false});
  @override
  Widget build(BuildContext context) => Text(tr(t).toUpperCase(),
      style: TextStyle(fontSize: 10.5, letterSpacing: 1.6, fontWeight: FontWeight.w500, color: onDark ? const Color(0xFFD9A98C) : accent(context)));
}

class H1 extends StatelessWidget {
  final String t;
  const H1(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Text(t, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.05));
}

class H2 extends StatelessWidget {
  final String t;
  const H2(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
      );
}

class Muted extends StatelessWidget {
  final String t;
  final double size;
  const Muted(this.t, {super.key, this.size = 13});
  @override
  Widget build(BuildContext context) => Text(t, style: TextStyle(fontSize: size, color: muted(context), height: 1.4));
}

class Stat extends StatelessWidget {
  final String k, v, s;
  final bool inverse;
  final VoidCallback? onTap;
  final Widget? extra;
  const Stat(this.k, this.v, {super.key, this.s = '', this.inverse = false, this.onTap, this.extra});
  @override
  Widget build(BuildContext context) {
    final c = Box(
      dark: inverse,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow(k, onDark: inverse),
        const SizedBox(height: 8),
        Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: -0.8, height: 1.1)),
        if (s.isNotEmpty) ...[const SizedBox(height: 6), inverse ? Text(s, style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6))) : Muted(s, size: 12.5)],
        if (extra != null) ...[const SizedBox(height: 10), extra!],
      ]),
    );
    return onTap == null ? c : GestureDetector(onTap: onTap, child: c);
  }
}

class Bar extends StatelessWidget {
  final double v;
  const Bar(this.v, {super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: (v.isNaN ? 0.0 : v).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) => LinearProgressIndicator(value: val, minHeight: 6, backgroundColor: soft(context), color: accent(context)),
        ),
      );
}

class Pill extends StatelessWidget {
  final String t;
  const Pill(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      );
}

class Seg<T> extends StatelessWidget {
  final List<(T, String)> opts;
  final T value;
  final ValueChanged<T> onChanged;
  const Seg({super.key, required this.opts, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: opts.map((o) => ButtonSegment<T>(value: o.$1, label: Text(o.$2, style: const TextStyle(fontSize: 13)))).toList(),
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class Field extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;
  const Field(this.label, this.child, {super.key, this.hint});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          child,
          if (hint != null) ...[const SizedBox(height: 6), Muted(hint!, size: 12)],
        ]),
      );
}

class TaskRow extends StatelessWidget {
  final bool done;
  final ValueChanged<bool> onChanged;
  final Widget body;
  final Widget? trailing;
  const TaskRow({super.key, required this.done, required this.onChanged, required this.body, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!done),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: done, onChanged: (v) => onChanged(v ?? false), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            const SizedBox(width: 4),
            Expanded(child: Opacity(opacity: done ? 0.55 : 1, child: body)),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
        ),
      ),
    );
  }
}

class Bullets extends StatelessWidget {
  final List<String> items;
  const Bullets(this.items, {super.key});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 8, right: 8), child: Icon(Icons.circle, size: 5)),
                    Expanded(child: Text(e, style: const TextStyle(height: 1.4))),
                  ]),
                ))
            .toList(),
      );
}

class LineChart extends CustomPainter {
  final List<double> ys;
  final double? target;
  final Color ink, grid;
  final double progress;
  LineChart(this.ys, this.target, this.ink, this.grid, [this.progress = 1.0]);
  @override
  void paint(Canvas canvas, Size size) {
    if (ys.length < 2) return;
    var lo = ys.reduce((a, b) => a < b ? a : b), hi = ys.reduce((a, b) => a > b ? a : b);
    if (target != null) {
      if (target! < lo) lo = target!;
      if (target! > hi) hi = target!;
    }
    final pad = (hi - lo) * 0.15 < 0.5 ? 0.5 : (hi - lo) * 0.15;
    lo -= pad;
    hi += pad;
    const l = 8.0, r = 8.0, t = 10.0, b = 10.0;
    double y(double v) => t + (hi - v) / (hi - lo) * (size.height - t - b);
    double x(int i) => l + i / (ys.length - 1) * (size.width - l - r);
    final gp = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final yy = t + i / 3 * (size.height - t - b);
      canvas.drawLine(Offset(l, yy), Offset(size.width - r, yy), gp);
    }
    if (target != null) {
      final tp = Paint()..color = ink.withOpacity(0.6)..strokeWidth = 1.2;
      for (double dx = l; dx < size.width - r; dx += 10) {
        canvas.drawLine(Offset(dx, y(target!)), Offset(dx + 5, y(target!)), tp);
      }
    }
    final path = Path()..moveTo(x(0), y(ys[0]));
    for (var i = 1; i < ys.length; i++) {
      path.lineTo(x(i), y(ys[i]));
    }
    final linePaint = Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    if (progress >= 1.0) {
      canvas.drawPath(path, linePaint);
    } else {
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * progress), linePaint);
      }
    }
    for (var i = 0; i < ys.length; i++) {
      final at = i / (ys.length - 1);
      if (at <= progress + 0.0001) {
        canvas.drawCircle(Offset(x(i), y(ys[i])), 4, Paint()..color = ink);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChart o) => true;
}


// ---------------- animated gauges ----------------
class RingGauge extends StatelessWidget {
  final double fraction;
  final String center;
  final double size;
  final Color? ink, track;
  const RingGauge({super.key, required this.fraction, required this.center, this.size = 84, this.ink, this.track});
  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: f),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, ink ?? accent(context), track ?? soft(context), size * 0.11),
          child: Center(child: Text(center, style: TextStyle(fontSize: (size * 0.2).clamp(12.0, 19.0), fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color ink, track;
  final double w;
  _RingPainter(this.v, this.ink, this.track, this.w);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    canvas.drawArc(r, 0, 6.283185307179586, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = w);
    if (v > 0) {
      canvas.drawArc(r, -1.5707963267948966, 6.283185307179586 * v, false, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.v != v || o.ink != ink || o.track != track || o.w != w;
}

// One bar split in three parts (protein, carbs, fat by calories) that fills in from the left.
class MacroBar extends StatelessWidget {
  final int pG, cG, fG;
  const MacroBar({super.key, required this.pG, required this.cG, required this.fG});
  @override
  Widget build(BuildContext context) {
    final p = pG * 4, c = cG * 4, f = fG * 9;
    final total = (p + c + f) <= 0 ? 1 : (p + c + f);
    Widget legend(String name, int grams, int kcal, double op) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: fg(context).withOpacity(op), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text('$name ${grams}g · ${(kcal * 100 / total).round()}%', style: const TextStyle(fontSize: 12.5)),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 16,
            color: soft(context),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: t,
              child: Row(children: [
                Expanded(flex: p <= 0 ? 1 : p, child: Container(color: fg(context))),
                Expanded(flex: c <= 0 ? 1 : c, child: Container(color: fg(context).withOpacity(0.6))),
                Expanded(flex: f <= 0 ? 1 : f, child: Container(color: fg(context).withOpacity(0.3))),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 6, children: [legend('Protein', pG, p, 1.0), legend('Carbs', cG, c, 0.6), legend('Fat', fG, f, 0.3)]),
    ]);
  }
}


// ---------------- PureBurn brand ----------------
// The flame mark, drawn from the same shape as the app icon. The hole in the middle is cut out.
class BrandMark extends StatelessWidget {
  final double size;
  final Color? color;
  const BrandMark({super.key, this.size = 28, this.color});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, s, _) => Transform.scale(
        scale: s,
        child: SizedBox(width: size, height: size, child: CustomPaint(painter: _FlamePainter(color ?? fg(context)))),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final Color color;
  _FlamePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset o(double x, double y) => Offset(x * s, y * s);
    final path = Path()..fillType = PathFillType.evenOdd;
    path.moveTo(0.50 * s, 0.90 * s);
    path.cubicTo(0.25 * s, 0.90 * s, 0.16 * s, 0.68 * s, 0.26 * s, 0.50 * s);
    path.cubicTo(0.30 * s, 0.43 * s, 0.36 * s, 0.40 * s, 0.38 * s, 0.30 * s);
    path.cubicTo(0.40 * s, 0.22 * s, 0.45 * s, 0.14 * s, 0.50 * s, 0.08 * s);
    path.cubicTo(0.58 * s, 0.20 * s, 0.82 * s, 0.38 * s, 0.80 * s, 0.62 * s);
    path.cubicTo(0.78 * s, 0.80 * s, 0.66 * s, 0.90 * s, 0.50 * s, 0.90 * s);
    path.close();
    path.moveTo(o(0.50, 0.84).dx, o(0.50, 0.84).dy);
    path.cubicTo(0.38 * s, 0.84 * s, 0.35 * s, 0.72 * s, 0.42 * s, 0.62 * s);
    path.cubicTo(0.45 * s, 0.58 * s, 0.48 * s, 0.56 * s, 0.50 * s, 0.50 * s);
    path.cubicTo(0.56 * s, 0.58 * s, 0.66 * s, 0.66 * s, 0.64 * s, 0.74 * s);
    path.cubicTo(0.63 * s, 0.80 * s, 0.57 * s, 0.84 * s, 0.50 * s, 0.84 * s);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _FlamePainter o) => o.color != color;
}

// Flame plus the PURE BURN wordmark.
class BrandLockup extends StatelessWidget {
  final double height;
  final Color? color;
  const BrandLockup({super.key, this.height = 24, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? fg(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(size: height * 1.15, color: c),
      SizedBox(width: height * 0.3),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'PURE', style: TextStyle(fontWeight: FontWeight.w800, color: c)),
          TextSpan(text: 'BURN', style: TextStyle(fontWeight: FontWeight.w300, color: c)),
        ]),
        style: TextStyle(fontSize: height * 0.72, letterSpacing: height * 0.14),
      ),
    ]);
  }
}
