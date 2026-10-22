import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter/services.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'features.dart';
import 'services.dart';
import 'ui.dart';

class ModuleView extends StatelessWidget {
  final String id;
  const ModuleView({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final d = app.d;
    if (id == 'profile') return ProfilePage();
    if (id == 'settings') return const SettingsPage();
    if (id == 'result' && d.ok) return const ResultPage();
    if (!d.ok) {
      return Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Some of your details are missing or out of range.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => app.go('profile'), child: const Text('Fix my details')),
        ]),
      );
    }
    switch (id) {
      case 'bmi':
        return BmiPage();
      case 'dex':
        return DexPage();
      case 'ddiet':
        return DdietPage();
      case 'explan':
        return ExPlanPage();
      case 'dietplan':
        return DietPlanPage();
      case 'progress':
        return ProgressPage();
      case 'measure':
        return const MeasurePage();
      case 'report':
        return const ReportPage();
      default:
        return DashboardPage();
    }
  }
}

Widget _blocked(Derived d) => Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.blocked ?? ''),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => app.go('profile'), child: const Text('Change my goal')),
      ]),
    );

Widget _grid(List<Widget> kids, {double min = 200}) => LayoutBuilder(builder: (c, bc) {
      final cols = (bc.maxWidth / min).floor().clamp(1, 4);
      final w = (bc.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: kids.map((k) => SizedBox(width: w, child: k)).toList());
    });

Widget _gap([double h = 16]) => SizedBox(height: h);

// ---------------- week strip ----------------
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});
  @override
  Widget build(BuildContext context) {
    final today = isoDate(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: app.weekDates().map((dt) {
          final dd = parseIso(dt);
          final sel = dt == app.selDate;
          final info = app.dayInfo(dt);
          final has = app.rowFor(dt) != null;
          final ink = sel ? Theme.of(context).colorScheme.surface : fg(context);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => app.selectDate(dt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? fg(context) : card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: dt == today ? fg(context) : line(context)),
                  ),
                  child: Column(children: [
                    Text(dayName(dd).substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 1, color: ink.withOpacity(0.7))),
                    Text('${dd.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w300, color: ink)),
                    SizedBox(height: 8, child: has ? Icon(Icons.circle, size: 5, color: ink) : null),
                    const SizedBox(height: 2),
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(value: info.score.clamp(0.0, 1.0), minHeight: 3, backgroundColor: ink.withOpacity(0.2), color: ink),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------- dashboard ----------------
// A short, branded summary of today. Full records live in each section.
class _Tk {
  final bool done;
  final String title, sub, to;
  const _Tk(this.done, this.title, this.sub, this.to);
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    final now = DateTime.now();
    final today = isoDate(now);
    final info = app.dayInfo(today);
    final st = app.streak();
    final L = app.logs[today];
    final row = app.rowFor(today);
    final kcalFrac = (d.plan != null && d.plan!.kcal > 0) ? info.kcal / d.plan!.kcal : 0.0;

    final items = <_Tk>[];
    if (d.plan != null) {
      if (row != null) {
        final n = sessionTasks(row).tasks.length;
        items.add(_Tk(info.exD == n, 'Workout: ${row.name}', '${info.exD} of $n tasks done', 'dex'));
      } else {
        items.add(const _Tk(true, 'Rest day', 'No workout scheduled today', 'dex'));
      }
      for (final m in d.diet!.meals) {
        items.add(_Tk(L != null && L.meal.contains(m.id), m.name, '${m.time} · ~${m.kcal} kcal', 'ddiet'));
      }
    }
    items.add(_Tk(info.water >= info.wg, 'Water', '${info.water} of ${info.wg} glasses', 'ddiet'));
    items.add(_Tk(info.steps >= d.stepGoal, 'Steps', '${info.steps} of ${d.stepGoal}', 'dex'));

    final greet = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';
    final left = info.total - info.done;
    final msg = info.total == 0
        ? 'Fill in your profile to get started.'
        : left <= 0
            ? 'Everything is done for today. Well played.'
            : '$left of ${info.total} tasks left today.';
    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3A3A3A)), borderRadius: BorderRadius.circular(99)),
          child: Text(t, style: const TextStyle(fontSize: 11.5, color: Color(0xFFD0D0D0))),
        );
    final hero = Box(
      dark: true,
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const BrandLockup(height: 22, color: Colors.white),
          const Spacer(),
          Text('${dayName(now).toUpperCase()} · ${now.day}/${now.month}', style: const TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: Color(0xFFA6A6A6))),
        ]),
        const SizedBox(height: 22),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greet, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w300, letterSpacing: -0.8, height: 1.1)),
              const SizedBox(height: 6),
              Text(msg, style: const TextStyle(color: Color(0xFFA6A6A6), height: 1.35, fontSize: 13.5)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                chip('Streak $st ${st == 1 ? 'day' : 'days'}'),
                chip('BMI ${d.bmi.toStringAsFixed(1)} · ${d.cat}'),
                if (d.plan != null) chip(d.plan!.headV),
              ]),
            ]),
          ),
          const SizedBox(width: 14),
          RingGauge(fraction: info.score, center: '${(info.score * 100).round()}%', size: 96, ink: Colors.white, track: const Color(0xFF2A2A2A)),
        ]),
      ]),
    );

    Widget nav(IconData icon, String t, String to) => InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => app.go(to),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(99), color: card(context)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      hero,
      _gap(12),
      _grid([
        _ringTile(context, 'Workout', info.exT > 0 ? info.exD / info.exT : 0.0, info.exT > 0 ? '${info.exD}/${info.exT}' : 'Rest', info.exT > 0 ? 'tasks done' : 'no session today', 'dex'),
        _ringTile(context, 'Calories', kcalFrac, '${(kcalFrac * 100).round()}%', '${info.kcal} kcal eaten', 'ddiet'),
        _ringTile(context, 'Water', info.wg > 0 ? info.water / info.wg : 0.0, '${info.water}/${info.wg}', 'glasses', 'ddiet'),
        _ringTile(context, 'Steps', d.stepGoal > 0 ? info.steps / d.stepGoal : 0.0, '${d.stepGoal > 0 ? (info.steps * 100 / d.stepGoal).round() : 0}%', '${info.steps} steps', 'dex'),
      ], min: 150),
      _gap(12),
      Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Eyebrow('Up next'), const SizedBox(height: 6), _TaskUpdates(items: items)])),
      _gap(12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        nav(Icons.speed_outlined, 'BMI and weight', 'bmi'),
        nav(Icons.calendar_month_outlined, 'Exercise plan', 'explan'),
        nav(Icons.list_alt_outlined, 'Diet plan', 'dietplan'),
        nav(Icons.show_chart, 'Progress', 'progress'),
      ]),
    ]);
  }
}

class _TaskUpdates extends StatefulWidget {
  final List<_Tk> items;
  const _TaskUpdates({required this.items});
  @override
  State<_TaskUpdates> createState() => _TaskUpdatesState();
}

class _TaskUpdatesState extends State<_TaskUpdates> {
  bool all = false;
  Widget _row(_Tk t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => app.go(t.to),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Pill(t.done ? 'Done' : 'Pending'),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (t.sub.isNotEmpty) Muted(t.sub, size: 12),
              ])),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pending = widget.items.where((t) => !t.done).toList();
    final shown = all ? widget.items : pending.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 4),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 10), child: Muted('All tasks are done for today.', size: 14)),
      for (final t in shown) _row(t),
      TextButton(
        onPressed: () => setState(() => all = !all),
        child: Text(all ? 'Show less' : 'Show all ${widget.items.length} tasks'),
      ),
    ]);
  }
}

class WeightChart extends StatelessWidget {
  const WeightChart({super.key});
  @override
  Widget build(BuildContext context) {
    if (app.weights.length < 2) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('Log your weight on two different days to see your chart.')));
    }
    final d = app.d;
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeInOut,
        builder: (context, t, _) => CustomPaint(
          painter: LineChart(app.weights.map((w) => app.toDisp(w.kg)).toList(), d.ok && d.goal != 'maintain' ? app.toDisp(d.tKg) : null, fg(context), line(context), t),
        ),
      ),
    );
  }
}

// ---------------- profile ----------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController age, cm, ft, inch, w, tw;

  @override
  void initState() {
    super.initState();
    final p = app.p;
    age = TextEditingController(text: '${p.age}');
    cm = TextEditingController(text: tidy(p.heightCm));
    final tin = p.heightCm / 2.54;
    final f = (tin / 12).floor();
    ft = TextEditingController(text: '$f');
    inch = TextEditingController(text: tidy(tin - f * 12));
    w = TextEditingController(text: tidy(app.toDisp(p.weightKg)));
    tw = TextEditingController(text: tidy(app.toDisp(app.d.ok ? app.d.tKg : p.weightKg)));
  }

  @override
  void dispose() {
    for (final c in [age, cm, ft, inch, w, tw]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  Widget _num(TextEditingController c, String unit, ValueChanged<String> onCh, {bool dec = true}) => TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: dec),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(suffixText: unit),
        onChanged: onCh,
      );

  @override
  Widget build(BuildContext context) {
    final p = app.p;
    final d = app.d;
    final goalNow = d.ok ? d.goal : (p.goal ?? 'maintain');
    final live = Box(
      dark: true,
      child: !d.ok
          ? const Text('Check your details: age 10 to 100, height 100 to 250 cm, weight 20 to 300 kg.')
          : Row(children: [
              Text(d.bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w200)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.cat, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(d.plan != null ? 'Goal: ${d.plan!.headV}. ${d.plan!.timeTxt}, ${d.plan!.kcal} kcal a day.' : (d.gNote.isEmpty ? '' : d.gNote), style: const TextStyle(color: Color(0xFFA6A6A6), fontSize: 13)),
              ])),
            ]),
    );

    final step1 = Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Step 01'),
        const SizedBox(height: 6),
        const H2('Your body'),
        Field('Weight unit', Seg<String>(opts: const [('metric', 'kg'), ('imperial', 'lb')], value: p.unit, onChanged: (v) {
          p.unit = v;
          w.text = tidy(app.toDisp(p.weightKg));
          tw.text = tidy(app.toDisp(d.ok ? d.tKg : p.weightKg));
          app.save();
        })),
        Field('Sex', Seg<String>(opts: const [('m', 'Male'), ('f', 'Female')], value: p.sex, onChanged: (v) { p.sex = v; app.save(); })),
        Field('Age', _num(age, 'yrs', (v) { final n = int.tryParse(v); if (n != null) { p.age = n; app.save(); } }, dec: false)),
        Field(
          'Height',
          Row(children: [
            Expanded(flex: 3, child: _num(cm, 'cm', (v) {
              final n = _n(cm);
              if (n == null) return;
              p.heightCm = n;
              final tin = n / 2.54;
              final f = (tin / 12).floor();
              ft.text = '$f';
              inch.text = tidy(tin - f * 12);
              app.save();
            })),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _num(ft, 'ft', (v) => _fromFt(), dec: false)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _num(inch, 'in', (v) => _fromFt())),
          ]),
          hint: 'Type in centimetres or in feet and inches. The other updates by itself.',
        ),
        Field('Current weight', _num(w, app.unitLbl(), (v) { final n = _n(w); if (n != null) { p.weightKg = (app.fromDisp(n) * 100).round() / 100; app.save(); } })),
        Field(
          'Daily activity, outside workouts',
          DropdownButtonFormField<String>(
            value: p.act,
            items: const [
              DropdownMenuItem(value: 'sedentary', child: Text('Mostly sitting (desk job)')),
              DropdownMenuItem(value: 'light', child: Text('On my feet some of the day')),
              DropdownMenuItem(value: 'moderate', child: Text('On my feet most of the day')),
              DropdownMenuItem(value: 'active', child: Text('Very physical work all day')),
            ],
            onChanged: (v) { if (v != null) { p.act = v; app.save(); } },
          ),
        ),
        Field('BMI standard', Seg<String>(opts: const [('asia', 'South Asian'), ('who', 'WHO general')], value: p.std, onChanged: (v) { p.std = v; app.save(); }),
            hint: 'In South Asian populations, health risks begin at a lower BMI (23), so this is the default.'),
      ]),
    );
    final step2 = Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Step 02'),
        const SizedBox(height: 6),
        const H2('Your goal'),
        Field('Goal', Seg<String>(opts: const [('lose', 'Lose'), ('maintain', 'Maintain'), ('gain', 'Gain')], value: goalNow, onChanged: (v) {
          p.goal = v;
          p.targetKg = null;
          app.save();
          tw.text = tidy(app.toDisp(app.d.ok ? app.d.tKg : p.weightKg));
        }), hint: 'Chosen for you from your BMI. Change it any time.'),
        if (goalNow != 'maintain') ...[
          Field('Target weight', _num(tw, app.unitLbl(), (v) { final n = _n(tw); if (n != null) { p.targetKg = (app.fromDisp(n) * 100).round() / 100; app.save(); } })),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () { p.targetKg = null; app.save(); tw.text = tidy(app.toDisp(app.d.tKg)); }, child: const Text('Use my best weight'))),
          Field('Pace', Seg<String>(opts: const [('gentle', 'Gentle'), ('steady', 'Steady'), ('fast', 'Faster')], value: p.pace, onChanged: (v) { p.pace = v; app.save(); }),
              hint: d.g == null ? null : 'Aim for about ${app.fmtD(d.g!.pace)} per week.'),
        ],
        Field('Workout days per week', Seg<int>(opts: const [(3, '3 days'), (4, '4 days'), (5, '5 days')], value: p.days, onChanged: (v) { p.days = v; app.save(); })),
        Field('Where you exercise', Seg<String>(opts: const [('home', 'At home'), ('gym', 'At a gym')], value: p.place, onChanged: (v) { p.place = v; app.save(); })),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      live,
      _gap(),
      LayoutBuilder(builder: (c, bc) {
        if (bc.maxWidth > 760) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: step1), const SizedBox(width: 16), Expanded(child: step2)]);
        }
        return Column(children: [step1, _gap(), step2]);
      }),
      _gap(),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Submit and see my plan'),
        ),
      ),
      _gap(12),
      const Muted('Your details are saved automatically on this device.'),
    ]);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!app.d.ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Check your details: age 10 to 100, height 100 to 250 cm, weight 20 to 300 kg.'),
      ));
      return;
    }
    app.save();
    Reminders.apply();
    app.go('result');
  }

  void _fromFt() {
    final f = _n(ft) ?? 0;
    final i = _n(inch) ?? 0;
    final c = ((f * 12 + i) * 2.54 * 10).round() / 10;
    app.p.heightCm = c;
    cm.text = tidy(c);
    app.save();
  }
}

// ---------------- bmi ----------------
class BmiPage extends StatelessWidget {
  const BmiPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    const s0 = 14.0, s1 = 40.0;
    double pos(double v) => ((v - s0) / (s1 - s0)).clamp(0.0, 1.0);
    final segs = [
      (s0, d.loBmi, 'Under'),
      (d.loBmi, d.hiStart, 'Healthy'),
      (d.hiStart, d.obStart, 'Over'),
      (d.obStart, s1, 'Obese'),
    ];
    final shades = [0.25, 1.0, 0.55, 0.8];
    final hero = Box(
      dark: true,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Your BMI', onDark: true),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: d.bmi),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w200, height: 0.95, letterSpacing: -3)),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(99), color: d.cls == 'ok' || d.cls == 'bad' ? Colors.white : null),
            child: Text(d.cat.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: d.cls == 'ok' || d.cls == 'bad' ? Colors.black : Colors.white)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(d.text, style: const TextStyle(color: Color(0xFFA6A6A6), height: 1.4)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (c, bc) {
          final w = bc.maxWidth;
          return SizedBox(
            height: 74,
            child: Stack(children: [
              for (var i = 0; i < segs.length; i++)
                Positioned(
                  left: pos(segs[i].$1) * w,
                  width: (pos(segs[i].$2) - pos(segs[i].$1)) * w - 3,
                  top: 28,
                  child: Container(height: 14, decoration: BoxDecoration(color: Colors.white.withOpacity(shades[i]), borderRadius: BorderRadius.circular(4))),
                ),
              for (var i = 0; i < segs.length; i++)
                Positioned(
                  left: (pos(segs[i].$1) + pos(segs[i].$2)) / 2 * w - 28,
                  width: 56,
                  top: 50,
                  child: Text(segs[i].$3.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, letterSpacing: 0.8, color: Color(0xFFA6A6A6))),
                ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: pos(d.bmi)),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(children: [Positioned(left: v * w - 1, top: 4, child: Container(width: 3, height: 44, color: Colors.white))]),
              ),
            ]),
          );
        }),
      ]),
    );
    final range = '${tidy(app.toDisp(d.minKg))} to ${app.fmtW(d.maxKg)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      hero,
      _gap(),
      _grid([
        Stat('Best weight', app.fmtW(d.target), s: 'Ideal target for your height', inverse: true),
        Stat('Healthy range', range, s: 'BMI 18.5 to ${d.hiBmi.toStringAsFixed(1)}'),
        Stat('To reach best weight', d.changeV, s: d.changeS),
      ], min: 220),
      _gap(),
      if (d.plan != null) ...[
        if (d.gNote.isNotEmpty) Box(child: Text(d.gNote)),
        if (d.gNote.isNotEmpty) _gap(),
        _glance(d),
      ] else
        _blocked(d),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Ideal weight formula'),
          const SizedBox(height: 10),
          for (final f in d.formulas) _trow(f.key, app.fmtW(f.value)),
          const Divider(),
          _trow('Average', app.fmtW(d.avg), bold: true),
        ]),
      ),
      _gap(),
      if (d.h < 140) const Muted('Below 140 cm the ideal weight formulas are less reliable. Rely more on the BMI-based healthy range.'),
      const Muted('PureBurn is a general guide only. BMI is not accurate for athletes or pregnant women. Please talk to a doctor before making health decisions.'),
    ]);
  }
}

Widget _trow(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );

Widget _glance(Derived d) {
  final p = d.plan!;
  return _grid([
    Stat('Your goal', p.headV, s: p.headS, inverse: true),
    Stat('Time to goal', p.timeTxt, s: p.paceS),
    Stat('Daily calories', '${p.kcal} kcal', s: 'Includes about ${(p.E / 5).round() * 5} kcal a day to fuel your workouts'),
    Stat('Workouts', '${d.g!.days} days a week', s: 'About ${(p.weekly / 10).round() * 10} kcal burned a week'),
  ], min: 220);
}

// ---------------- daily exercise ----------------
class DexPage extends StatelessWidget {
  const DexPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    if (d.blocked != null) return _blocked(d);
    final date = app.selDate;
    final L = app.logs[date];
    final row = app.rowFor(date);
    final info = app.dayInfo(date);
    final dn = dayName(parseIso(date));
    Widget main;
    if (row != null) {
      final st = sessionTasks(row);
      final done = st.tasks.where((t) => L != null && L.ex.contains(t.id)).length;
      main = Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow("$dn's session"),
          const SizedBox(height: 6),
          Text(row.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [Pill('${row.min} min'), Pill('About ${(row.kcal / 5).round() * 5} kcal'), Pill(d.g!.place == 'home' ? 'At home' : 'At a gym')]),
          const SizedBox(height: 14),
          Bar(done / st.tasks.length),
          const SizedBox(height: 4),
          Muted('$done of ${st.tasks.length} done'),
          const SizedBox(height: 14),
          for (final t in st.tasks)
            TaskRow(done: L != null && L.ex.contains(t.id), onChanged: (v) => app.tick('ex', t.id, v), body: Text(t.text, style: const TextStyle(height: 1.35))),
          if (st.notes.isNotEmpty) ...[const SizedBox(height: 8), const Text('How to do it', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Bullets(st.notes)],
          const SizedBox(height: 14),
          Wrap(spacing: 10, children: [
            FilledButton(onPressed: () => app.markAll('ex', true), child: const Text('Mark everything done')),
            OutlinedButton(onPressed: () => app.markAll('ex', false), child: const Text('Clear')),
          ]),
        ]),
      );
    } else {
      main = Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(dn),
          const SizedBox(height: 6),
          const Text('Rest day', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Muted('Your muscles grow and recover on rest days. Keep moving gently if you feel like it.', size: 14),
          const SizedBox(height: 14),
          TaskRow(done: L != null && L.ex.contains('r0'), onChanged: (v) => app.tick('ex', 'r0', v), body: const Text('Easy 20 to 30 minute walk (optional)')),
          TaskRow(done: L != null && L.ex.contains('r1'), onChanged: (v) => app.tick('ex', 'r1', v), body: const Text('10 minutes of stretching (optional)')),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WeekStrip(),
      main,
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Steps'),
          _StepsField(key: ValueKey(date), initial: info.steps),
          const SizedBox(height: 12),
          Bar(info.steps / d.stepGoal),
          const SizedBox(height: 6),
          Muted('Goal ${d.stepGoal} a day'),
        ]),
      ),
      _gap(),
      _exerciseRecord(context),
    ]);
  }
}

class _StepsField extends StatelessWidget {
  final int initial;
  const _StepsField({super.key, required this.initial});
  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: initial == 0 ? '' : '$initial',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: 'steps', hintText: '0'),
        onChanged: (v) => app.setSteps(int.tryParse(v) ?? 0),
      );
}

// ---------------- daily diet ----------------
Widget _budget() => Field(
      'Your food budget',
      Seg<String>(opts: const [('low', 'Tight'), ('std', 'Standard'), ('high', 'Comfortable')], value: app.p.budget, onChanged: (v) { app.p.budget = v; app.save(); }),
      hint: {'low': 'Daal, chana, eggs and seasonal sabzi do most of the work.', 'std': 'Chicken for protein, with daal, eggs, fruit and sabzi.', 'high': 'Fish, nuts and a wider choice of fruit and protein.'}[app.p.budget],
    );

class DdietPage extends StatelessWidget {
  const DdietPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    if (d.blocked != null) return _blocked(d);
    final date = app.selDate;
    final L = app.logs[date];
    final info = app.dayInfo(date);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WeekStrip(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${info.kcal}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w300, letterSpacing: -1.5)),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Muted('of ${d.plan!.kcal} kcal eaten')),
          ]),
          const SizedBox(height: 8),
          Bar(info.kcal / d.plan!.kcal),
          const SizedBox(height: 6),
          Muted('Food cost so far ${rs(info.cost, 5)} of about ${rs(d.diet!.daily, 5)} for the day', size: 12),
        ]),
      ),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _budget(),
          for (final m in d.diet!.meals)
            TaskRow(
              done: L != null && L.meal.contains(m.id),
              onChanged: (v) => app.tick('meal', m.id, v),
              body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Muted(m.time, size: 12),
                const SizedBox(height: 4),
                Bullets(m.items),
              ]),
              trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Pill('~${m.kcal} kcal'), const SizedBox(height: 6), Pill(rs(m.cost, 5))]),
            ),
          Wrap(spacing: 10, children: [
            FilledButton(onPressed: () => app.markAll('meal', true), child: const Text('I ate everything')),
            OutlinedButton(onPressed: () => app.markAll('meal', false), child: const Text('Clear')),
          ]),
        ]),
      ),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Water'),
          Muted('${info.water} of ${info.wg} glasses (250 ml each). Tap a glass to fill up to it.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < info.wg; i++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => app.setWater(i),
                child: Container(
                  width: 44,
                  height: 52,
                  decoration: BoxDecoration(
                    color: i < info.water ? fg(context) : soft(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i < info.water ? fg(context) : Theme.of(context).colorScheme.outline, width: 1.5),
                  ),
                ),
              ),
          ]),
        ]),
      ),
      _gap(),
      _dietRecord(context),
    ]);
  }
}

// ---------------- exercise plan ----------------
class ExPlanPage extends StatelessWidget {
  const ExPlanPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    if (d.blocked != null) return _blocked(d);
    final p = d.plan!, g = d.g!;
    final seen = <String>{};
    final details = <Widget>[];
    for (final r in p.sched) {
      if (!seen.add(r.key)) continue;
      details.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Muted('${r.min} minutes', size: 12),
          const SizedBox(height: 6),
          Bullets(r.items),
        ]),
      ));
    }
    final steps = {'lose': '8,000 to 10,000', 'maintain': '7,000 to 9,000', 'gain': '6,000 to 8,000'}[g.goal]!;
    final goalNote = {
      'lose': 'Strength days protect your muscle while you lose fat, and cardio days raise the calories you burn.',
      'maintain': 'A mix of strength and cardio keeps your weight, muscle and fitness steady.',
      'gain': 'Strength training makes sure the extra weight you gain is mostly muscle. Keep cardio light.',
    }[g.goal]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (d.gNote.isNotEmpty) ...[Box(child: Text(d.gNote)), _gap()],
      Pill('${p.headV} · ${p.timeTxt} · ${p.kcal} kcal a day'),
      _gap(),
      Text(goalNote, style: const TextStyle(fontSize: 15, height: 1.45)),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Your week'),
          for (final r in p.sched)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(width: 92, child: Text(r.day, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(r.name, style: const TextStyle(fontSize: 13))),
                Text('${r.min} min · ${(r.kcal / 5).round() * 5}', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          const Muted('Other days are rest days. Calorie burn (kcal) is an estimate for your current weight.', size: 12),
        ]),
      ),
      _gap(),
      Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('What to do in each session'), ...details])),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('How to progress'),
          Bullets([
            'Weeks 1 and 2: do 2 sets of each exercise and focus on good form. Rest 60 to 90 seconds between sets.',
            'Weeks 3 and 4: move up to the full number of sets.',
            'From week 5: when every rep feels easy, add load (a heavier bag of books, or 2.5 kg more at the gym) and lengthen cardio.',
            'Aim for $steps steps a day on every day, including rest days.',
            'Warm up for 5 minutes before each session and stretch for 5 minutes after.',
            'Come back here every 4 weeks with your new weight to refresh the plan.',
          ]),
        ]),
      ),
      _gap(),
      Muted('Stop and rest if you feel chest pain, dizziness or unusual breathlessness. ${g.lowImpact ? 'This plan avoids jumping and running to protect your joints. ' : ''}${d.age >= 40 ? 'At your age, get a check-up before starting if you have been inactive for a long time. ' : ''}${p.care}'),
      _gap(),
      FilledButton(onPressed: () => app.go('dex'), child: const Text("Start today's workout")),
    ]);
  }
}

// ---------------- diet plan ----------------
class DietPlanPage extends StatelessWidget {
  const DietPlanPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.d;
    if (d.blocked != null) return _blocked(d);
    final p = d.plan!, df = d.diet!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (d.gNote.isNotEmpty) ...[Box(child: Text(d.gNote)), _gap()],
      Pill('${p.headV} · ${p.timeTxt} · ${p.kcal} kcal a day'),
      _gap(),
      Box(child: _budget()),
      _gap(),
      _grid([
        Stat('Food cost', '${rs(df.daily, 5)} / day', s: 'About ${rs(df.daily * 30, 100)} a month', inverse: true),
        Stat('Daily split', '${p.pG}P / ${p.cG}C / ${p.fG}F', s: 'Grams of protein, carbs and fat'),
      ], min: 220),
      _gap(),
      Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Where your calories come from'), MacroBar(pG: p.pG, cG: p.cG, fG: p.fG)])),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Sample day, with cost'),
          for (final m in df.meals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))), Pill(rs(m.cost, 5))]),
                Muted(m.time, size: 12),
                const SizedBox(height: 6),
                Bullets(m.items),
              ]),
            ),
        ]),
      ),
      _gap(),
      Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Eating tips for your goal'), Bullets(df.goalTips)])),
      _gap(),
      Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Save money'), Bullets(df.moneyTips)])),
      _gap(),
      const Muted('Costs are a guide for one person. Prices of atta, daal, eggs, dahi, milk, chicken, tomatoes, onions and bananas follow national averages from the Pakistan Bureau of Statistics weekly report (early June 2026). Fruit, fish, nuts and cooking costs are estimates, and prices change by city and season.'),
      _gap(8),
      Muted('${df.floorNote}Calories are estimates based on your age, sex, size, daily activity and the workouts planned. The plan never goes below ${p.floorKcal} kcal a day when losing weight. ${p.care}'),
      _gap(),
      FilledButton(onPressed: () => app.go('ddiet'), child: const Text("Track today's meals")),
    ]);
  }
}

// ---------------- progress ----------------
class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late final TextEditingController wc;
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final last = app.weights.isEmpty ? app.p.weightKg : app.weights.last.kg;
    wc = TextEditingController(text: tidy(app.toDisp(last)));
  }

  @override
  void dispose() {
    wc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = app.d;
    final ws = app.weights.reversed.toList();
    final first = app.weights.isEmpty ? null : app.weights.first.kg;
    final lastW = app.weights.isEmpty ? null : app.weights.last.kg;
    final change = first == null ? 0.0 : lastW! - first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Log your weight'),
          Row(children: [
            OutlinedButton(
              onPressed: () async {
                final r = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (r != null) setState(() => date = r);
              },
              child: Text(isoDate(date)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: wc,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(suffixText: app.unitLbl()),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                final n = double.tryParse(wc.text.replaceAll(',', '.'));
                if (n != null) {
                  app.addWeight(isoDate(date), app.fromDisp(n));
                }
              },
              child: const Text('Save'),
            ),
          ]),
        ]),
      ),
      _gap(),
      _grid([
        Stat('Change', first == null ? '--' : '${change > 0 ? '+' : change < 0 ? '-' : ''}${app.fmtD(change)}', s: first == null ? 'No entries yet' : 'Since ${app.weights.first.d}', inverse: true),
        Stat('Current', lastW == null ? '--' : app.fmtW(lastW), s: d.goal != 'maintain' && lastW != null ? '${app.fmtD(d.tKg - lastW)} to go' : 'Latest entry'),
      ], min: 220),
      _gap(),
      Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Weight over time'), WeightChart()])),
      _gap(),
      _progressWeek(context),
      _gap(),
      const TrendsBox(),
      _gap(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('History'),
          if (ws.isEmpty) const Muted('No weight entries yet.'),
          for (final w in ws.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: Text(w.d, style: TextStyle(color: muted(context)))),
                  Text(app.fmtW(w.kg), style: const TextStyle(fontSize: 18)),
                  IconButton(onPressed: () => app.delWeight(w.d), icon: const Icon(Icons.close, size: 18)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ---------------- result (after Submit) ----------------
class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  static const _actLbl = {
    'sedentary': 'Mostly sitting',
    'light': 'On my feet some of the day',
    'moderate': 'On my feet most of the day',
    'active': 'Very physical work',
  };
  static const _paceLbl = {'gentle': 'Gentle', 'steady': 'Steady', 'fast': 'Faster'};
  static const _goalLbl = {'lose': 'Lose weight', 'maintain': 'Maintain weight', 'gain': 'Gain weight'};

  String _height() {
    final tin = app.p.heightCm / 2.54;
    final f = (tin / 12).floor();
    return '${tidy(app.p.heightCm)} cm (${f} ft ${tidy(tin - f * 12)} in)';
  }

  String _summary() {
    final p = app.p, d = app.d;
    final b = StringBuffer();
    b.writeln('PUREBURN - MY PLAN');
    b.writeln('');
    b.writeln('DETAILS');
    b.writeln('Sex: ${p.sex == 'm' ? 'Male' : 'Female'}');
    b.writeln('Age: ${p.age} years');
    b.writeln('Height: ${_height()}');
    b.writeln('Weight: ${app.fmtW(p.weightKg)}');
    b.writeln('Daily activity: ${_actLbl[p.act] ?? p.act}');
    b.writeln('BMI: ${d.bmi.toStringAsFixed(1)} (${d.cat})');
    b.writeln('Healthy range: ${tidy(app.toDisp(d.minKg))} to ${app.fmtW(d.maxKg)}');
    b.writeln('Best weight: ${app.fmtW(d.target)}');
    final pl = d.plan;
    if (pl == null || d.g == null) {
      b.writeln(d.blocked ?? '');
      return b.toString();
    }
    b.writeln('');
    b.writeln('GOAL');
    b.writeln('Goal: ${pl.headV}');
    b.writeln('Time: ${pl.timeTxt}');
    b.writeln('Daily calories: ${pl.kcal} kcal');
    b.writeln('Daily split: ${pl.pG}g protein, ${pl.cG}g carbs, ${pl.fG}g fat');
    b.writeln('Workouts: ${d.g!.days} days a week, ${p.place == 'home' ? 'at home' : 'at a gym'}');
    b.writeln('');
    b.writeln('EXERCISE PLAN');
    for (final r in pl.sched) {
      b.writeln('${r.day}: ${r.name} (${r.min} min)');
      for (final it in r.items) {
        b.writeln('  - $it');
      }
    }
    b.writeln('Other days are rest days.');
    b.writeln('');
    b.writeln('DIET PLAN (sample day)');
    for (final m in d.diet!.meals) {
      b.writeln('${m.time} - ${m.name}');
      for (final it in m.items) {
        b.writeln('  - $it');
      }
    }
    b.writeln('Food cost: about ${rs(d.diet!.daily, 5)} a day');
    b.writeln('');
    b.writeln('PureBurn is a general guide only. Please talk to a doctor before making health decisions.');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final d = app.d, p = app.p;
    final hero = Box(
      dark: true,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Your plan is ready', onDark: true),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(d.bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w200, height: 0.95, letterSpacing: -2)),
          const SizedBox(width: 14),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(d.cat.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          )),
        ]),
        const SizedBox(height: 12),
        Text(
          d.plan != null ? 'Goal: ${d.plan!.headV}. ${d.plan!.timeTxt}, ${d.plan!.kcal} kcal a day.' : (d.blocked ?? d.text),
          style: const TextStyle(color: Color(0xFFA6A6A6), height: 1.4),
        ),
      ]),
    );

    final details = Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Your details'),
        const SizedBox(height: 6),
        _trow('Sex', p.sex == 'm' ? 'Male' : 'Female'),
        _trow('Age', '${p.age} years'),
        _trow('Height', _height()),
        _trow('Current weight', app.fmtW(p.weightKg)),
        _trow('Daily activity', _actLbl[p.act] ?? p.act),
        _trow('BMI standard', p.std == 'asia' ? 'South Asian' : 'WHO general'),
        const Divider(),
        _trow('Goal', _goalLbl[d.goal] ?? d.goal, bold: true),
        if (d.goal != 'maintain') _trow('Target weight', app.fmtW(d.tKg)),
        if (d.goal != 'maintain') _trow('Pace', _paceLbl[p.pace] ?? p.pace),
        _trow('Workout days', '${p.days} a week'),
        _trow('Where you exercise', p.place == 'home' ? 'At home' : 'At a gym'),
        const Divider(),
        _trow('Best weight', app.fmtW(d.target)),
        _trow('Healthy range', '${tidy(app.toDisp(d.minKg))} to ${app.fmtW(d.maxKg)}'),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      hero,
      _gap(),
      details,
      _gap(),
      if (d.plan != null) ...[_glance(d), _gap()],
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _summary()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary copied. You can paste it in WhatsApp or notes.')));
            }
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy summary to share'),
        ),
        OutlinedButton.icon(
          onPressed: () => app.go('profile'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit details'),
        ),
      ]),
      _gap(28),
      const Eyebrow('Your sections'),
      const SizedBox(height: 6),
      const H2('Open any section to see its full result'),
      if (d.blocked != null) _blocked(d) else _sectionCards(context),
    ]);
  }
}


// ---------------- week bar chart and per-section records ----------------
class WeekBars extends StatelessWidget {
  final List<String> dates;
  final List<double> fracs;
  final List<String> labels;
  const WeekBars({super.key, required this.dates, required this.fracs, required this.labels});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(dates.length, (i) => Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(labels[i], style: TextStyle(fontSize: 9.5, color: muted(context))),
                const SizedBox(height: 4),
                Container(
                  width: 22,
                  height: 90,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(color: soft(context), borderRadius: BorderRadius.circular(8)),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: (fracs[i].isNaN ? 0.0 : fracs[i]).clamp(0.0, 1.0)),
                    duration: Duration(milliseconds: 600 + i * 110),
                    curve: Curves.easeOutCubic,
                    builder: (context, h, _) => FractionallySizedBox(
                      heightFactor: h,
                      child: Container(decoration: BoxDecoration(color: fg(context), borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(dayName(parseIso(dates[i])).substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 9.5, color: muted(context))),
              ]),
            )),
      ),
    );
  }
}

Widget _exerciseRecord(BuildContext context) {
  final d = app.d;
  final wk = app.weekDates();
  final infos = wk.map(app.dayInfo).toList();
  final today = isoDate(DateTime.now());
  var sched = 0, done = 0, stepsTotal = 0, stepDays = 0;
  for (var i = 0; i < 7; i++) {
    if (app.rowFor(wk[i]) != null) {
      sched++;
      if (infos[i].exT > 0 && infos[i].exD / infos[i].exT >= 0.8) done++;
    }
    if (wk[i].compareTo(today) <= 0) {
      stepsTotal += infos[i].steps;
      stepDays++;
    }
  }
  final avgSteps = stepDays == 0 ? 0 : (stepsTotal / stepDays).round();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Eyebrow('Record'),
    const SizedBox(height: 6),
    const H2('This week in exercise'),
    _grid([
      Stat('Sessions done', '$done of $sched', s: 'Counted when 80% of tasks are done', inverse: true),
      Stat('Steps this week', '$stepsTotal', s: 'Average $avgSteps a day'),
    ], min: 200),
    _gap(),
    Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Workout tasks done'),
        WeekBars(
          dates: wk,
          fracs: [for (final x in infos) x.exT > 0 ? x.exD / x.exT : 0.0],
          labels: [for (final x in infos) x.exT > 0 ? '${x.exD}/${x.exT}' : 'Rest'],
        ),
      ]),
    ),
    _gap(),
    Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Steps each day'),
        WeekBars(
          dates: wk,
          fracs: [for (final x in infos) d.stepGoal > 0 ? x.steps / d.stepGoal : 0.0],
          labels: [for (final x in infos) x.steps == 0 ? '-' : '${x.steps}'],
        ),
        const SizedBox(height: 6),
        Muted('Goal ${d.stepGoal} a day', size: 12),
      ]),
    ),
  ]);
}

Widget _dietRecord(BuildContext context) {
  final d = app.d;
  final wk = app.weekDates();
  final infos = wk.map(app.dayInfo).toList();
  final today = isoDate(DateTime.now());
  var kcalTotal = 0, kcalDays = 0, waterDays = 0, meals = 0;
  for (var i = 0; i < 7; i++) {
    meals += infos[i].mD;
    if (wk[i].compareTo(today) <= 0) {
      if (infos[i].kcal > 0) {
        kcalTotal += infos[i].kcal;
        kcalDays++;
      }
      if (infos[i].water >= infos[i].wg) waterDays++;
    }
  }
  final avgKcal = kcalDays == 0 ? 0 : (kcalTotal / kcalDays).round();
  final target = d.plan?.kcal ?? 1;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Eyebrow('Record'),
    const SizedBox(height: 6),
    const H2('This week in food and water'),
    _grid([
      Stat('Average calories', '$avgKcal', s: kcalDays == 0 ? 'No meals ticked yet' : 'Target $target kcal a day', inverse: true),
      Stat('Meals eaten', '$meals', s: 'Ticked this week'),
      Stat('Water goal met', '$waterDays of 7 days', s: 'Glasses of 250 ml'),
    ], min: 170),
    _gap(),
    Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Calories each day'),
        WeekBars(
          dates: wk,
          fracs: [for (final x in infos) x.kcal / target],
          labels: [for (final x in infos) x.kcal == 0 ? '-' : '${x.kcal}'],
        ),
        const SizedBox(height: 6),
        Muted('Full bar is your target of $target kcal', size: 12),
      ]),
    ),
    _gap(),
    Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Water each day'),
        WeekBars(
          dates: wk,
          fracs: [for (final x in infos) x.wg > 0 ? x.water / x.wg : 0.0],
          labels: [for (final x in infos) '${x.water}/${x.wg}'],
        ),
      ]),
    ),
  ]);
}

Widget _progressWeek(BuildContext context) {
  final wk = app.weekDates();
  final infos = wk.map(app.dayInfo).toList();
  final today = isoDate(DateTime.now());
  final avg = (infos.fold<double>(0, (a, x) => a + x.score) / 7 * 100).round();
  final st = app.streak();
  final recent = <Widget>[];
  for (var i = wk.length - 1; i >= 0; i--) {
    if (wk[i].compareTo(today) > 0) continue;
    recent.add(Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Text(dayName(parseIso(wk[i])), style: const TextStyle(fontWeight: FontWeight.w500))),
          Text('${infos[i].done} of ${infos[i].total} tasks  '),
          Pill('${(infos[i].score * 100).round()}%'),
        ]),
      ),
    ));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _grid([
      Stat('Streak', '$st ${st == 1 ? 'day' : 'days'}', s: 'Days with 60% of tasks done', inverse: true),
      Stat('Week average', '$avg%', s: 'Workout, meals and water'),
    ], min: 200),
    _gap(),
    Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Tasks done this week'),
        WeekBars(
          dates: wk,
          fracs: [for (final x in infos) x.score],
          labels: [for (final x in infos) '${(x.score * 100).round()}%'],
        ),
      ]),
    ),
    _gap(),
    Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Recent days'), ...recent])),
  ]);
}

Widget _sectionCards(BuildContext context) {
  final d = app.d;
  final pl = d.plan!, df = d.diet!;
  final today = isoDate(DateTime.now());
  final info = app.dayInfo(today);
  final row = app.rowFor(today);
  Widget secCard(IconData icon, String title, String result, String to) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => app.go(to),
        child: Box(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Muted(result, size: 12.5),
            ])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
  return _grid([
    secCard(Icons.speed_outlined, 'BMI and weight', 'BMI ${d.bmi.toStringAsFixed(1)} · ${d.cat}. Best weight ${app.fmtW(d.target)}', 'bmi'),
    secCard(Icons.calendar_month_outlined, 'Exercise plan', '${d.g!.days} days a week, about ${(pl.weekly / 10).round() * 10} kcal burned a week', 'explan'),
    secCard(Icons.list_alt_outlined, 'Diet plan', '${pl.kcal} kcal a day, about ${rs(df.daily, 5)} of food a day', 'dietplan'),
    secCard(Icons.fitness_center, 'Daily exercise', row == null ? 'Rest day today' : 'Today: ${row.name}', 'dex'),
    secCard(Icons.restaurant_outlined, 'Daily diet', '${info.kcal} of ${pl.kcal} kcal eaten today', 'ddiet'),
    secCard(Icons.show_chart, 'Progress', app.weights.isEmpty ? 'Log your weight to start your chart' : '${app.weights.length} weight entries · latest ${app.fmtW(app.weights.last.kg)}', 'progress'),
  ], min: 300);
}


Widget _ringTile(BuildContext context, String title, double frac, String center, String sub, String to) => InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => app.go(to),
      child: Box(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(title),
          const SizedBox(height: 10),
          Row(children: [
            RingGauge(fraction: frac, center: center, size: 64),
            const SizedBox(width: 10),
            Expanded(child: Muted(sub, size: 12)),
          ]),
        ]),
      ),
    );
