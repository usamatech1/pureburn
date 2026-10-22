import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logic.dart';
import 'cloud.dart';
import 'foods.dart';
import 'dietfit.dart';

class AppState extends ChangeNotifier {
  Profile p = Profile();
  Map<String, DayLog> logs = {};
  List<WeightEntry> weights = [];
  String mod = 'dashboard';
  String selDate = isoDate(DateTime.now());
  ThemeMode theme = ThemeMode.system;
  Derived d = Derived();
  SharedPreferences? _sp;
  List<Measure> measures = [];
  // Settings kept on this device: reminders, auto steps, app lock.
  Map<String, dynamic> set = {
    'water': false, 'waterEvery': 2,
    'wk': false, 'wkH': 18, 'wkM': 0,
    'meals': false,
    'autoSteps': false,
    'lock': false, 'pinHash': '', 'bio': false,
    'dietType': 'any', 'allergies': <String>[],
    'ramadan': false, 'sehri': '04:30', 'iftar': '18:30',
  };
  Map<String, List<FoodEntry>> food = {}; // food diary by date
  List<Food> customFoods = [];
  Map<String, String> swaps = {}; // meal id -> template id
  Set<String> shopDone = {};
  Map<String, Map<String, List<SetLog>>> wlog = {}; // workout sets by date and exercise
  bool unlocked = false;
  String lockNote = '';

  AppState() {
    _rebuild();
  }

  void _rebuild() {
    d = derive(p);
    if (d.ok && d.diet != null) applyPrefs(d, set, swaps, customFoods, p.budget);
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    cloud.exporter = exportJson;
    cloud.onRemote = (t) async => importJson(t);
    await cloud.load(_sp!);
    final backFromGoogle = cloud.justSignedIn || cloud.status.startsWith('Google sign-in');
    try {
      final raw = _sp!.getString('pureburn-state-v1');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        p.fromJson((j['p'] ?? {}) as Map<String, dynamic>);
        logs = {};
        ((j['logs'] ?? {}) as Map<String, dynamic>).forEach((k, v) => logs[k] = DayLog.fromJson(v as Map<String, dynamic>));
        weights = ((j['weights'] ?? []) as List).map((e) => WeightEntry(e['d'] as String, (e['kg'] as num).toDouble())).toList();
        measures = ((j['meas'] ?? []) as List).map((e) => Measure.fromJson(e as Map<String, dynamic>)).toList();
        food = {};
        ((j['food'] ?? {}) as Map<String, dynamic>).forEach((k, v) => food[k] = [for (final e in v as List) FoodEntry.fromJson(e as Map<String, dynamic>)]);
        customFoods = [for (final e in (j['cfoods'] ?? []) as List) Food.fromJson(e as Map<String, dynamic>)];
        swaps = {for (final e in ((j['swaps'] ?? {}) as Map<String, dynamic>).entries) e.key: '${e.value}'};
        shopDone = {for (final e in (j['shop'] ?? []) as List) '$e'};
        wlog = _wlogFrom(j['wlog']);
      }
      final sraw = _sp!.getString('pureburn-settings');
      if (sraw != null) {
        set.addAll(jsonDecode(sraw) as Map<String, dynamic>);
        set['allergies'] = [for (final a in (set['allergies'] ?? const []) as List) '$a'];
      }

      final t = _sp!.getString('pureburn-theme');
      if (t == 'dark') theme = ThemeMode.dark;
      if (t == 'light') theme = ThemeMode.light;
    } catch (_) {}
    _rebuild();
    // Deep link for the web version, for example ?mod=progress opens the Progress section.
    final q = Uri.base.queryParameters['mod'];
    if (q != null && const ['dashboard', 'profile', 'result', 'bmi', 'dex', 'ddiet', 'explan', 'dietplan', 'progress', 'measure', 'report', 'settings', 'foods', 'shop', 'workout', 'sleep', 'health', 'coach', 'challenges', 'account'].contains(q)) {
      mod = q;
    }
    final qp = Uri.base.queryParameters;
    welcomed = _sp!.getBool('pureburn-welcomed') == true ||
        _sp!.getString('pureburn-state-v1') != null ||
        d.ok ||
        cloud.signedIn ||
        !cloudConfigured ||
        qp.containsKey('mod') ||
        qp.containsKey('nolock');
    if (backFromGoogle) mod = 'account';
    unlocked = !(set['lock'] == true && (set['pinHash'] as String).isNotEmpty) || Uri.base.queryParameters.containsKey('nolock');
    loaded = true;
    notifyListeners();
  }

  bool loaded = false;
  // First run: sign in (or skip), then goals, then the dashboard.
  bool welcomed = true;

  void finishWelcome() {
    welcomed = true;
    _sp?.setBool('pureburn-welcomed', true);
    mod = d.ok ? 'dashboard' : 'profile';
    notifyListeners();
  }

  static const prefKeys = ['dietType', 'allergies', 'ramadan', 'sehri', 'iftar', 'level', 'restSec', 'sleepGoal', 'health', 'healthOk', 'hread', 'haptics'];

  SharedPreferences? get prefs => _sp;

  void refresh() => notifyListeners();

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

  // ---- workout log ----
  Map<String, dynamic> _wlogTo() => wlog.map((d, m) => MapEntry(d, m.map((ex, l) => MapEntry(ex, l.map((s) => s.toJson()).toList()))));

  Map<String, Map<String, List<SetLog>>> _wlogFrom(Object? raw) {
    final out = <String, Map<String, List<SetLog>>>{};
    if (raw is Map) {
      raw.forEach((d, m) {
        final inner = <String, List<SetLog>>{};
        (m as Map).forEach((ex, l) => inner['$ex'] = [for (final e in l as List) SetLog.fromJson(e as Map<String, dynamic>)]);
        out['$d'] = inner;
      });
    }
    return out;
  }

  /// The sets logged for an exercise on a date, grown to at least n rows.
  List<SetLog> setsFor(String date, String ex, int n, int reps, double kg) {
    final l = wlog.putIfAbsent(date, () => {}).putIfAbsent(ex, () => []);
    while (l.length < n) {
      l.add(SetLog(reps, kg, false));
    }
    return l;
  }

  /// The most recent earlier sets of this exercise that had a weight.
  SetLog? lastSet(String date, String ex) {
    final keys = wlog.keys.where((k) => k.compareTo(date) < 0).toList()..sort();
    for (final k in keys.reversed) {
      final l = wlog[k]![ex];
      if (l == null) continue;
      for (final s in l.reversed) {
        if (s.done && s.kg > 0) return s;
      }
    }
    return null;
  }

  int totalSetsDone() {
    var n = 0;
    for (final m in wlog.values) {
      for (final l in m.values) {
        n += l.where((s) => s.done).length;
      }
    }
    return n;
  }

  // ---- food diary ----
  void addFood(String date, FoodEntry e) {
    food.putIfAbsent(date, () => []).add(e);
    save();
  }

  void removeFood(String date, int i) {
    final l = food[date];
    if (l == null || i < 0 || i >= l.length) return;
    l.removeAt(i);
    save();
  }

  void addCustomFood(Food f) {
    customFoods.add(f);
    save();
  }

  void removeCustomFood(String id) {
    customFoods.removeWhere((f) => f.id == id);
    save();
  }

  void setSwap(String mealId, String? tmplId) {
    if (tmplId == null) {
      swaps.remove(mealId);
    } else {
      swaps[mealId] = tmplId;
    }
    save();
  }

  void setPref(String k, Object? v) {
    set[k] = v;
    saveSettings();
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
        'food': food.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'cfoods': customFoods.map((f) => f.toJson()).toList(),
        'swaps': swaps,
        'wlog': _wlogTo(),
        'prefs': {for (final k in prefKeys) k: set[k]},
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
      final nf = <String, List<FoodEntry>>{};
      ((j['food'] ?? {}) as Map<String, dynamic>).forEach((k, v) => nf[k] = [for (final e in v as List) FoodEntry.fromJson(e as Map<String, dynamic>)]);
      customFoods = [for (final e in (j['cfoods'] ?? []) as List) Food.fromJson(e as Map<String, dynamic>)];
      swaps = {for (final e in ((j['swaps'] ?? {}) as Map<String, dynamic>).entries) e.key: '${e.value}'};
      food = nf;
      wlog = _wlogFrom(j['wlog']);
      final pr = j['prefs'];
      if (pr is Map) {
        for (final k in prefKeys) {
          if (pr[k] != null) set[k] = pr[k];
        }
        set['allergies'] = [for (final a in (set['allergies'] ?? const []) as List) '$a'];
        saveSettings();
      }
      p = np;
      logs = nl;
      weights = nw;
      measures = nm;
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
    var goodNights = 0;
    logs.forEach((k, v) {
      if (v.sleep >= 7) goodNights++;
    });
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
      Achv('sleep', 'Well rested', 'Sleep 7 hours or more on 5 nights', Icons.bedtime_outlined, goodNights >= 5),
      Achv('sets', 'Set counter', 'Complete 30 logged sets', Icons.fitness_center, totalSetsDone() >= 30),
      Achv('l1', 'First kilo', 'Lose 1 kg from your first entry', Icons.trending_down, lost >= 1),
      Achv('l5', 'Five kilos', 'Lose 5 kg from your first entry', Icons.emoji_events_outlined, lost >= 5),
    ];
  }

  void save() {
    final cutoff = isoDate(DateTime.now().subtract(const Duration(days: 120)));
    logs.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    food.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    wlog.removeWhere((k, _) => k.compareTo(cutoff) < 0);
    _rebuild();
    persist();
    flushNow();
    notifyListeners();
  }

  /// Writes the data to the device without rebuilding the screens.
  Timer? _pt;

  /// Keystroke friendly: waits a moment and writes once. save() writes at once.
  void persist() {
    _pt?.cancel();
    _pt = Timer(const Duration(milliseconds: 350), flushNow);
    cloud.markDirty();
  }

  void flushNow() {
    _pt?.cancel();
    _pt = null;
    final sp = _sp;
    if (sp != null) {
      sp.setString(
          'pureburn-state-v1',
          jsonEncode({
            'p': p.toJson(),
            'logs': logs.map((k, v) => MapEntry(k, v.toJson())),
            'weights': weights.map((w) => {'d': w.d, 'kg': w.kg}).toList(),
            'meas': measures.map((m) => m.toJson()).toList(),
            'food': food.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
            'cfoods': customFoods.map((f) => f.toJson()).toList(),
            'swaps': swaps,
            'shop': shopDone.toList(),
            'wlog': _wlogTo(),
          }));
    }
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
          i.p += m.mp;
          i.c += m.mc;
          i.f += m.mf;
        }
      }
    }
    for (final e in food[date] ?? const <FoodEntry>[]) {
      final fd = findFood(e.id, customFoods);
      if (fd == null) continue;
      final k = (fd.kcal * e.servings).round();
      i.kcal += k;
      i.dK += k;
      i.p += fd.p * e.servings;
      i.c += fd.c * e.servings;
      i.f += fd.f * e.servings;
      i.cost += fd.price * e.servings;
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
  int exT = 0, exD = 0, mT = 0, mD = 0, water = 0, wg = 8, kcal = 0, steps = 0, total = 0, done = 0, dK = 0;
  double cost = 0, score = 0, p = 0, c = 0, f = 0;
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

class FoodEntry {
  final String id, slot;
  final double servings;
  FoodEntry(this.id, this.servings, this.slot);
  Map<String, dynamic> toJson() => {'id': id, 's': servings, 'slot': slot};
  static FoodEntry fromJson(Map<String, dynamic> j) => FoodEntry(j['id'] as String, ((j['s'] ?? 1) as num).toDouble(), (j['slot'] ?? 'Snack') as String);
}

class SetLog {
  int reps;
  double kg;
  bool done;
  SetLog(this.reps, this.kg, this.done);
  Map<String, dynamic> toJson() => {'r': reps, 'kg': kg, 'd': done};
  static SetLog fromJson(Map<String, dynamic> j) => SetLog(((j['r'] ?? 0) as num).toInt(), ((j['kg'] ?? 0) as num).toDouble(), j['d'] == true);
}
