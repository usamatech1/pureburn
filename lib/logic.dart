import 'dart:math' as math;

const double kgPerLb = 0.45359237;
const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

String two(int n) => n < 10 ? '0$n' : '$n';
String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime parseIso(String s) {
  final a = s.split('-');
  return DateTime(int.parse(a[0]), int.parse(a[1]), int.parse(a[2]));
}

String dayName(DateTime d) => dayNames[d.weekday % 7];
String tidy(double n) => n.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
String rs(double n, int step) {
  final v = (n / step).round() * step;
  final s = v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return 'Rs $s';
}

String fracTxt(double x) {
  if (x == 0.5) return '1/2';
  if (x == 0.75) return '3/4';
  if (x == 1) return '1';
  if (x == 1.5) return '1 1/2';
  if (x == 2) return '2';
  return x.toString();
}

String rotiTxt(int n) => '$n ${n == 1 ? 'roti' : 'rotis'} (atta, no ghee)';

class Profile {
  String unit = 'metric'; // metric | imperial
  String sex = 'm';
  int age = 30;
  String act = 'light';
  double heightCm = 170;
  double weightKg = 78;
  String std = 'asia';
  String? goal;
  double? targetKg;
  String pace = 'steady';
  int days = 4;
  String place = 'home';
  String budget = 'std';

  Map<String, dynamic> toJson() => {
        'unit': unit, 'sex': sex, 'age': age, 'act': act, 'heightCm': heightCm, 'weightKg': weightKg,
        'std': std, 'goal': goal, 'targetKg': targetKg, 'pace': pace, 'days': days, 'place': place, 'budget': budget,
      };

  void fromJson(Map<String, dynamic> j) {
    unit = j['unit'] ?? unit;
    sex = j['sex'] ?? sex;
    age = (j['age'] ?? age).toInt();
    act = j['act'] ?? act;
    heightCm = (j['heightCm'] ?? heightCm).toDouble();
    weightKg = (j['weightKg'] ?? weightKg).toDouble();
    std = j['std'] ?? std;
    goal = j['goal'];
    targetKg = j['targetKg'] == null ? null : (j['targetKg'] as num).toDouble();
    pace = j['pace'] ?? pace;
    days = (j['days'] ?? days).toInt();
    place = j['place'] ?? place;
    budget = j['budget'] ?? budget;
  }
}

class DayLog {
  Set<String> ex = {};
  Set<String> meal = {};
  int water = 0;
  int steps = 0;
  Map<String, dynamic> toJson() => {'ex': ex.toList(), 'meal': meal.toList(), 'water': water, 'steps': steps};
  static DayLog fromJson(Map<String, dynamic> j) {
    final d = DayLog();
    d.ex = Set<String>.from((j['ex'] ?? []) as List);
    d.meal = Set<String>.from((j['meal'] ?? []) as List);
    d.water = (j['water'] ?? 0).toInt();
    d.steps = (j['steps'] ?? 0).toInt();
    return d;
  }
}

class WeightEntry {
  final String d;
  final double kg;
  WeightEntry(this.d, this.kg);
}

class Session {
  final String name;
  final int min;
  final double met;
  final List<String> items;
  Session(this.name, this.min, this.met, this.items);
}

class SchedRow {
  final String day, key, name;
  final int min;
  final double kcal;
  final List<String> items;
  SchedRow(this.day, this.key, this.name, this.min, this.kcal, this.items);
}

class Goal {
  final String goal;
  final double targetKg, pace;
  final int days;
  final String place;
  final bool lowImpact;
  Goal(this.goal, this.targetKg, this.pace, this.days, this.place, this.lowImpact);
}

class TaskItem {
  final String id, text;
  TaskItem(this.id, this.text);
}

class SessionTasks {
  final List<TaskItem> tasks;
  final List<String> notes;
  SessionTasks(this.tasks, this.notes);
}

double burn(double met, int min, double kg) => (met - 1) * 3.5 * kg / 200 * min;

Session sessionInfo(String key, Goal g) {
  final home = g.place == 'home';
  final gain = g.goal == 'gain';
  final sets = gain ? '3 to 4 sets' : '3 sets';
  final sMin = gain ? 50 : 40;
  switch (key) {
    case 'A':
      return Session('Strength A: lower body and push', sMin, 4, home
          ? [
              'Squats: $sets of 10 to 12 (hold a backpack with books to make it harder)',
              'Glute bridges: $sets of 12 to 15',
              'Push-ups on your knees, or with hands on a table or wall: $sets of 8 to 10',
              'Plank: 3 holds of 20 to 30 seconds',
            ]
          : [
              'Leg press: $sets of 10 to 12',
              'Chest press machine or dumbbell bench press: $sets of 10',
              'Dumbbell shoulder press: $sets of 10',
              'Plank: 3 holds of 30 seconds',
            ]);
    case 'B':
      return Session('Strength B: pull, legs and core', sMin, 4, home
          ? [
              '${g.lowImpact ? 'Step-ups on a sturdy stair' : 'Split squats or lunges'}: $sets of 8 per leg',
              'Backpack rows, bent over: $sets of 10 to 12',
              'Superman holds: 3 sets of 10',
              'Dead bug: 3 sets of 8 per side',
            ]
          : [
              'Goblet squat: $sets of 10',
              'Lat pulldown: $sets of 10',
              'Seated cable row: $sets of 10',
              'Romanian deadlift with light dumbbells: $sets of 10',
            ]);
    case 'C':
      return Session('Cardio', 35, g.lowImpact ? 4.3 : 6, g.lowImpact
          ? [
              'Brisk walk, fast enough that you can talk but not sing, outdoors or on a treadmill',
              'Or easy to moderate cycling or swimming',
              'Start at 30 minutes and add 5 minutes each week, up to 45',
            ]
          : [
              'Brisk walk with a 1 minute jog every 3 minutes',
              'Or cycling, skipping rope or the cross trainer in rounds',
              'Start at 30 minutes and add 5 minutes each week, up to 45',
            ]);
    case 'L':
      return Session('Long walk', 60, 4.3, [
        'Easy 60 minute walk at a steady pace',
        'Evenings are cooler. A park or jogging track is gentler on your knees than a road.',
      ]);
    default:
      return Session('Easy walk', 25, 3.5, [
        'Easy 25 minute walk, for example after dinner',
        'This helps recovery and digestion. Keep it relaxed.',
      ]);
  }
}

List<SchedRow> buildSchedule(Goal g, double kg) {
  final n = g.days;
  final days = {
    3: ['Monday', 'Wednesday', 'Friday'],
    4: ['Monday', 'Tuesday', 'Thursday', 'Saturday'],
    5: ['Monday', 'Tuesday', 'Thursday', 'Friday', 'Saturday'],
  }[n]!;
  List<String> seq;
  if (g.goal == 'gain') {
    seq = n == 5 ? ['A', 'B', 'A', 'B', 'W'] : n == 4 ? ['A', 'B', 'A', 'B'] : ['A', 'B', 'A'];
  } else {
    seq = n == 5 ? ['A', 'C', 'B', 'C', 'L'] : n == 4 ? ['A', 'C', 'B', 'C'] : ['A', 'C', 'B'];
  }
  final rows = <SchedRow>[];
  for (var i = 0; i < seq.length; i++) {
    final s = sessionInfo(seq[i], g);
    rows.add(SchedRow(days[i], seq[i], s.name, s.min, burn(s.met, s.min, kg), s.items));
  }
  return rows;
}

SessionTasks sessionTasks(SchedRow row) {
  final cardio = row.key == 'C' || row.key == 'L' || row.key == 'W';
  final tasks = <TaskItem>[TaskItem('wu', 'Warm up for 5 minutes')];
  var notes = <String>[];
  if (cardio) {
    tasks.add(TaskItem('main', '${row.name}: ${row.min} minutes'));
    notes = row.items;
  } else {
    for (var i = 0; i < row.items.length; i++) {
      tasks.add(TaskItem('${row.key}$i', row.items[i]));
    }
  }
  tasks.add(TaskItem('cd', 'Cool down and stretch for 5 minutes'));
  return SessionTasks(tasks, notes);
}

class Plan {
  late String goal, timeTxt, headS, paceS, care;
  late String headV;
  late int kcal, pG, cG, fG, floorKcal;
  late double perWeek, E, weekly, tdee;
  late List<SchedRow> sched;
}

class Meal {
  final String id, time, name;
  double cost;
  int kcal = 0;
  List<String> items;
  List<(String, double)>? parts; // foods and portions, when the meal was swapped or filtered
  String? tmpl; // template id when swapped
  double mp = 0, mc = 0, mf = 0; // estimated protein, carbs and fat in grams
  Meal(this.id, this.time, this.name, this.cost, this.items);
}

class Diet {
  late List<Meal> meals;
  late double daily;
  late List<String> goalTips, moneyTips;
  late String floorNote;
}

class Derived {
  bool ok = false;
  double h = 0, w = 0;
  int age = 0;
  String sex = 'm';
  double bmi = 0, hiStart = 23, obStart = 27.5, loBmi = 18.5, hiBmi = 22.9;
  String cat = '', cls = '', text = '';
  double minKg = 0, maxKg = 0, avg = 0, target = 0;
  List<MapEntry<String, double>> formulas = [];
  String changeV = '', changeS = '';
  String goal = 'maintain';
  double tKg = 0;
  String gNote = '';
  bool gOk = true;
  Goal? g;
  String? blocked;
  Plan? plan;
  Diet? diet;
  int waterGoal = 8, stepGoal = 8000;
}

const _price = {
  'roti': 8.0, 'egg': 44.0, 'tea': 15.0, 'greenTea': 12.0, 'salad': 20.0, 'vegCup': 20.0, 'yogCup': 58.0,
  'chicken100': 55.0, 'fish100': 80.0, 'cook': 15.0,
};
const _curryCup = {'low': 27.0, 'std': 30.0, 'high': 40.0};
const _fruit = {'low': 20.0, 'std': 45.0, 'high': 70.0};
const _snackG = {'low': 0.4, 'std': 0.6, 'high': 3.0};
const _post = {'low': 70.0, 'std': 70.0, 'high': 110.0};

Plan computePlan(Profile p, Goal g, double h, double w, int age) {
  final bmr = 10 * w + 6.25 * h - 5 * age + (p.sex == 'm' ? 5 : -161);
  final mult = {'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725}[p.act] ?? 1.2;
  final tdee = bmr * mult;
  final sched = buildSchedule(g, w);
  final weekly = sched.fold<double>(0, (a, r) => a + r.kcal);
  final e = weekly / 7;
  final floorKcal = p.sex == 'm' ? 1500 : 1200;
  int kcal;
  double perWeek;
  if (g.goal == 'lose') {
    kcal = math.max(floorKcal, (((tdee + e - g.pace * 1100) / 50).round() * 50));
    perWeek = math.max(0.1, (tdee + e - kcal) * 7 / 7700);
  } else if (g.goal == 'gain') {
    kcal = ((tdee + e + g.pace * 1100) / 50).round() * 50;
    perWeek = math.max(0.1, (kcal - tdee - e) * 7 / 7700);
  } else {
    kcal = ((tdee + e) / 50).round() * 50;
    perWeek = 0;
  }
  final diffKg = (g.targetKg - w).abs();
  final weeks = perWeek > 0 ? math.max(1, (diffKg / perWeek).ceil()) : 0;
  final plan = Plan();
  plan.goal = g.goal;
  plan.timeTxt = g.goal == 'maintain' ? 'Ongoing' : 'About ${weeks <= 12 ? '$weeks weeks' : '${(weeks / 4.345).round()} months'}';
  final pf = {'lose': 1.4, 'maintain': 1.2, 'gain': 1.7}[g.goal]!;
  plan.pG = (pf * (g.goal == 'gain' ? w : g.targetKg)).round();
  plan.fG = (kcal * 0.27 / 9).round();
  plan.cG = math.max(50, ((kcal - plan.pG * 4 - plan.fG * 9) / 4).round());
  plan.kcal = kcal;
  plan.perWeek = perWeek;
  plan.E = e;
  plan.weekly = weekly;
  plan.tdee = tdee;
  plan.sched = sched;
  plan.floorKcal = floorKcal;
  plan.care = age >= 65
      ? 'Because you are 65 or older, please check this plan with your doctor before starting.'
      : 'If you have diabetes, a heart, blood pressure or kidney condition, or you are pregnant or breastfeeding, check this plan with your doctor first.';
  return plan;
}

Diet buildDiet(Profile p, Goal g, Plan plan) {
  final b = p.budget;
  final goal = g.goal;
  final kcal = plan.kcal;
  final t = kcal < 1450 ? 0 : kcal < 1750 ? 1 : kcal < 2050 ? 2 : kcal < 2400 ? 3 : 4;
  T pick<T>(List<T> a) => a[t];
  final eggs = pick([1, 2, 2, 3, 3]);
  final rotiB = pick([1, 1, 2, 2, 3]);
  final fruitN = pick([1, 1, 1, 2, 2]);
  final rotiL = pick([1, 2, 2, 3, 4]);
  final curryL = pick([0.75, 1.0, 1.0, 1.5, 1.5]);
  final yogN = pick([0.5, 0.5, 1.0, 1.0, 1.0]);
  final nuts = pick([15, 20, 30, 30, 45]);
  final prot = pick([100, 120, 150, 180, 200]);
  final rotiD = pick([0, 1, 1, 2, 3]);
  final dinCup = pick([1.0, 1.5, 1.5, 2.0, 2.0]);
  final fruitTxt = {'low': 'banana or guava (amrood)', 'std': 'apple, pear or kinnow', 'high': 'apple, pomegranate (anaar) or papaya'}[b]!;
  final lunchCurry = {'low': 'masoor or chana daal', 'std': 'daal (masoor, moong or chana)', 'high': 'moong daal, mash daal or rajma'}[b]!;
  final snackTxt = {'low': 'Bhuna chana (roasted chana)', 'std': 'Bhuna chana or peanuts (mungfali)', 'high': 'Almonds, walnuts or mixed nuts'}[b]!;
  String dinnerProt;
  double dinnerCost;
  if (b == 'low') {
    dinnerProt = '${fracTxt(dinCup)} cups of lobia, chana or daal curry made with little oil';
    dinnerCost = dinCup * _curryCup['low']!;
  } else if (b == 'std') {
    dinnerProt = '$prot g chicken (tikka, boti or light salan, no cream)';
    dinnerCost = prot / 100 * _price['chicken100']! + _price['cook']!;
  } else {
    dinnerProt = '$prot g grilled or baked fish (rohu or similar), or chicken';
    dinnerCost = prot / 100 * _price['fish100']! + _price['cook']!;
  }
  final costB = eggs * _price['egg']! + rotiB * _price['roti']! + _price['tea']!;
  final costM = fruitN * _fruit[b]!;
  final costL = rotiL * _price['roti']! + curryL * _curryCup[b]! + _price['salad']! + yogN * _price['yogCup']!;
  final costS = nuts * _snackG[b]! + _price['greenTea']!;
  final costD = rotiD * _price['roti']! + 1.5 * _price['vegCup']! + dinnerCost;

  final meals = <Meal>[
    Meal('bf', 'Around 8:00 am', 'Breakfast', costB, [
      '$eggs ${eggs == 1 ? 'boiled egg' : 'boiled eggs'} or a vegetable omelette made with very little oil',
      rotiTxt(rotiB),
      'Chai with milk and no sugar, or green tea',
    ]),
    Meal('mm', 'Around 11:00 am', 'Mid-morning snack', costM, ['$fruitN $fruitTxt']),
    Meal('ln', 'Around 1:30 pm', 'Lunch', costL, [
      rotiTxt(rotiL),
      '${fracTxt(curryL)} cup of $lunchCurry, cooked with little oil',
      'Large salad of kheera (cucumber), tamatar and pyaz',
      '${fracTxt(yogN)} cup of plain dahi (yogurt) or raita',
    ]),
    Meal('sn', 'Around 5:00 pm', 'Evening snack', costS, ['$snackTxt, about $nuts g', 'Green tea or nimbu pani without sugar']),
  ];
  if (goal == 'gain') {
    meals.add(Meal('pw', 'Within 1 hour of training', 'After workout', _post[b]!, [
      b == 'high' ? '1 glass (250 ml) of doodh with a banana and 10 almonds' : '1 glass (250 ml) of doodh with a banana',
    ]));
  }
  meals.add(Meal('dn', 'Around 8:00 pm', 'Dinner', costD, [
    dinnerProt,
    '1 1/2 cups of seasonal sabzi such as bhindi, tori, lauki, palak or gobi',
    rotiD > 0 ? rotiTxt(rotiD) : 'No roti or rice at dinner',
  ]));
  final fr = goal == 'gain' ? [0.23, 0.07, 0.28, 0.08, 0.08, 0.26] : [0.25, 0.08, 0.30, 0.09, 0.28];
  for (var i = 0; i < meals.length; i++) {
    meals[i].kcal = (kcal * fr[i] / 10).round() * 10;
  }
  final goalTips = {
    'lose': [
      'Have protein (egg, daal, chicken, dahi) at every meal to protect your muscle.',
      'Cook with 1 to 2 teaspoons of oil per person and skip extra ghee on roti.',
      'Eat roti, daal and sabzi on most days instead of paratha, puri, samosa, pakora, biryani or halwa puri.',
      'Choose namkeen lassi or plain water over sweet lassi, sharbat and cold drinks.',
    ],
    'maintain': [
      'Keep your portions steady and weigh yourself once a month.',
      'Cook with 1 to 2 teaspoons of oil per person and keep fried food for special days.',
      'Choose namkeen lassi or plain water over sweet lassi, sharbat and cold drinks.',
    ],
    'gain': [
      'Do not skip meals. Eat every 3 to 4 hours, and add an extra snack if you cannot finish a meal.',
      'Add a glass of doodh daily, and use a little desi ghee or nuts to raise calories without huge portions.',
      'Have protein (egg, daal, chicken, fish, dahi) at every meal. Muscle needs it to grow.',
      'Sleep 7 to 8 hours. Muscle is built while you rest.',
    ],
  }[goal]!;
  final diet = Diet();
  diet.meals = meals;
  diet.daily = meals.fold<double>(0, (a, m) => a + m.cost);
  diet.goalTips = [
    ...goalTips,
    'Eat your evening snack or dinner within 2 hours after a workout.',
    'Drink 2 to 3 litres of water a day, and a glass before each workout.',
    'Weigh yourself once a week at the same time of day.',
  ];
  diet.moneyTips = [
    'Buy seasonal sabzi and fruit from the sabzi mandi or weekly bazaar. Out-of-season produce costs far more.',
    'Eggs, daal and chana are the cheapest protein. Use them on more days if money is tight.',
    'Buy atta, daal and rice in bulk and cook at home. Eating out and packaged snacks cost more and add calories.',
    'Buy a whole chicken and cut it at home. It usually costs less per kg than boneless pieces.',
  ];
  diet.floorNote = (goal == 'lose' && kcal == plan.floorKcal && plan.perWeek < g.pace - 0.05)
      ? 'Your calories are held at the lowest safe level, so your real pace is slower than the one you chose. '
      : '';
  return diet;
}

String _fmtKg(Profile p, double kg) =>
    p.unit == 'metric' ? '${kg.abs().toStringAsFixed(1)} kg' : '${(kg.abs() / kgPerLb).toStringAsFixed(1)} lb';

Derived derive(Profile p) {
  final d = Derived();
  d.h = p.heightCm;
  d.w = p.weightKg;
  d.age = p.age;
  d.sex = p.sex;
  final ok = d.h >= 100 && d.h <= 250 && d.w >= 20 && d.w <= 300 && d.age >= 10 && d.age <= 100;
  if (!ok) return d;
  d.ok = true;
  final m2 = math.pow(d.h / 100, 2).toDouble();
  final bmi = d.w / m2;
  d.bmi = bmi;
  final asia = p.std == 'asia';
  d.hiStart = asia ? 23 : 25;
  d.obStart = asia ? 27.5 : 30;
  d.hiBmi = d.hiStart - 0.1;
  if (bmi < d.loBmi) {
    d.cat = 'Underweight';
    d.cls = 'under';
    d.text = 'Your weight is below the healthy range. Add protein and healthy fats to your meals, and talk to a doctor if you are unsure why.';
  } else if (bmi < d.hiStart) {
    d.cat = 'Healthy weight';
    d.cls = 'ok';
    d.text = 'Your weight is within the healthy range. Keep up your current eating and activity habits.';
  } else if (bmi < d.obStart) {
    d.cat = 'Overweight';
    d.cls = 'warn';
    d.text = 'Your weight is a little above the healthy range. Cut back on sugary and fried food and aim for a 30 minute walk each day.';
  } else {
    d.cat = 'Obese';
    d.cls = 'bad';
    d.text = 'Your BMI is in the obese range. A doctor or dietitian can help you build a safe plan to lose weight.';
  }
  d.minKg = d.loBmi * m2;
  d.maxKg = d.hiBmi * m2;
  final inOver = d.h / 2.54 - 60;
  final male = p.sex == 'm';
  d.formulas = [
    MapEntry('Devine (1974)', male ? 50 + 2.3 * inOver : 45.5 + 2.3 * inOver),
    MapEntry('Robinson (1983)', male ? 52 + 1.9 * inOver : 49 + 1.7 * inOver),
    MapEntry('Miller (1983)', male ? 56.2 + 1.41 * inOver : 53.1 + 1.36 * inOver),
    MapEntry('Hamwi (1964)', male ? 48 + 2.7 * inOver : 45.4 + 2.27 * inOver),
  ];
  d.avg = d.formulas.fold<double>(0, (a, f) => a + f.value) / 4;
  d.target = math.min(d.maxKg, math.max(d.minKg, d.avg));
  final delta = d.target - d.w;
  if (delta.abs() < 0.5) {
    d.changeV = 'On target';
    d.changeS = 'You are close to your best weight.';
  } else if (delta < 0) {
    d.changeV = 'Lose ${_fmtKg(p, delta)}';
    d.changeS = 'Losing 0.25 to 0.5 kg a week is a safe pace.';
  } else {
    d.changeV = 'Gain ${_fmtKg(p, delta)}';
    d.changeS = 'Gaining 0.25 to 0.5 kg a week is a safe pace.';
  }
  final autoGoal = d.cls == 'under' ? 'gain' : d.cls == 'ok' ? 'maintain' : 'lose';
  final goal = p.goal ?? autoGoal;
  d.goal = goal;
  var tKg = goal == 'maintain' ? d.w : (p.targetKg ?? d.target);
  var note = '';
  var gOk = true;
  if (tKg < 20 || tKg > 300) {
    note = 'Enter a valid target weight.';
    gOk = false;
  } else if (goal == 'lose') {
    if (bmi < d.loBmi) {
      note = 'Your BMI is already below the healthy range, so losing weight is not advised. Choose Maintain or Gain.';
      gOk = false;
    } else if (tKg > d.w - 0.4) {
      note = 'To lose weight, your target must be below your current weight.';
      gOk = false;
    } else if (tKg < d.minKg) {
      tKg = d.minKg;
      note = 'Your target was raised to ${_fmtKg(p, d.minKg)}, the lowest healthy weight for your height.';
    }
  } else if (goal == 'gain') {
    if (bmi >= d.hiStart) {
      note = 'Your weight is already above the healthy range, so gaining weight is not advised. Choose Lose or Maintain.';
      gOk = false;
    } else if (tKg < d.w + 0.4) {
      note = 'To gain weight, your target must be above your current weight.';
      gOk = false;
    } else if (tKg > d.maxKg) {
      tKg = d.maxKg;
      note = 'Your target was lowered to ${_fmtKg(p, d.maxKg)}, the top of the healthy range for your height.';
    }
  }
  d.tKg = tKg;
  d.gNote = note;
  d.gOk = gOk;
  final paceMap = goal == 'gain'
      ? {'gentle': 0.25, 'steady': 0.4, 'fast': 0.5}
      : {'gentle': 0.25, 'steady': 0.5, 'fast': 0.75};
  final pace = paceMap[p.pace] ?? 0.5;
  d.g = Goal(goal, tKg, pace, p.days, p.place, d.cls == 'bad' || d.age >= 50);
  if (d.age < 18) {
    d.blocked = 'Plans here are for adults aged 18 and over. For teens and children, please ask a doctor.';
  } else if (!gOk) {
    d.blocked = note;
  }
  if (d.blocked == null) {
    d.plan = computePlan(p, d.g!, d.h, d.w, d.age);
    final pl = d.plan!;
    pl.headV = goal == 'lose'
        ? 'Lose ${_fmtKg(p, d.w - tKg)}'
        : goal == 'gain'
            ? 'Gain ${_fmtKg(p, tKg - d.w)}'
            : 'Stay at ${_fmtKg(p, d.w)}';
    pl.headS = goal == 'maintain' ? 'Keep your weight steady' : 'From ${_fmtKg(p, d.w)} to ${_fmtKg(p, tKg)}';
    pl.paceS = goal == 'maintain' ? 'Check your weight once a month' : 'Around ${_fmtKg(p, pl.perWeek)} per week';
    d.diet = buildDiet(p, d.g!, pl);
  }
  d.waterGoal = math.min(12, math.max(8, (d.w * 35 / 250).round()));
  d.stepGoal = {'lose': 9000, 'maintain': 8000, 'gain': 7000}[goal]!;
  return d;
}
