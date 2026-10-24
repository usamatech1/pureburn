// Daily diet extras: macro meters, portion stepper, water bottle, quick add, day wrap-up.
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dietfit.dart' show findFood;
import 'foods.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'state.dart';
import 'ui.dart';

/// Opens WhatsApp with the text ready to send. Falls back to copying it.
Future<void> shareWhatsApp(BuildContext context, String text) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp. The text was copied, paste it in any chat.')));
    }
  }
}

/// Protein, carbs and fat eaten against the daily targets.
class MacroMeters extends StatelessWidget {
  final DayInfo info;
  final Plan plan;
  const MacroMeters({super.key, required this.info, required this.plan});

  Widget _row(BuildContext context, String name, double eaten, int target, Color c) {
    final f = target > 0 ? (eaten / target) : 0.0;
    final over = f > 1.05;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          Text('${eaten.round()}g / ${target}g', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: over ? const Color(0xFFD64545) : null)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: f.isNaN ? 0.0 : f.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (c2, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: over ? const Color(0xFFD64545) : c, backgroundColor: soft(context)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row(context, 'Protein', info.p, plan.pG, accent(context)),
        _row(context, 'Carbs', info.c, plan.cG, const Color(0xFF2E9E6B)),
        _row(context, 'Fat', info.f, plan.fG, const Color(0xFFB8860B)),
      ]);
}

/// [-] 1x [+] for the size of a meal. 1x is the planned portion.
class PortionStepper extends StatelessWidget {
  final String mealId;
  final double value;
  const PortionStepper({super.key, required this.mealId, required this.value});

  static const steps = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  void _go(int dir) {
    var i = steps.indexOf(value);
    if (i < 0) i = 2;
    final n = (i + dir).clamp(0, steps.length - 1);
    buzz();
    app.setPortion(mealId, steps[n]);
  }

  @override
  Widget build(BuildContext context) {
    final txt = value == value.roundToDouble() ? '${value.round()}x' : '${value}x';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('Portion', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      IconButton(visualDensity: VisualDensity.compact, onPressed: value <= steps.first ? null : () => _go(-1), icon: const Icon(Icons.remove_circle_outline)),
      SizedBox(width: 38, child: Text(txt, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
      IconButton(visualDensity: VisualDensity.compact, onPressed: value >= steps.last ? null : () => _go(1), icon: const Icon(Icons.add_circle_outline)),
    ]);
  }
}

/// A bottle that fills up with a moving wave as you drink.
class WaterBottle extends StatefulWidget {
  final int glasses;
  final int goal;
  const WaterBottle({super.key, required this.glasses, required this.goal});
  @override
  State<WaterBottle> createState() => _WaterBottleState();
}

class _WaterBottleState extends State<WaterBottle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.goal > 0 ? (widget.glasses / widget.goal).clamp(0.0, 1.0) : 0.0;
    final blue = const Color(0xFF3D8BFD);
    return SizedBox(
      width: 92,
      height: 150,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: f),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, level, _) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _BottlePainter(level, _c.value, blue, Theme.of(context).dividerColor, soft(context)),
            child: Center(
              child: Text('${(widget.glasses * 0.25).toStringAsFixed(widget.glasses % 4 == 0 ? 0 : 2).replaceFirst(RegExp(r'0$'), '')} L', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: level > 0.45 ? Colors.white : null)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  final double level, phase;
  final Color water, outline, bg;
  _BottlePainter(this.level, this.phase, this.water, this.outline, this.bg);
  @override
  void paint(Canvas canvas, Size s) {
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(4, 22, s.width - 8, s.height - 26), const Radius.circular(22));
    final neck = RRect.fromRectAndRadius(Rect.fromLTWH(s.width / 2 - 14, 4, 28, 22), const Radius.circular(6));
    canvas.drawRRect(body, Paint()..color = bg);
    canvas.save();
    canvas.clipRRect(body);
    final top = body.top + body.height * (1 - level);
    final path = Path()..moveTo(body.left, s.height);
    path.lineTo(body.left, top);
    for (double x = 0; x <= body.width; x += 2) {
      path.lineTo(body.left + x, top + math.sin((x / body.width * 2 * math.pi) + phase * 2 * math.pi) * (level > 0 && level < 1 ? 4 : 0));
    }
    path.lineTo(body.right, s.height);
    path.close();
    canvas.drawPath(path, Paint()..color = water.withOpacity(0.9));
    canvas.restore();
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = outline;
    canvas.drawRRect(body, line);
    canvas.drawRRect(neck, line);
  }

  @override
  bool shouldRepaint(_BottlePainter o) => o.level != level || o.phase != phase;
}

/// One-tap logging of things that are not in the plan.
class QuickAdd extends StatelessWidget {
  final String date;
  final VoidCallback onMore;
  const QuickAdd({super.key, required this.date, required this.onMore});

  static const ids = ['chai', 'green_tea', 'biscuit', 'samosa', 'lassi_sweet', 'rooh_afza'];

  @override
  Widget build(BuildContext context) {
    final extra = app.dayInfo(date).dK;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H2('Quick add'),
      const SizedBox(height: 2),
      const Muted('Ate or drank something that is not in your plan? Add it in one tap. Your plan stays as it is.', size: 12.5),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final id in ids)
          if (findFood(id, app.customFoods) != null)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(findFood(id, app.customFoods)!.name.split(' with').first.split(',').first),
              onPressed: () {
                buzz();
                final fd = findFood(id, app.customFoods)!;
                app.addFood(date, FoodEntry(id, 1, 'Snack'));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${fd.name} (about ${fd.kcal.round()} kcal).')));
              },
            ),
        ActionChip(avatar: const Icon(Icons.search, size: 16), label: const Text('More foods'), onPressed: onMore),
      ]),
      if (extra > 0) ...[const SizedBox(height: 10), Muted('Extra logged today: $extra kcal', size: 12.5)],
    ]);
  }
}

/// Shown once every meal of the day is ticked.
class DayWrap extends StatelessWidget {
  final DayInfo info;
  final Plan plan;
  const DayWrap({super.key, required this.info, required this.plan});
  Widget _p(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) {
    final diff = info.kcal - plan.kcal;
    final note = diff.abs() <= 100 ? 'Right on your calorie target.' : diff > 0 ? '${diff} kcal above your target. A short walk helps.' : '${-diff} kcal under your target. Add a healthy snack if you are still hungry.';
    return Box(
      dark: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.nightlight_round, color: Colors.white),
          SizedBox(width: 10),
          Expanded(child: Text('All meals done. Great day!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _p('${info.kcal} kcal eaten'),
          _p('${info.steps} steps'),
          _p(info.exT > 0 ? 'Workout ${info.exD}/${info.exT}' : 'Rest day'),
          _p('Water ${info.water}/${info.wg}'),
        ]),
        const SizedBox(height: 10),
        Text(note, style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 12.5)),
      ]),
    );
  }
}
