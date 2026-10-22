// Workout player (exercise guide, timers, sets and reps log, levels) and sleep tracker.
import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'exlib.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'pages.dart' show WeekStrip, WeekBars;
import 'state.dart';
import 'ui.dart';

Widget _g([double h = 16]) => SizedBox(height: h);

String _mmss(int s) => '${two(s ~/ 60)}:${two(s % 60)}';

String get _level => '${app.set['level'] ?? 'inter'}';
int get _restSec => ((app.set['restSec'] ?? 60) as num).toInt();

// ---------------------------------------------------------------- workout player
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});
  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  Timer? _t;
  int rest = 0, restTotal = 0, holdLeft = 0, warm = 0, cardio = 0;
  String timerLabel = '';
  bool cardioOn = false;
  final open = <String>{};
  final timerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    app.persist();
    super.dispose();
  }

  void _buzz() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _tick() {
    var ch = false;
    if (rest > 0) {
      rest--;
      ch = true;
      if (rest == 0) _buzz();
    }
    if (holdLeft > 0) {
      holdLeft--;
      ch = true;
      if (holdLeft == 0) _buzz();
    }
    if (warm > 0) {
      warm--;
      ch = true;
      if (warm == 0) _buzz();
    }
    if (cardioOn) {
      cardio++;
      ch = true;
    }
    if (ch && mounted) setState(() {});
  }

  void _show() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = timerKey.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), alignment: 0.1);
    });
  }

  void _startRest() {
    setState(() {
      rest = restTotal = _restSec;
      timerLabel = 'Rest';
    });
    _show();
  }

  void _toggleSet(ExItem e, int n, String date, int i) {
    final l = app.setsFor(date, e.name, n, repsFor(e, _level), 0);
    final s = l[i];
    s.done = !s.done;
    if (s.done) buzz();
    app.persist();
    final all = l.take(n).every((x) => x.done);
    app.tick('ex', e.id, all);
    if (s.done && !all) _startRest();
    if (s.done && all) {
      setState(() {
        rest = 0;
        timerLabel = '';
      });
    }
    setState(() {});
  }

  Widget _timerCard() {
    final active = rest > 0 || holdLeft > 0 || warm > 0;
    if (!active) return const SizedBox.shrink();
    final secs = holdLeft > 0 ? holdLeft : rest > 0 ? rest : warm;
    final label = holdLeft > 0 ? 'Hold' : rest > 0 ? 'Rest' : 'Warm up';
    return Padding(
      key: timerKey,
      padding: const EdgeInsets.only(bottom: 16),
      child: Box(
        dark: true,
        child: Row(children: [
          RingGauge(fraction: holdLeft > 0 ? 0 : (rest > 0 ? rest / (restTotal == 0 ? 1 : restTotal) : warm / 300), center: _mmss(secs), size: 84, ink: Colors.white, track: const Color(0xFF2A2A2A)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(label, onDark: true),
              const SizedBox(height: 4),
              Text(label == 'Rest' ? 'Catch your breath' : label == 'Hold' ? timerLabel : 'Easy movement to get warm', style: const TextStyle(fontSize: 15, color: Colors.white)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF555555)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  onPressed: () => setState(() {
                    if (holdLeft > 0) {
                      holdLeft += 10;
                    } else if (rest > 0) {
                      rest += 15;
                      restTotal += 15;
                    } else {
                      warm += 30;
                    }
                  }),
                  child: Text(holdLeft > 0 ? '+10 s' : rest > 0 ? '+15 s' : '+30 s'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF555555)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  onPressed: () => setState(() {
                    rest = 0;
                    holdLeft = 0;
                    warm = 0;
                  }),
                  child: const Text('Skip'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _info(ExInfo i) => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: soft(context), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600))), Pill(i.muscles)]),
          const SizedBox(height: 8),
          for (var k = 0; k < i.steps.length; k++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 22, child: Text('${k + 1}.', style: TextStyle(color: muted(context), fontSize: 13))),
                Expanded(child: Text(i.steps[k], style: const TextStyle(fontSize: 13.5, height: 1.4))),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Tip: ${i.tip}', style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Easier: ${i.easier}', style: TextStyle(fontSize: 12.5, height: 1.4, color: muted(context))),
          Text('Harder: ${i.harder}', style: TextStyle(fontSize: 12.5, height: 1.4, color: muted(context))),
        ]),
      );

  Widget _setRow(ExItem e, int n, String date, int i, List<SetLog> l) {
    final s = l[i];
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(children: [
        SizedBox(width: 44, child: Text('Set ${i + 1}', style: TextStyle(color: muted(context), fontSize: 12.5))),
        SizedBox(
          width: 76,
          child: TextFormField(
            key: ValueKey('$date|${e.name}|$i|r'),
            initialValue: '${s.reps}',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(isDense: true, labelText: e.hold ? 'sec' : 'reps', floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
            onChanged: (v) {
              s.reps = int.tryParse(v) ?? s.reps;
              app.persist();
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: TextFormField(
            key: ValueKey('$date|${e.name}|$i|k'),
            initialValue: s.kg == 0 ? '' : tidy(s.kg),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true, labelText: 'kg', floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
            onChanged: (v) {
              s.kg = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              app.persist();
            },
          ),
        ),
        const Spacer(),
        if (e.hold)
          IconButton(
            tooltip: 'Start hold timer',
            onPressed: () {
              setState(() {
                holdLeft = s.reps.clamp(3, 600);
                timerLabel = '${e.name}, set ${i + 1}';
              });
              _show();
            },
            icon: const Icon(Icons.timer_outlined),
          ),
        Checkbox(value: s.done, onChanged: (_) => _toggleSet(e, n, date, i), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      ]),
    );
  }

  Widget _exercise(ExItem e, String date) {
    final n = setsFor(e, _level);
    final last = app.lastSet(date, e.name);
    final l = app.setsFor(date, e.name, n, repsFor(e, _level), last?.kg ?? 0);
    final done = l.take(n).where((s) => s.done).length;
    final info = exInfoFor(e.name);
    final isOpen = open.contains(e.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, height: 1.3))),
            const SizedBox(width: 8),
            Pill('$done / $n'),
          ]),
          const SizedBox(height: 4),
          Muted(targetText(e, _level), size: 12.5),
          if (e.note != null) Muted(e.note!, size: 12),
          if (last != null) Muted('Last time: ${tidy(last.kg)} kg × ${last.reps}${_level == 'adv' ? '. Try ${tidy(last.kg + 2.5)} kg today.' : ''}', size: 12),
          if (info != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => isOpen ? open.remove(e.name) : open.add(e.name)),
                icon: Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 18),
                label: const Text('How to do it'),
              ),
            ),
          if (info != null && isOpen) _info(info),
          const SizedBox(height: 6),
          for (var i = 0; i < n; i++) _setRow(e, n, date, i, l),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = app.d;
    final date = app.selDate;
    final row = app.rowFor(date);
    final L = app.logs[date];
    final head = Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Field(
          'Your level',
          Seg<String>(opts: const [('beg', 'Beginner'), ('inter', 'Intermediate'), ('adv', 'Advanced')], value: _level, onChanged: (v) => setState(() => app.setPref('level', v))),
          hint: _level == 'beg' ? 'One set fewer, the lower number of reps, and a slow pace.' : _level == 'adv' ? 'One extra set, more reps and heavier weights. Slow the lowering.' : 'The sets and reps from your plan.',
        ),
        Field('Rest between sets', Seg<int>(opts: const [(30, '30 s'), (60, '60 s'), (90, '90 s'), (120, '2 min')], value: _restSec, onChanged: (v) => setState(() => app.setPref('restSec', v)))),
      ]),
    );
    if (row == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WeekStrip(),
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Rest day'), const Muted('No workout is planned for this day. Your muscles grow and recover on rest days. An easy walk is always welcome.')])),
        _g(),
        head,
      ]);
    }
    final st = sessionTasks(row);
    final strength = st.notes.isEmpty;
    final items = <ExItem>[];
    if (strength) {
      for (final t in st.tasks) {
        final it = parseEx(t.id, t.text);
        if (it != null) items.add(it);
      }
    }
    var setsTotal = 0, setsDone = 0;
    var volume = 0.0;
    for (final e in items) {
      final n = setsFor(e, _level);
      final l = app.wlog[date]?[e.name] ?? const <SetLog>[];
      setsTotal += n;
      for (final s in l.take(n)) {
        if (s.done) {
          setsDone++;
          volume += s.reps * s.kg;
        }
      }
    }
    final target = row.min * 60;
    final cardioInfo = exInfoFor(st.notes.isNotEmpty ? st.notes.first : '');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const WeekStrip(),
      _timerCard(),
      Box(
        dark: true,
        child: Row(children: [
          RingGauge(
            fraction: strength ? (setsTotal == 0 ? 0 : setsDone / setsTotal) : (target == 0 ? 0 : cardio / target),
            center: strength ? '$setsDone/$setsTotal' : _mmss(cardio),
            size: 92,
            ink: Colors.white,
            track: const Color(0xFF2A2A2A),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Today\'s session', onDark: true),
              const SizedBox(height: 4),
              Text(row.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300, height: 1.2)),
              const SizedBox(height: 6),
              Text(strength ? '${row.min} min · $setsDone of $setsTotal sets${volume > 0 ? ' · ${volume.round()} kg lifted' : ''}' : '${row.min} min target', style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6))),
            ]),
          ),
        ]),
      ),
      _g(12),
      head,
      _g(12),
      TaskRow(
        done: L != null && L.ex.contains('wu'),
        onChanged: (v) => app.tick('ex', 'wu', v),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Warm up for 5 minutes', style: TextStyle(fontWeight: FontWeight.w600)),
          Muted('March on the spot, circle your arms and hips, and do 10 easy squats.', size: 12),
        ]),
        trailing: TextButton(
          onPressed: () {
            setState(() => warm = 300);
            _show();
          },
          child: const Text('Timer'),
        ),
      ),
      if (strength)
        for (final e in items) _exercise(e, date)
      else ...[
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H2(row.name),
            Row(children: [
              Expanded(child: Text(_mmss(cardio), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300, letterSpacing: -1.5))),
              Muted('of ${row.min}:00'),
            ]),
            const SizedBox(height: 8),
            Bar(target == 0 ? 0 : cardio / target),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(onPressed: () => setState(() => cardioOn = !cardioOn), icon: Icon(cardioOn ? Icons.pause : Icons.play_arrow), label: Text(cardioOn ? 'Pause' : (cardio > 0 ? 'Resume' : 'Start'))),
              OutlinedButton(onPressed: () => setState(() {
                    cardio = 0;
                    cardioOn = false;
                  }), child: const Text('Reset')),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => cardioOn = false);
                  app.tick('ex', 'main', !(L != null && L.ex.contains('main')));
                },
                icon: Icon((L != null && L.ex.contains('main')) ? Icons.check_circle : Icons.check_circle_outline),
                label: Text((L != null && L.ex.contains('main')) ? 'Done' : 'Mark as done'),
              ),
            ]),
            const SizedBox(height: 12),
            Bullets(st.notes),
            const Muted('Keep the screen on while the timer runs.', size: 12),
          ]),
        ),
        if (cardioInfo != null) ...[
          _g(12),
          Box(child: _info(cardioInfo)),
        ],
        _g(12),
      ],
      TaskRow(
        done: L != null && L.ex.contains('cd'),
        onChanged: (v) => app.tick('ex', 'cd', v),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Cool down and stretch for 5 minutes', style: TextStyle(fontWeight: FontWeight.w600)),
          Muted('Walk slowly, then stretch your thighs, back and shoulders. Breathe out as you stretch.', size: 12),
        ]),
      ),
      _g(8),
      Muted(d.ok ? 'Your sets are saved on this device. Tick a set when it is done and the rest timer starts.' : '', size: 12),
    ]);
  }
}

// ---------------------------------------------------------------- sleep
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});
  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  double? hours;
  int? quality;

  double get _goal => ((app.set['sleepGoal'] ?? 8) as num).toDouble();

  @override
  Widget build(BuildContext context) {
    final date = app.selDate;
    final L = app.logs[date];
    final saved = L?.sleep ?? 0;
    final h = hours ?? (saved > 0 ? saved : 7.5);
    final q = quality ?? ((L?.sleepQ ?? 0) > 0 ? L!.sleepQ : 3);
    final wk = app.weekDates();
    final today = isoDate(DateTime.now());
    final logged = [for (final dt in wk) if (dt.compareTo(today) <= 0 && (app.logs[dt]?.sleep ?? 0) > 0) app.logs[dt]!.sleep];
    final avg = logged.isEmpty ? 0.0 : logged.reduce((a, b) => a + b) / logged.length;
    final debt = logged.fold<double>(0, (a, b) => a + (b < _goal ? _goal - b : 0));
    final met = logged.where((x) => x >= _goal - 0.5).length;
    String tip;
    if (logged.isEmpty) {
      tip = 'Log last night to start. Most adults need 7 to 9 hours.';
    } else if (avg >= _goal - 0.5) {
      tip = 'Great sleep. Your body recovers and burns fat better when you sleep well.';
    } else if (avg >= 6.5) {
      tip = 'A little short. Try going to bed 30 minutes earlier and keep your phone away for the last half hour.';
    } else {
      tip = 'You are short on sleep. Poor sleep raises hunger and cravings, so protect your bedtime this week.';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const WeekStrip(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Last night\'s sleep'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.outlined(onPressed: () => setState(() => hours = (h - 0.5).clamp(1, 14)), icon: const Icon(Icons.remove)),
            SizedBox(width: 130, child: Center(child: Text('${tidy(h)} h', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w300, letterSpacing: -1)))),
            IconButton.outlined(onPressed: () => setState(() => hours = (h + 0.5).clamp(1, 14)), icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 14),
          const Muted('How did you sleep?', size: 12.5),
          const SizedBox(height: 6),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setState(() => quality = i),
                icon: Icon(i <= q ? Icons.star : Icons.star_border, size: 30),
              ),
          ]),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              final l = app.log(date);
              l.sleep = h;
              l.sleepQ = q;
              buzz(true);
              app.save();
              setState(() {
                hours = null;
                quality = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep saved.')));
            },
            child: Text(saved > 0 ? 'Update sleep' : 'Save sleep'),
          ),
        ]),
      ),
      _g(),
      Box(
        dark: true,
        child: Row(children: [
          RingGauge(fraction: avg / _goal, center: avg == 0 ? '--' : tidy(avg), size: 92, ink: Colors.white, track: const Color(0xFF2A2A2A)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Average this week', onDark: true),
              const SizedBox(height: 4),
              Text(avg == 0 ? 'No nights yet' : '${tidy(avg)} hours', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
              const SizedBox(height: 6),
              Text(tip, style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6), height: 1.4)),
            ]),
          ),
        ]),
      ),
      _g(12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Sleep this week'),
          WeekBars(
            dates: wk,
            fracs: [for (final dt in wk) (app.logs[dt]?.sleep ?? 0) / _goal],
            labels: [for (final dt in wk) (app.logs[dt]?.sleep ?? 0) == 0 ? '-' : tidy(app.logs[dt]!.sleep)],
          ),
          const SizedBox(height: 6),
          Muted('Full bar is your goal of ${tidy(_goal)} hours. Nights at goal: $met. Sleep owed this week: ${tidy(debt)} h.', size: 12),
        ]),
      ),
      _g(12),
      Box(
        child: Field(
          'Sleep goal',
          Seg<double>(opts: const [(7, '7 h'), (8, '8 h'), (9, '9 h')], value: _goal, onChanged: (v) => setState(() => app.setPref('sleepGoal', v))),
          hint: 'Most adults feel best with 7 to 9 hours.',
        ),
      ),
      _g(12),
      const Muted('A general guide only. If you often feel very tired or have trouble sleeping, please talk to a doctor.', size: 12),
    ]);
  }
}
