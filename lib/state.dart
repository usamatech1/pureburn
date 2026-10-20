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
      }
      final t = _sp!.getString('pureburn-theme');
      if (t == 'dark') theme = ThemeMode.dark;
      if (t == 'light') theme = ThemeMode.light;
    } catch (_) {}
    d = derive(p);
    notifyListeners();
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
