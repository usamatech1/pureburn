// Phase 1 features: measurements, trends and badges, weekly report, settings and backup.
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'state.dart';
import 'ui.dart';
import 'services.dart';

Widget _g(double h) => SizedBox(height: h);

Widget _cols(List<Widget> kids, {double min = 200}) => LayoutBuilder(builder: (c, bc) {
      final n = (bc.maxWidth / min).floor().clamp(1, 4);
      final w = (bc.maxWidth - (n - 1) * 12) / n;
      return Wrap(spacing: 12, runSpacing: 12, children: kids.map((k) => SizedBox(width: w, child: k)).toList());
    });

void _snack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------------------------------------------------------- measurements
class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});
  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  final wc = TextEditingController(), cc = TextEditingController(), hc = TextEditingController();
  DateTime date = DateTime.now();

  double _toCm(double v) => app.p.unit == 'metric' ? v : v * 2.54;
  double _fromCm(double cm) => app.p.unit == 'metric' ? cm : cm / 2.54;
  String _u() => app.p.unit == 'metric' ? 'cm' : 'in';
  String _f(double cm) => cm <= 0 ? '--' : '${tidy(_fromCm(cm))} ${_u()}';

  @override
  void initState() {
    super.initState();
    final m = app.measures.isEmpty ? null : app.measures.last;
    if (m != null) {
      if (m.waist > 0) wc.text = tidy(_fromCm(m.waist));
      if (m.chest > 0) cc.text = tidy(_fromCm(m.chest));
      if (m.hip > 0) hc.text = tidy(_fromCm(m.hip));
    }
  }

  @override
  void dispose() {
    wc.dispose();
    cc.dispose();
    hc.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Widget _in(String label, TextEditingController c) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '${tr(label)} (${_u()})'),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final h = app.p.heightCm;
    final ms = app.measures;
    final last = ms.isEmpty ? null : ms.last;
    final first = ms.isEmpty ? null : ms.first;
    final waist = last != null && last.waist > 0 ? last.waist : 0.0;
    final whtr = waist > 0 ? waist / h : 0.0;
    String band = '--', note = 'Add your waist to see your waist-to-height ratio.';
    if (whtr > 0) {
      if (whtr < 0.4) {
        band = 'Very slim';
        note = 'Your waist is small for your height. Make sure you are eating enough.';
      } else if (whtr < 0.5) {
        band = 'Healthy';
        note = 'Your waist is under half your height. Keep it up.';
      } else if (whtr < 0.6) {
        band = 'Raised';
        note = 'Your waist is over half your height. Walking daily and cutting sugary and fried food will bring it down.';
      } else {
        band = 'High';
        note = 'Your waist is well over half your height. Please talk to a doctor and follow your plan every day.';
      }
    }
    final hip = last != null && last.hip > 0 ? last.hip : 0.0;
    final whr = waist > 0 && hip > 0 ? waist / hip : 0.0;
    final limit = app.p.sex == 'f' ? 0.85 : 0.90;
    final waistSeries = [for (final m in ms) if (m.waist > 0) _fromCm(m.waist)];
    String change(double a, double b) {
      if (a <= 0 || b <= 0) return '--';
      final c = _fromCm(b - a);
      return '${c > 0 ? '+' : c < 0 ? '-' : ''}${tidy(c.abs())} ${_u()}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Log your measurements'),
          Row(children: [_in('Waist', wc), _in('Chest', cc), _in('Hip', hc)]),
          _g(6),
          const Muted('Measure your waist at the navel, your chest at the fullest point and your hip at the widest point. Leave a box empty to skip it.', size: 12),
          _g(12),
          Row(children: [
            OutlinedButton(
              onPressed: () async {
                final r = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (r != null) setState(() => date = r);
              },
              child: Text(isoDate(date)),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                final w = _toCm(_n(wc)), c = _toCm(_n(cc)), hp = _toCm(_n(hc));
                if (w <= 0 && c <= 0 && hp <= 0) {
                  _snack(context, 'Enter at least one measurement.');
                  return;
                }
                bool bad(double v) => v != 0 && (v < 30 || v > 250);
                if (bad(w) || bad(c) || bad(hp)) {
                  _snack(context, 'Check the numbers. They look too small or too large.');
                  return;
                }
                app.addMeasure(Measure(isoDate(date), waist: w, chest: c, hip: hp));
                _snack(context, 'Saved.');
              },
              child: const Text('Save'),
            ),
          ]),
        ]),
      ),
      _g(16),
      Box(
        dark: true,
        child: Row(children: [
          RingGauge(fraction: whtr / 0.7, center: whtr > 0 ? whtr.toStringAsFixed(2) : '--', size: 92, ink: Colors.white, track: const Color(0xFF2A2A2A)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Waist-to-height ratio', onDark: true),
              const SizedBox(height: 6),
              Text(band, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300)),
              const SizedBox(height: 6),
              Text(note, style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6), height: 1.4)),
            ]),
          ),
        ]),
      ),
      _g(12),
      _cols([
        Stat('Waist', _f(waist), s: first == null ? 'No entries yet' : 'Change ${change(first.waist, last!.waist)}'),
        Stat('Chest', _f(last?.chest ?? 0), s: first == null ? 'No entries yet' : 'Change ${change(first.chest, last!.chest)}'),
        Stat('Hip', _f(hip), s: first == null ? 'No entries yet' : 'Change ${change(first.hip, last!.hip)}'),
        Stat('Waist-to-hip', whr > 0 ? whr.toStringAsFixed(2) : '--', s: whr == 0 ? 'Needs waist and hip' : (whr >= limit ? 'High. Aim below ${limit.toStringAsFixed(2)}' : 'Good. Below ${limit.toStringAsFixed(2)}')),
      ], min: 150),
      _g(12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Waist over time'),
          if (waistSeries.length < 2)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('Log your waist on two different days to see your chart.')))
          else
            SizedBox(
              height: 190,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
                builder: (context, t, _) => CustomPaint(painter: LineChart(waistSeries, _fromCm(h / 2), fg(context), line(context), t)),
              ),
            ),
          const SizedBox(height: 6),
          Muted('The dotted line is half your height: ${_f(h / 2)}', size: 12),
        ]),
      ),
      _g(12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('History'),
          if (ms.isEmpty) const Muted('No measurements yet.'),
          for (final m in ms.reversed.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.d, style: TextStyle(color: muted(context), fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('${tr('Waist')} ${_f(m.waist)}  ·  ${tr('Chest')} ${_f(m.chest)}  ·  ${tr('Hip')} ${_f(m.hip)}', style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                  IconButton(onPressed: () => app.delMeasure(m.d), icon: const Icon(Icons.close, size: 18)),
                ]),
              ),
            ),
        ]),
      ),
      _g(12),
      const Muted('A general guide only. Please talk to a doctor before making health decisions.', size: 12),
    ]);
  }
}

// ---------------------------------------------------------------- trends and badges
class _WeekAgg {
  final String label;
  final double score, kcal, steps;
  _WeekAgg(this.label, this.score, this.kcal, this.steps);
}

List<_WeekAgg> _weeks(int n) {
  final now = DateTime.now();
  final mon = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final today = isoDate(now);
  final out = <_WeekAgg>[];
  for (var k = n - 1; k >= 0; k--) {
    final start = DateTime(mon.year, mon.month, mon.day - 7 * k);
    var sc = 0.0, kc = 0, kd = 0, st = 0, sd = 0, days = 0;
    for (var i = 0; i < 7; i++) {
      final ds = isoDate(DateTime(start.year, start.month, start.day + i));
      if (ds.compareTo(today) > 0) continue;
      days++;
      final x = app.dayInfo(ds);
      sc += x.score;
      if (x.kcal > 0) {
        kc += x.kcal;
        kd++;
      }
      if (x.steps > 0) {
        st += x.steps;
        sd++;
      }
    }
    out.add(_WeekAgg(k == 0 ? 'Now' : '-$k', days == 0 ? 0 : sc / days, kd == 0 ? 0 : kc / kd, sd == 0 ? 0 : st / sd));
  }
  return out;
}

class TrendBars extends StatelessWidget {
  final List<String> labels, tops;
  final List<double> fracs;
  const TrendBars({super.key, required this.labels, required this.tops, required this.fracs});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) => Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(tops[i], style: TextStyle(fontSize: 9.5, color: muted(context))),
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 90,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(color: soft(context), borderRadius: BorderRadius.circular(8)),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: (fracs[i].isNaN ? 0.0 : fracs[i]).clamp(0.0, 1.0)),
                    duration: Duration(milliseconds: 600 + i * 90),
                    curve: Curves.easeOutCubic,
                    builder: (context, h, _) => FractionallySizedBox(
                      heightFactor: h,
                      child: Container(decoration: BoxDecoration(color: fg(context), borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: TextStyle(fontSize: 9.5, color: muted(context))),
              ]),
            )),
      ),
    );
  }
}

class TrendsBox extends StatefulWidget {
  const TrendsBox({super.key});
  @override
  State<TrendsBox> createState() => _TrendsBoxState();
}

class _TrendsBoxState extends State<TrendsBox> {
  String m = 'score';
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    final w = _weeks(8);
    final kt = (d.plan?.kcal ?? 2000).toDouble();
    final st = d.stepGoal.toDouble();
    List<double> fr;
    List<String> tops;
    String note;
    switch (m) {
      case 'kcal':
        fr = [for (final x in w) x.kcal / kt];
        tops = [for (final x in w) x.kcal == 0 ? '-' : '${x.kcal.round()}'];
        note = 'Average calories on days you ticked meals. Full bar is ${kt.round()} kcal.';
        break;
      case 'steps':
        fr = [for (final x in w) x.steps / st];
        tops = [for (final x in w) x.steps == 0 ? '-' : '${x.steps.round()}'];
        note = 'Average steps on days you logged steps. Full bar is ${st.round()} steps.';
        break;
      default:
        fr = [for (final x in w) x.score];
        tops = [for (final x in w) '${(x.score * 100).round()}%'];
        note = 'How much of your plan you followed each week: workout, meals and water.';
    }
    // 14 days of plan follow-through as a line.
    final now = DateTime.now();
    final days = [for (var i = 13; i >= 0; i--) app.dayInfo(isoDate(DateTime(now.year, now.month, now.day - i))).score * 100];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Last 8 weeks'),
          Seg<String>(opts: const [('score', 'Plan followed'), ('kcal', 'Calories'), ('steps', 'Steps')], value: m, onChanged: (v) => setState(() => m = v)),
          _g(14),
          TrendBars(labels: [for (final x in w) x.label], tops: tops, fracs: fr),
          const SizedBox(height: 6),
          Muted(note, size: 12),
        ]),
      ),
      _g(12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Plan followed, last 14 days'),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeInOut,
              builder: (context, t, _) => CustomPaint(painter: LineChart(days, 60, fg(context), line(context), t)),
            ),
          ),
          const SizedBox(height: 6),
          const Muted('The dotted line is 60%, the level that keeps your streak going.', size: 12),
        ]),
      ),
      _g(12),
      const BadgesBox(),
    ]);
  }
}

class BadgesBox extends StatelessWidget {
  const BadgesBox({super.key});
  @override
  Widget build(BuildContext context) {
    final bs = app.badges();
    final n = bs.where((b) => b.earned).length;
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Badges'),
        Muted('$n of ${bs.length} earned', size: 12.5),
        _g(12),
        _cols([
          for (final b in bs)
            Opacity(
              opacity: b.earned ? 1 : 0.4,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: b.earned ? fg(context) : Colors.transparent,
                  border: Border.all(color: b.earned ? fg(context) : line(context)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Icon(b.earned ? b.icon : Icons.lock_outline, size: 22, color: b.earned ? Theme.of(context).colorScheme.surface : fg(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: b.earned ? Theme.of(context).colorScheme.surface : fg(context))),
                      const SizedBox(height: 2),
                      Text(b.desc, style: TextStyle(fontSize: 11, height: 1.3, color: b.earned ? Theme.of(context).colorScheme.surface.withOpacity(0.7) : muted(context))),
                    ]),
                  ),
                ]),
              ),
            ),
        ], min: 200),
      ]),
    );
  }
}

// ---------------------------------------------------------------- weekly report
class _Week {
  late String from, to;
  int score = 0, workouts = 0, workoutsOf = 0, waterDays = 0, steps = 0, avgKcal = 0, streak = 0, badges = 0;
  String weight = '--';
}

_Week _weekData() {
  final r = _Week();
  final wk = app.weekDates();
  final today = isoDate(DateTime.now());
  final infos = wk.map(app.dayInfo).toList();
  var sc = 0.0, days = 0, kc = 0, kd = 0;
  for (var i = 0; i < 7; i++) {
    if (wk[i].compareTo(today) > 0) continue;
    days++;
    sc += infos[i].score;
    if (app.rowFor(wk[i]) != null) {
      r.workoutsOf++;
      if (infos[i].exT > 0 && infos[i].exD / infos[i].exT >= 0.8) r.workouts++;
    }
    if (infos[i].water >= infos[i].wg) r.waterDays++;
    r.steps += infos[i].steps;
    if (infos[i].kcal > 0) {
      kc += infos[i].kcal;
      kd++;
    }
  }
  r.score = days == 0 ? 0 : (sc / days * 100).round();
  r.avgKcal = kd == 0 ? 0 : (kc / kd).round();
  r.streak = app.streak();
  r.badges = app.badges().where((b) => b.earned).length;
  r.from = wk.first;
  r.to = today.compareTo(wk.last) < 0 ? today : wk.last;
  final inWeek = app.weights.where((w) => w.d.compareTo(wk.first) >= 0 && w.d.compareTo(wk.last) <= 0).toList();
  if (app.weights.isNotEmpty) {
    final prev = app.weights.where((w) => w.d.compareTo(wk.first) < 0).toList();
    final base = prev.isNotEmpty ? prev.last.kg : (inWeek.isNotEmpty ? inWeek.first.kg : null);
    final cur = inWeek.isNotEmpty ? inWeek.last.kg : null;
    if (base != null && cur != null) {
      final c = cur - base;
      r.weight = '${c > 0 ? '+' : c < 0 ? '-' : ''}${app.fmtD(c)}';
    } else {
      r.weight = app.fmtW(app.weights.last.kg);
    }
  }
  return r;
}

String weekSummaryText() {
  final r = _weekData();
  return '${tr('PUREBURN - MY WEEK')}\n${r.from} to ${r.to}\n\n'
      '${tr('Plan followed')}: ${r.score}%\n'
      '${tr('Workouts')}: ${r.workouts} / ${r.workoutsOf}\n'
      '${tr('Average calories')}: ${r.avgKcal} kcal\n'
      '${tr('Water goal met')}: ${r.waterDays} / 7\n'
      '${tr('Steps this week')}: ${r.steps}\n'
      '${tr('Weight')}: ${r.weight}\n'
      '${tr('Streak')}: ${r.streak}\n\n'
      'PureBurn - ${tr('BURN CLEAN. LIVE PURE.')}';
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final key = GlobalKey();
  bool busy = false;

  Future<void> _shareImage() async {
    setState(() => busy = true);
    try {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'pureburn-week.png')],
        fileNameOverrides: ['pureburn-week.png'],
        text: weekSummaryText(),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: weekSummaryText()));
      _snack(context, 'Sharing is not available here, so the summary was copied instead.');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = _weekData();
    Widget cell(String k, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(k, onDark: true),
            const SizedBox(height: 4),
            Text(v, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w300, color: Colors.white)),
          ]),
        );
    final card = RepaintBoundary(
      key: key,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFF0B0B0B), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BrandLockup(color: Colors.white),
            const SizedBox(height: 6),
            Text('${r.from}  →  ${r.to}', style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xFFA6A6A6))),
            const SizedBox(height: 22),
            Row(children: [
              RingGauge(fraction: r.score / 100, center: '${r.score}%', size: 104, ink: Colors.white, track: const Color(0xFF2A2A2A)),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Eyebrow('My week', onDark: true),
                  const SizedBox(height: 6),
                  Text(r.score >= 80 ? 'Excellent week' : r.score >= 60 ? 'Good week' : r.score >= 30 ? 'Keep going' : 'A fresh start', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('of the plan followed', style: TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6))),
                ]),
              ),
            ]),
            const SizedBox(height: 22),
            Row(children: [cell('Workouts', '${r.workouts} / ${r.workoutsOf}'), cell('Average calories', '${r.avgKcal}')]),
            const SizedBox(height: 16),
            Row(children: [cell('Water goal met', '${r.waterDays} / 7'), cell('Steps this week', '${r.steps}')]),
            const SizedBox(height: 16),
            Row(children: [cell('Weight', r.weight), cell('Streak', '${r.streak} ${r.streak == 1 ? 'day' : 'days'}')]),
            const SizedBox(height: 22),
            const Text('BURN CLEAN. LIVE PURE.', style: TextStyle(fontSize: 9.5, letterSpacing: 2, color: Color(0xFF7A7A7A))),
          ]),
        ),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Muted('A picture of your week. Share it on WhatsApp or save it.'),
      _g(14),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: card)),
      _g(16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: busy ? null : _shareImage, icon: const Icon(Icons.share_outlined), label: const Text('Share as image')),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: weekSummaryText()));
            _snack(context, 'Summary copied. You can paste it in WhatsApp or notes.');
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy as text'),
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- settings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final importC = TextEditingController();

  @override
  void dispose() {
    importC.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final text = app.exportJson();
    try {
      await Share.shareXFiles(
        [XFile.fromData(Uint8List.fromList(utf8.encode(text)), mimeType: 'application/json', name: 'pureburn-backup.json')],
        fileNameOverrides: ['pureburn-backup.json'],
        text: 'PureBurn backup',
      );
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: text));
    _snack(context, 'Backup copied. Paste it in a safe place such as WhatsApp to yourself or Notes.');
  }

  Future<void> _import() async {
    var text = importC.text;
    if (text.trim().isEmpty) {
      final c = await Clipboard.getData('text/plain');
      text = c?.text ?? '';
    }
    if (text.trim().isEmpty) {
      _snack(context, 'Paste your backup text first.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text('This replaces the data on this device with the backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    final err = app.importJson(text);
    importC.clear();
    _snack(context, err ?? 'Backup restored.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ServiceSettings(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Backup and restore'),
          const Muted('Your data lives only on this device. Save a backup so you do not lose it if you change phones or clear the app.'),
          _g(12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(onPressed: _export, icon: const Icon(Icons.upload_outlined), label: const Text('Save a backup')),
          ]),
          _g(18),
          const Muted('To restore, paste your backup text here and press Restore. If the box is empty the text on your clipboard is used.', size: 12),
          const SizedBox(height: 8),
          TextField(controller: importC, minLines: 2, maxLines: 4, decoration: InputDecoration(hintText: tr('Paste backup text here'))),
          _g(10),
          OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.download_outlined), label: const Text('Restore')),
        ]),
      ),
      _g(16),
      const Muted('PureBurn is a general guide only. Please talk to a doctor before making health decisions.', size: 12),
    ]);
  }
}
