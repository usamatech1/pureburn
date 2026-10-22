// Applies diet filters, meal swaps and Ramadan mode to the plan, and builds the shopping list.
import 'foods.dart';
import 'logic.dart';

final Map<String, Food> _byId = {for (final f in foodDb) f.id: f};
final Map<String, Tmpl> _tById = {for (final t in templates) t.id: t};

Food? findFood(String id, List<Food> custom) {
  final f = _byId[id];
  if (f != null) return f;
  for (final c in custom) {
    if (c.id == id) return c;
  }
  return null;
}

Tmpl? templateById(String id) => _tById[id];

String fmtS(double s) {
  if (s == s.roundToDouble()) return s.round().toString();
  if ((s * 2) == (s * 2).roundToDouble()) return s.floor() == 0 ? '1/2' : '${s.floor()} 1/2';
  return tidy(s);
}

// ---- fitting a template to a calorie target
List<(String, double)> fitTemplate(Tmpl t, int target) {
  double k(String id) => _byId[id]!.kcal.toDouble();
  var fixedK = 0.0, flexK = 0.0;
  for (final p in t.parts) {
    final x = k(p.food) * p.servings;
    if (p.fixed) {
      fixedK += x;
    } else {
      flexK += x;
    }
  }
  final scale = flexK > 0 ? ((target - fixedK) / flexK).clamp(0.5, 3.0) : 1.0;
  final sv = <double>[];
  for (final p in t.parts) {
    if (p.fixed) {
      sv.add(p.servings);
    } else {
      final st = _byId[p.food]!.step;
      var v = (p.servings * scale / st).round() * st;
      if (v < st) v = st;
      sv.add(v);
    }
  }
  double total() {
    var s = 0.0;
    for (var i = 0; i < sv.length; i++) {
      s += k(t.parts[i].food) * sv[i];
    }
    return s;
  }

  for (var n = 0; n < 8; n++) {
    final diff = target - total();
    var best = -1;
    var bestDir = 0;
    var bestAbs = diff.abs();
    for (var j = 0; j < sv.length; j++) {
      if (t.parts[j].fixed) continue;
      final f = _byId[t.parts[j].food]!;
      for (final dir in [1, -1]) {
        final nv = sv[j] + dir * f.step;
        if (nv < f.step) continue;
        final d2 = (diff - dir * f.step * f.kcal).abs();
        if (d2 < bestAbs - 1) {
          bestAbs = d2;
          best = j;
          bestDir = dir;
        }
      }
    }
    if (best < 0) break;
    sv[best] += bestDir * _byId[t.parts[best].food]!.step;
  }
  return [for (var i = 0; i < sv.length; i++) (t.parts[i].food, sv[i])];
}

List<String> partsText(List<(String, double)> parts, List<Food> custom) => [
      for (final p in parts)
        if (findFood(p.$1, custom) != null) '${fmtS(p.$2)} × ${findFood(p.$1, custom)!.name} (${findFood(p.$1, custom)!.serving})',
    ];

double partsCost(List<(String, double)> parts, List<Food> custom) {
  var s = 0.0;
  for (final p in parts) {
    s += (findFood(p.$1, custom)?.price ?? 0) * p.$2;
  }
  return s;
}

bool tmplBlocked(Tmpl t, Set<String> blocked) {
  if (blocked.isEmpty) return false;
  for (final p in t.parts) {
    final f = _byId[p.food];
    if (f != null && f.tags.any(blocked.contains)) return true;
  }
  return false;
}

/// Templates for this slot that fit the diet, each fitted to the calories of the meal.
List<(Tmpl, List<(String, double)>)> alternatives(String mealId, int kcal, Set<String> blocked, {String? exclude}) {
  final g = groupOf(mealId);
  return [
    for (final t in templates)
      if (t.group == g && t.id != exclude && !tmplBlocked(t, blocked)) (t, fitTemplate(t, kcal)),
  ];
}

void _apply(Meal m, Tmpl t, List<Food> custom) {
  final parts = fitTemplate(t, m.kcal);
  m.parts = parts;
  m.tmpl = t.id;
  m.items = partsText(parts, custom);
  m.cost = partsCost(parts, custom);
  var p = 0.0, c = 0.0, f = 0.0;
  for (final x in parts) {
    final fd = findFood(x.$1, custom);
    if (fd == null) continue;
    p += fd.p * x.$2;
    c += fd.c * x.$2;
    f += fd.f * x.$2;
  }
  m.mp = p;
  m.mc = c;
  m.mf = f;
}

Tmpl? _best(String mealId, int kcal, Set<String> blocked, String budget) {
  final alts = alternatives(mealId, kcal, blocked);
  if (alts.isEmpty) return null;
  (Tmpl, List<(String, double)>)? best;
  var bestScore = 1e9;
  for (final a in alts) {
    var tot = 0.0;
    for (final x in a.$2) {
      tot += _byId[x.$1]!.kcal * x.$2;
    }
    var score = (tot - kcal).abs();
    if (budget == 'low') score += partsCost(a.$2, const []) * 0.5;
    if (score < bestScore) {
      bestScore = score;
      best = a;
    }
  }
  return best?.$1;
}

String _label(int h, int m) => 'Around ${h % 12 == 0 ? 12 : h % 12}:${two(m)} ${h < 12 ? 'am' : 'pm'}';

List<int> _hm(String s, int dh, int dm) {
  final a = s.split(':');
  if (a.length != 2) return [dh, dm];
  return [int.tryParse(a[0]) ?? dh, int.tryParse(a[1]) ?? dm];
}

const ramadanTips = [
  'Break your fast with khajoor and water, pray, then eat the main meal.',
  'Drink 8 glasses of water between iftar and sehri: 2 at iftar, 4 after taraweeh and 2 at sehri.',
  'Keep pakora, samosa and sweet sharbat for one day a week, not every day.',
  'Do not skip sehri. Daal, roti and dahi keep you full for longer.',
  'Train lightly 1 to 2 hours after iftar, or take an easy walk, and cut your sets by one.',
];

/// Applies the diet type, allergies, swaps and Ramadan mode to a freshly built plan.
void applyPrefs(Derived d, Map<String, dynamic> set, Map<String, String> swaps, List<Food> custom, String budget) {
  final diet = d.diet, plan = d.plan;
  if (diet == null || plan == null) return;
  final allergies = [for (final a in (set['allergies'] ?? const []) as List) '$a'];
  final blocked = blockedTags('${set['dietType'] ?? 'any'}', allergies);
  var meals = diet.meals;
  final ramadan = set['ramadan'] == true;
  if (ramadan) {
    final s = _hm('${set['sehri'] ?? '04:30'}', 4, 30);
    final i = _hm('${set['iftar'] ?? '18:30'}', 18, 30);
    final dn = (i[0] + 3) % 24;
    int share(double f) => (plan.kcal * f / 10).round() * 10;
    meals = [
      Meal('seh', _label(s[0], s[1]), 'Sehri', 0, [])..kcal = share(0.32),
      Meal('ifr', _label(i[0], i[1]), 'Iftar', 0, [])..kcal = share(0.30),
      Meal('rdn', _label(dn, i[1]), 'Dinner after taraweeh', 0, [])..kcal = share(0.38),
    ];
    diet.goalTips = [...ramadanTips, ...diet.goalTips];
  }
  for (final m in meals) {
    final share = plan.kcal > 0 ? m.kcal / plan.kcal : 0;
    m.mp = plan.pG * share;
    m.mc = plan.cG * share;
    m.mf = plan.fG * share;
    Tmpl? t;
    final sw = swaps[m.id];
    if (sw != null) {
      final c = templateById(sw);
      if (c != null && c.group == groupOf(m.id) && !tmplBlocked(c, blocked)) t = c;
    }
    if (t == null && (ramadan || textBlocked(m.items.join(' '), blocked))) {
      t = _best(m.id, m.kcal, blocked, budget);
    }
    if (t != null) _apply(m, t, custom);
  }
  diet.meals = meals;
  diet.daily = meals.fold<double>(0, (a, m) => a + m.cost);
}

// ---- shopping list
final _fracRe = RegExp(r'^(\d+ \d/\d|\d/\d|\d+)');

double _frac(String s) {
  final m = _fracRe.firstMatch(s);
  if (m == null) return 1;
  final x = m[1]!;
  if (x.contains(' ')) {
    final a = x.split(' ');
    final b = a[1].split('/');
    return double.parse(a[0]) + double.parse(b[0]) / double.parse(b[1]);
  }
  if (x.contains('/')) {
    final b = x.split('/');
    return double.parse(b[0]) / double.parse(b[1]);
  }
  return double.parse(x);
}

void _parseText(String raw, Map<String, double> t) {
  final l = raw.toLowerCase();
  void add(String k, double v) => t[k] = (t[k] ?? 0) + v;
  RegExpMatch? m;
  if ((m = RegExp(r'^(\d+) rotis?').firstMatch(l)) != null) {
    add('atta', 40.0 * int.parse(m![1]!));
  } else if ((m = RegExp(r'^(\d+) (?:boiled )?eggs?').firstMatch(l)) != null) {
    add('eggs', double.parse(m![1]!));
  } else if ((m = RegExp(r'(\d+) g chicken').firstMatch(l)) != null) {
    add('chicken', double.parse(m![1]!));
  } else if ((m = RegExp(r'(\d+) g grilled or baked fish').firstMatch(l)) != null) {
    add('fish', double.parse(m![1]!));
  } else if (l.contains('plain dahi')) {
    add('dahi', 200 * _frac(l));
  } else if (RegExp(r'^[\d /]+ cups? of (lobia|.*daal|.*rajma)').hasMatch(l)) {
    add('daal', 65 * _frac(l));
  } else if (l.contains('seasonal sabzi')) {
    add('veg', 225);
  } else if (l.contains('salad')) {
    add('veg', 200);
  } else if (l.contains('doodh')) {
    add('milk', 250);
    if (l.contains('banana')) add('fruit', 1);
    if (l.contains('almond')) add('nuts', 15);
  } else if (l.startsWith('chai with milk')) {
    add('milk', 60);
  } else if ((m = RegExp(r'^(\d+) (apple|banana|guava)').firstMatch(l)) != null) {
    add('fruit', double.parse(m![1]!));
  } else if ((m = RegExp(r'about (\d+) g').firstMatch(l)) != null) {
    add(l.contains('almond') ? 'nuts' : 'chana', double.parse(m![1]!));
  }
}

/// Totals of each ingredient for a number of days of the current meals.
Map<String, double> shoppingTotals(Diet diet, int days, List<Food> custom) {
  final t = <String, double>{};
  for (final m in diet.meals) {
    if (m.parts != null) {
      for (final p in m.parts!) {
        final f = findFood(p.$1, custom);
        if (f?.ing != null) t[f!.ing!] = (t[f.ing!] ?? 0) + f.ingQty * p.$2;
      }
    } else {
      for (final it in m.items) {
        _parseText(it, t);
      }
    }
  }
  return {for (final e in t.entries) e.key: e.value * days};
}

String fmtQty(String key, double q) {
  final ing = ingredients[key]!;
  if (ing.unit == 'g') return q >= 1000 ? '${(q / 1000).toStringAsFixed(1)} kg' : '${(q / 10).round() * 10} g';
  if (ing.unit == 'ml') return q >= 1000 ? '${(q / 1000).toStringAsFixed(1)} L' : '${(q / 50).round() * 50} ml';
  return '${q.round()} pieces';
}
