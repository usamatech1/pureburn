// Daily exercise extras: task timers, steps card, session summary, demo links.
import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'ui.dart';

/// Minutes written in a task, like "Warm up for 5 minutes" or "Brisk walk: 25 minutes". Null for rep-based tasks.
int? taskMinutes(String text) {
  final m = RegExp(r'(\d+)\s*minutes?').firstMatch(text);
  if (m == null) return null;
  final n = int.tryParse(m.group(1)!);
  return (n == null || n <= 0 || n > 120) ? null : n;
}

/// Play/pause countdown that ticks the task when it ends.
class TaskTimer extends StatefulWidget {
  final int minutes;
  final bool done;
  final VoidCallback onFinished;
  const TaskTimer({super.key, required this.minutes, required this.done, required this.onFinished});
  @override
  State<TaskTimer> createState() => _TaskTimerState();
}

class _TaskTimerState extends State<TaskTimer> {
  Timer? _t;
  late int left = widget.minutes * 60;
  bool get running => _t != null;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _toggle() {
    buzz();
    if (running) {
      _t?.cancel();
      setState(() => _t = null);
      return;
    }
    if (left <= 0) left = widget.minutes * 60;
    setState(() {
      _t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => left--);
        if (left <= 0) {
          t.cancel();
          _t = null;
          HapticFeedback.heavyImpact();
          widget.onFinished();
          setState(() => left = widget.minutes * 60);
        }
      });
    });
  }

  String get _txt {
    final m = left ~/ 60, s = left % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.done && !running) return const Icon(Icons.check_circle, color: Color(0xFF2E9E6B));
    final ac = accent(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: ac.withOpacity(running ? 0.2 : 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: ac.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18, color: ac),
          const SizedBox(width: 4),
          Text(_txt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

/// Opens a YouTube search for how to do the exercise. No video files are bundled in the app.
Future<void> openDemo(BuildContext context, String q) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent('$q exercise proper form')}'), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open YouTube on this device.')));
  }
}

/// Steps with a progress ring, quick add buttons and estimated distance and calories.
class StepsCard extends StatefulWidget {
  final String date;
  final int steps;
  final int goal;
  const StepsCard({super.key, required this.date, required this.steps, required this.goal});
  @override
  State<StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<StepsCard> {
  late final TextEditingController c = TextEditingController(text: widget.steps == 0 ? '' : '${widget.steps}');

  @override
  void didUpdateWidget(StepsCard o) {
    super.didUpdateWidget(o);
    if (o.date != widget.date) c.text = widget.steps == 0 ? '' : '${widget.steps}';
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _add(int n) {
    buzz();
    final v = (int.tryParse(c.text) ?? 0) + n;
    c.text = '$v';
    app.setSteps(v);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final stride = app.p.heightCm * 0.415 / 100; // metres per step
    final km = steps * stride / 1000;
    final kcal = km * app.p.weightKg * 0.5;
    final frac = widget.goal > 0 ? steps / widget.goal : 0.0;
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Steps'),
        const SizedBox(height: 8),
        Row(children: [
          RingGauge(fraction: frac, center: '${(frac * 100).clamp(0, 999).round()}%', size: 92),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$steps', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: -1)),
              Muted('of ${widget.goal} steps', size: 12.5),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill('${km.toStringAsFixed(2)} km'),
                Pill('~${kcal.round()} kcal'),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'steps', hintText: 'Type your steps'),
          onChanged: (v) => app.setSteps(int.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in [500, 1000, 2000])
            OutlinedButton(onPressed: () => _add(n), child: Text('+$n')),
        ]),
        const SizedBox(height: 8),
        const Muted('Distance and calories are estimates from your height and weight. Copy your count from your phone or watch health app.', size: 12),
      ]),
    );
  }
}

/// Streak chip for the top of the page.
Widget streakChip(BuildContext context) {
  final n = app.streak();
  final ac = accent(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: ac.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: ac.withOpacity(0.5))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.local_fire_department, size: 18, color: ac),
      const SizedBox(width: 6),
      Text(n == 0 ? 'Start your streak today' : '$n-day streak', style: TextStyle(fontWeight: FontWeight.w800, color: ac, fontSize: 13)),
    ]),
  );
}

Map<String, String> _feels() {
  final f = app.set['feel'];
  return f is Map ? {for (final e in f.entries) '${e.key}': '${e.value}'} : <String, String>{};
}

/// Shown when every task of the session is done.
class SessionSummary extends StatelessWidget {
  final SchedRow row;
  final String date;
  const SessionSummary({super.key, required this.row, required this.date});
  @override
  Widget build(BuildContext context) {
    final feels = _feels();
    final mine = feels[date];
    final recent = (feels.keys.toList()..sort()).reversed.take(3).map((k) => feels[k]!).toList();
    String? tip;
    String? setLevel;
    if (recent.length == 3 && recent.every((x) => x == 'hard')) {
      tip = 'Your last 3 sessions felt hard. Consider the Beginner level in the workout player for a lighter week.';
      setLevel = 'beg';
    } else if (recent.length == 3 && recent.every((x) => x == 'easy')) {
      tip = 'Your last 3 sessions felt easy. You are ready to try the Advanced level in the workout player.';
      setLevel = 'adv';
    }
    Widget feel(String k, String label) {
      final on = mine == k;
      return ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) {
          buzz();
          final m = _feels();
          m[date] = k;
          app.set['feel'] = m;
          app.save();
        },
      );
    }

    return Box(
      dark: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.celebration_outlined, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(child: Text('Session complete. Well done!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _darkPill('${row.min} min'),
          _darkPill('~${(row.kcal / 5).round() * 5} kcal burned'),
          _darkPill('${app.streak()}-day streak'),
        ]),
        const SizedBox(height: 14),
        const Text('How did this session feel?', style: TextStyle(color: Color(0xFFA6A6A6), fontSize: 12.5)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [feel('easy', 'Easy'), feel('moderate', 'Moderate'), feel('hard', 'Hard')]),
        if (tip != null) ...[
          const SizedBox(height: 10),
          Text(tip, style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            onPressed: () {
              app.set['level'] = setLevel;
              app.save();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workout player level set to ${setLevel == 'adv' ? 'Advanced' : 'Beginner'}.')));
            },
            child: Text(setLevel == 'adv' ? 'Switch to Advanced' : 'Switch to Beginner'),
          ),
        ],
      ]),
    );
  }

  Widget _darkPill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

/// Dashed horizontal goal line.
class DashLine extends CustomPainter {
  final Color color;
  DashLine(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1.6;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), p);
      x += 6;
    }
  }

  @override
  bool shouldRepaint(DashLine o) => o.color != color;
}
