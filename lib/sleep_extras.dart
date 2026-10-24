// Sleep helpers: schedule maths, recovery score, regularity and a guided breathing exercise.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'ui.dart';

TimeOfDay? parseHm(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return TimeOfDay(hour: h, minute: mi);
}

String fmtHm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String pretty(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// Hours between going to bed and waking up, across midnight when needed.
double sleepHours(TimeOfDay bed, TimeOfDay wake) {
  var m = (wake.hour * 60 + wake.minute) - (bed.hour * 60 + bed.minute);
  if (m <= 0) m += 24 * 60;
  return (m / 6).round() / 10;
}

/// Bedtime as minutes after 6 pm, so 11:30 pm and 12:30 am sit close together.
double _bedAxis(TimeOfDay t) {
  var m = t.hour * 60 + t.minute - 18 * 60;
  if (m < 0) m += 24 * 60;
  return m.toDouble();
}

class Regularity {
  final double sdMin; // spread of bedtimes in minutes
  final int nights;
  Regularity(this.sdMin, this.nights);
  String get label => nights < 3 ? 'Need 3 nights' : sdMin <= 30 ? 'Very regular' : sdMin <= 60 ? 'Fairly regular' : 'Irregular';
  Color get color => nights < 3 ? const Color(0xFF8D8D8D) : sdMin <= 30 ? const Color(0xFF2E9E6B) : sdMin <= 60 ? const Color(0xFFF0A030) : const Color(0xFFD64545);
  double get factor => nights < 3 ? 0.7 : sdMin <= 30 ? 1.0 : sdMin <= 60 ? 0.7 : 0.4;
}

/// Spread of bedtimes over the last 7 days.
Regularity regularity() {
  final today = DateTime.now();
  final xs = <double>[];
  for (var i = 0; i < 7; i++) {
    final l = app.logs[isoDate(today.subtract(Duration(days: i)))];
    final t = l == null ? null : parseHm(l.bed);
    if (t != null) xs.add(_bedAxis(t));
  }
  if (xs.length < 2) return Regularity(0, xs.length);
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  final v = xs.fold<double>(0, (a, b) => a + (b - mean) * (b - mean)) / xs.length;
  return Regularity(math.sqrt(v), xs.length);
}

class Recovery {
  final int score;
  final String title, text;
  Recovery(this.score, this.title, this.text);
}

/// Recovery from last night's hours, how it felt and how regular bedtimes are.
Recovery recovery(double hours, int quality, double goal) {
  final reg = regularity();
  final q = quality <= 0 ? 3 : quality;
  final s = (100 * (0.65 * math.min(hours / goal, 1.0) + 0.20 * (q / 5) + 0.15 * reg.factor)).round().clamp(0, 100);
  if (s >= 85) return Recovery(s, '$s% Ready', 'Great night! Today is a good day for a heavy strength or cardio session.');
  if (s >= 70) return Recovery(s, '$s% Good', 'Good recovery. Your planned session is fine today.');
  if (s >= 55) return Recovery(s, '$s% Moderate', 'Keep today\'s session light to moderate and listen to your body.');
  return Recovery(s, '$s% Low recovery', 'Active recovery or light cardio is best today. Go to bed early tonight.');
}

/// Average sleep on nights with a tag against nights without it. Null when there is not enough data.
String? tagInsight() {
  const bad = ['Late dinner', 'Caffeine after 6 PM', 'Screen time in bed', 'Woke up in the night'];
  final today = DateTime.now();
  final withT = <String, List<double>>{};
  final without = <String, List<double>>{};
  for (var i = 0; i < 30; i++) {
    final l = app.logs[isoDate(today.subtract(Duration(days: i)))];
    if (l == null || l.sleep <= 0) continue;
    for (final t in bad) {
      (l.stags.contains(t) ? withT : without).putIfAbsent(t, () => []).add(l.sleep);
    }
  }
  String? best;
  var worst = 0.0;
  for (final t in bad) {
    final a = withT[t], b = without[t];
    if (a == null || b == null || a.length < 2 || b.length < 2) continue;
    final ma = a.reduce((x, y) => x + y) / a.length, mb = b.reduce((x, y) => x + y) / b.length;
    if (mb - ma > worst && mb - ma >= 0.4) {
      worst = mb - ma;
      best = 'On nights with "$t" you slept ${ma.toStringAsFixed(1)} h, against ${mb.toStringAsFixed(1)} h on other nights.';
    }
  }
  return best;
}

/// 4-7-8 breathing with a growing and shrinking circle. Needs no audio files.
class BreathingGuide extends StatefulWidget {
  const BreathingGuide({super.key});
  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide> {
  Timer? _t;
  int ms = 0;
  static const total = 4 * 19000; // four rounds of 4 + 7 + 8 seconds

  bool get running => _t != null;

  void _toggle() {
    buzz();
    if (running) {
      _t?.cancel();
      setState(() { _t = null; ms = 0; });
      return;
    }
    setState(() {
      ms = 0;
      _t = Timer.periodic(const Duration(milliseconds: 100), (t) {
        if (!mounted) return;
        setState(() => ms += 100);
        if (ms >= total) {
          t.cancel();
          _t = null;
          HapticFeedback.mediumImpact();
          setState(() => ms = -1);
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = accent(context);
    var scale = 0.55;
    var phase = 'Ready';
    var left = 0;
    if (ms == -1) {
      phase = 'Done. Sleep well.';
    } else if (running) {
      final c = ms % 19000;
      if (c < 4000) {
        phase = 'Breathe in';
        scale = 0.55 + 0.45 * (c / 4000);
        left = 4 - c ~/ 1000;
      } else if (c < 11000) {
        phase = 'Hold';
        scale = 1.0;
        left = 7 - (c - 4000) ~/ 1000;
      } else {
        phase = 'Breathe out';
        scale = 1.0 - 0.45 * ((c - 11000) / 8000);
        left = 8 - (c - 11000) ~/ 1000;
      }
    }
    return Column(children: [
      SizedBox(
        height: 150,
        child: Center(
          child: Container(
            width: 140 * scale,
            height: 140 * scale,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ac.withOpacity(0.18), border: Border.all(color: ac, width: 2)),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(phase, style: TextStyle(fontWeight: FontWeight.w700, color: ac, fontSize: 13)),
              if (running && left > 0) Text('$left', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: ac)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: _toggle,
        icon: Icon(running ? Icons.stop_rounded : Icons.air),
        label: Text(running ? 'Stop' : 'Start 4-7-8 breathing (about 1 minute)'),
      ),
    ]);
  }
}

Future<void> openSounds(BuildContext context, String q) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}'), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open YouTube on this device.')));
  }
}
