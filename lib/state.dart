import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logic.dart';

class AppState extends ChangeNotifier {
  Profile p = Profile();
  Map<String, DayLog> logs = {};
  List<WeightEntry> weights = [];
  String mod = 'dashboard';
  String selDate = isoDate(DateTime.now());
  ThemeMode theme = ThemeMode.system;
  Derived d = Derived();
  SharedPreferences? _sp;
  String lang = 'en'; // en | ur | rur
  List<Measure> measures = [];
  // Settings kept on this device: reminders, auto steps, app lock.
  Map<String, dynamic> set = {
    'water': false, 'waterEvery': 2,
    'wk': false, 'wkH': 18, 'wkM': 0,
    'meals': false,
    'autoSteps': false,
    'lock': false, 'pinHash': '', 'bio': false,
  };
  bool unlocked = false;
  String lockNote = '';

  AppState() {
    d = derive(p);
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    try {
      final raw = _sp!.getString('pureburn-state-v1');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        p.fromJson((j['p'] ?? {}) as Map<String, dynamic>);
        logs = {};
        ((j['logs'] ?? {}) as Map<String, dynamic>).forEach((k, v) => logs[k] = DayLog.fromJson(v as Map<String, dynamic>));
        weights = ((j['weights'] ?? []) as List).map((e) => WeightEntry(e['d'] as String, (e['kg'] as num).toDouble())).toList();
        measures = ((j['meas'] ?? []) as List).map((e) => Measure.fromJson(e as Map<String, dynamic>)).toList();
      }
      final sraw = _sp!.getString('pureburn-settings');
      if (sraw != null) set.addAll(jsonDecode(sraw) as Map<String, dynamic>);
      final lg = _sp!.getString('pureburn-lang');
      if (lg == 'ur' || lg == 'rur' || lg == 'en') lang = lg!;
      final t = _sp!.getString('pureburn-theme');
      if (t == 'dark') theme = ThemeMode.dark;
      if (t == 'light') theme = ThemeMode.light;
    } catch (_) {}
    d = derive(p);
    // Deep link for the web version, for example ?mod=progress opens the Progress section.
    final q = Uri.base.queryParameters['mod'];
    if (q != null && const ['dashboard', 'profile', 'result', 'bmi', 'dex', 'ddiet', 'explan', 'dietplan', 'progress', 'measure', 'report', 'settings'].contains(q)) {
      mod = q;
    }
    final ql = Uri.base.queryParameters['lang'];
    if (ql == 'ur' || ql == 'rur' || ql == 'en') lang = ql!;
    unlocked = !(set['lock'] == true && (set['pinHash'] as String).isNotEmpty) || Uri.base.queryParameters.containsKey('nolock');
    loaded = true;
    notifyListeners();
  }

  bool loaded = false;

  SharedPreferences? get prefs => _sp;

  void refresh() => notifyListeners();

  void setLang(String l) {
    lang = l;
    _sp?.setString('pureburn-lang', l);
    notifyListeners();
  }

  void saveSettings() {
    _sp?.setString('pureburn-settings', jsonEncode(set));
    notifyListeners();
  }

  // ---- measurements ----
  void addMeasure(Measure m) {
    measures.removeWhere((x) => x.d == m.d);
    measures.add(m);
    measures.sort((a, b) => a.d.compareTo(b.d));
    save();
  }

  void delMeasure(String date) {
    measures.removeWhere((x) => x.d == date);
    save();
  }

  // ---- backup ----
  String exportJson() => jsonEncode({
        'app': 'pureburn',
        'v': 1,
        'saved': isoDate(DateTime.now()),
        'p': p.toJson(),
        'logs': logs.map((k, v) => MapEntry(k, v.toJson())),
        'weights': weights.map((w) => {'d': w.d, 'kg': w.kg}).toList(),
        'meas': measures.map((m) => m.toJson()).toList(),
        'lang': lang,
      });

  /// Returns null when the text was restored, otherwise a short error message.
  String? importJson(String text) {
    try {
      final j = jsonDecode(text.trim());
      if (j is! Map || j['app'] != 'pureburn') return 'This is not a PureBurn backup.';
      final np = Profile();
      np.fromJson((j['p'] ?? {}) as Map<String, dynamic>);
      final nl = <String, DayLog>{};
      ((j['logs'] ?? {}) as Map<String, dynamic>).forEach((k, v) => nl[k] = DayLog.fromJson(v as Map<String, dynamic>));
      final nw = ((j['weights'] ?? []) as List).map((e) => WeightEntry(e['d'] as String, (e['kg'] as num).toDouble())).toList();
      final nm = ((j['meas'] ?? []) as List).map((e) => Measure.fromJson(e as Map<String, dynamic>)).toList();
      p = np;
      logs = nl;
      weights = nw;
      measures = nm;
      final lg = j['lang'];
      if (lg == 'ur' || lg == 'rur' || lg == 'en') setLang(lg as String);
      save();
      return null;
    } catch (_) {
      return 'The backup text could not be read.';
    }
  }

  // ---- badges ----
  List<Achv> badges() {
    var tasksDone = 0, bestScore = 0.0, waterDays = 0, maxSteps = 0, perfect = 0;
    logs.forEach((k, v) {
      if (v.ex.isNotEmpty || v.meal.isNotEmpty) tasksDone++;
      if (v.steps > maxSteps) maxSteps = v.steps;
      final i = dayInfo(k);
      if (i.score > bestScore) bestScore = i.score;
      if (d.ok && i.water >= i.wg && i.wg > 0) waterDays++;
      if (i.total > 0 && i.score >= 0.999) perfect++;
    });
    final st = streak();
    var lost = 0.0;
    if (weights.length >= 2) lost = weights.first.kg - weights.last.kg;
    return [
      Achv('start', 'First step', 'Tick your first task', Icons.flag_outlined, tasksDone >= 1),
      Achv('s3', '3-day streak', 'Three good days in a row', Icons.local_fire_department_outlined, st >= 3),
      Achv('s7', '7-day streak', 'A full week of good days', Icons.whatshot_outlined, st >= 7),
      Achv('s30', '30-day streak', 'A whole month. Wow', Icons.workspace_premium_outlined, st >= 30),
      Achv('perfect', 'Perfect day', 'Finish every task in one day', Icons.check_circle_outline, perfect >= 1),
      Achv('water', 'Water hero', 'Meet your water goal on 5 days', Icons.water_drop_outlined, waterDays >= 5),
      Achv('steps', '10,000 steps', 'Walk 10,000 steps in a day', Icons.directions_walk, maxSteps >= 10000),
      Achv('w5', 'Weight tracker', 'Log your weight 5 times', Icons.monitor_weight_outlined, weights.length >= 5),
      Achv('m1', 'Tape measure', 'Log your first measurements', Icons.straighten, measures.isNotEmpty),
      Achv('l1', 'First kilo', 'Lose 1 kg from your first entry', Icons.trending_down, lost >= 1),
      Achv('l5', 'Five kilos', 'Lose 5 kg from your first entry', Icons.emoji_events_outlined, lost >= 5),
    ];
  }

  void save() {
    final cutoff = isoDate(DateTime.now().subtract(const Duration(days: 120)));
    logs.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    d = derive(p);
    final sp = _sp;
    if (sp != null) {
      sp.setString(
          'pureburn-state-v1',
          jsonEncode({
            'p': p.toJson(),
            'logs': logs.map((k, v) => MapEntry(k, v.toJson())),
            'weights': weights.map((w) => {'d': w.d, 'kg': w.kg}).toList(),
            'meas': measures.map((m) => m.toJson()).toList(),
          }));
    }
    notifyListeners();
  }

  void go(String m) {
    mod = m;
    notifyListeners();
  }

  void selectDate(String s) {
    selDate = s;
    notifyListeners();
  }

  void toggleTheme(bool dark) {
    theme = dark ? ThemeMode.light : ThemeMode.dark;
    _sp?.setString('pureburn-theme', theme == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  DayLog log(String date) => logs.putIfAbsent(date, () => DayLog());

  SchedRow? rowFor(String date) {
    final pl = d.plan;
    if (pl == null) return null;
    final dn = dayName(parseIso(date));
    for (final r in pl.sched) {
      if (r.day == dn) return r;
    }
    return null;
  }

  DayInfo dayInfo(String date) {
    final L = logs[date];
    final i = DayInfo();
    final wg = d.ok ? d.waterGoal : 8;
    i.wg = wg;
    i.water = L?.water ?? 0;
    i.steps = L?.steps ?? 0;
    if (d.ok && d.plan != null) {
      final row = rowFor(date);
      if (row != null) {
        final st = sessionTasks(row);
        i.exT = st.tasks.length;
        for (final t in st.tasks) {
          if (L != null && L.ex.contains(t.id)) i.exD++;
        }
      }
      i.mT = d.diet!.meals.length;
      for (final m in d.diet!.meals) {
        if (L != null && L.meal.contains(m.id)) {
          i.mD++;
          i.kcal += m.kcal;
          i.cost += m.cost;
        }
      }
    }
    i.total = i.exT + i.mT + 1;
    i.done = i.exD + i.mD + (i.water >= wg ? 1 : 0);
    i.score = i.total > 0 ? i.done / i.total : 0;
    return i;
  }

  int streak() {
    var n = 0;
    final today = DateTime.now();
    for (var i = 0; i < 60; i++) {
      final dt = today.subtract(Duration(days: i));
      if (dayInfo(isoDate(dt)).score >= 0.6) {
        n++;
      } else if (i == 0) {
        continue;
      } else {
        break;
      }
    }
    return n;
  }

  List<String> weekDates() {
    var dt = DateTime.now();
    dt = DateTime(dt.year, dt.month, dt.day - (dt.weekday - 1));
    return List.generate(7, (i) => isoDate(DateTime(dt.year, dt.month, dt.day + i)));
  }

  void tick(String grp, String id, bool on) {
    final L = log(selDate);
    final set = grp == 'ex' ? L.ex : L.meal;
    if (on) {
      set.add(id);
    } else {
      set.remove(id);
    }
    save();
  }

  void markAll(String grp, bool on) {
    final L = log(selDate);
    final set = grp == 'ex' ? L.ex : L.meal;
    final ids = grp == 'meal'
        ? d.diet!.meals.map((m) => m.id).toList()
        : (rowFor(selDate) == null ? <String>[] : sessionTasks(rowFor(selDate)!).tasks.map((t) => t.id).toList());
    if (on) {
      set.addAll(ids);
    } else {
      set.removeAll(ids);
    }
    save();
  }

  void setWater(int i) {
    final L = log(selDate);
    L.water = L.water == i + 1 ? i : i + 1;
    save();
  }

  void setSteps(int v) {
    log(selDate).steps = v;
    save();
  }

  void addWeight(String date, double kg) {
    if (kg < 20 || kg > 300) return;
    weights.removeWhere((w) => w.d == date);
    weights.add(WeightEntry(date, (kg * 10).round() / 10));
    weights.sort((a, b) => a.d.compareTo(b.d));
    if (date == isoDate(DateTime.now())) p.weightKg = (kg * 10).round() / 10;
    save();
  }

  void delWeight(String date) {
    weights.removeWhere((w) => w.d == date);
    save();
  }

  // unit helpers
  double toDisp(double kg) => p.unit == 'metric' ? kg : kg / kgPerLb;
  double fromDisp(double v) => p.unit == 'metric' ? v : v * kgPerLb;
  String unitLbl() => p.unit == 'metric' ? 'kg' : 'lb';
  String fmtW(double kg) => p.unit == 'metric' ? '${kg.toStringAsFixed(1)} kg' : '${(kg / kgPerLb).toStringAsFixed(1)} lb';
  String fmtD(double kg) => fmtW(kg.abs());
}

class DayInfo {
  int exT = 0, exD = 0, mT = 0, mD = 0, water = 0, wg = 8, kcal = 0, steps = 0, total = 0, done = 0;
  double cost = 0, score = 0;
}

class Measure {
  final String d;
  final double waist, chest, hip; // cm, 0 means not measured
  Measure(this.d, {this.waist = 0, this.chest = 0, this.hip = 0});
  Map<String, dynamic> toJson() => {'d': d, 'waist': waist, 'chest': chest, 'hip': hip};
  static Measure fromJson(Map<String, dynamic> j) => Measure(j['d'] as String,
      waist: ((j['waist'] ?? 0) as num).toDouble(), chest: ((j['chest'] ?? 0) as num).toDouble(), hip: ((j['hip'] ?? 0) as num).toDouble());
}

class Achv {
  final String id, title, desc;
  final IconData icon;
  final bool earned;
  Achv(this.id, this.title, this.desc, this.icon, this.earned);
}
