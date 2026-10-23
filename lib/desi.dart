// Desi Food Intelligence (Module 2): roti and grain customiser, salan oil estimator,
// chai builder, smart swaps and the Clean Burn Score.
import 'package:flutter/material.dart' hide Text;
import 'foods.dart';
import 'i18n.dart';
import 'main.dart' show app;
import 'state.dart';
import 'ui.dart';

// ---------------------------------------------------------------- which foods are customised
const _salanIds = {
  'masoor', 'moong', 'mash', 'chana_daal', 'chana_curry', 'lobia', 'rajma', 'bhindi', 'aloo', 'palak', 'lauki', 'gobi',
  'chicken_salan', 'beef_salan', 'mutton_karahi', 'nihari', 'haleem', 'biryani', 'pulao', 'khichdi',
};
const _chaiIds = {'chai', 'chai_ns', 'green_tea'};

String? desiKind(Food f) {
  if (f.mine) return null;
  if (f.id == 'roti') return 'roti';
  if (_salanIds.contains(f.id)) return 'salan';
  if (_chaiIds.contains(f.id)) return 'chai';
  return null;
}

// ---------------------------------------------------------------- data
class _Flour {
  final String name, note;
  final double kcal, c, p, f;
  final int clean;
  const _Flour(this.name, this.note, this.kcal, this.c, this.p, this.f, this.clean);
}

// Per roti. Wheat, besan and jowar follow the spec. Multigrain is an estimate between them.
const _flours = <String, _Flour>{
  'wheat': _Flour('Whole wheat', 'Standard', 105, 22, 3, 0.8, 2),
  'besan': _Flour('Besan', 'Low carb, high protein', 110, 13, 6, 1.6, 5),
  'jowar': _Flour('Jowar', 'Gluten free', 95, 19, 3, 0.6, 5),
  'multi': _Flour('Multigrain', 'Mixed grains', 100, 20, 4, 1.0, 4),
};
const _chupriKcal = 50.0, _chupriFat = 5.5;

const _tari = [
  ('Ghar ka, low oil', 'About 1 tsp of oil', 45.0, 5.0, 3),
  ('Moderate tari', 'Usual home cooking', 100.0, 11.0, 0),
  ('Dhabba style', 'Oil floating on top', 200.0, 22.0, -6),
];

class _Milk {
  final String name;
  final double kcal, p, c, f;
  final int clean;
  const _Milk(this.name, this.kcal, this.p, this.c, this.f, this.clean);
}

const _milks = <String, _Milk>{
  'full': _Milk('Full cream milk', 80, 4, 6, 4.5, 0),
  'skim': _Milk('Low fat milk', 45, 4, 6, 0.3, 1),
  'black': _Milk('Black or green tea', 2, 0, 0.4, 0, 3),
};
const _sugars = <String, (String, double, int)>{
  'none': ('No sugar', 0.0, 2),
  'one': ('1 tsp sugar', 16.0, -1),
  'two': ('2 tsp sugar', 32.0, -3),
  'stevia': ('Stevia', 0.0, 2),
};

// ---------------------------------------------------------------- Clean Burn Score
/// Effect of a plain (not customised) food on the score.
const _plainClean = {
  'paratha': -4, 'naan': -2, 'rice': -2, 'cold_drink': -5, 'rooh_afza': -4, 'lassi_sweet': -3,
  'green_tea': 2, 'salad': 2, 'dahi': 1, 'egg_boiled': 1, 'chicken_grill': 2, 'chicken_tikka': 2, 'fish_grill': 2,
  'masoor': 1, 'moong': 1, 'chana_daal': 1,
};

int entryClean(FoodEntry e) => e.custom ? e.clean : (_plainClean[e.id] ?? 0);

/// Starts at 70 and moves with what you log. Null when nothing is logged.
int? cleanBurnScore(String date) {
  final l = app.food[date];
  if (l == null || l.isEmpty) return null;
  var s = 70;
  for (final e in l) {
    s += entryClean(e);
  }
  return s.clamp(0, 100);
}

class CleanScoreCard extends StatelessWidget {
  const CleanScoreCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = cleanBurnScore(app.selDate);
    final msg = s == null
        ? 'Add food to your diary to see your score.'
        : s >= 85
            ? 'Excellent. Your choices today are clean.'
            : s >= 70
                ? 'Good. A swap or two would push you above 85.'
                : 'A few swaps will help. Try less oil, besan roti and chai without sugar.';
    return Box(
      child: Row(children: [
        RingGauge(fraction: (s ?? 0) / 100, center: s == null ? '-' : '$s', size: 72),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('Clean Burn Score'),
            const SizedBox(height: 4),
            Muted(msg, size: 12.5),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- smart swaps
class SwapTip {
  final String key, text;
  final String? action; // button label
  final int entryIndex;
  const SwapTip(this.key, this.text, this.entryIndex, {this.action});
}

final Set<String> _dismissed = {};

List<SwapTip> swapTips(String date) {
  final l = app.food[date] ?? const <FoodEntry>[];
  final out = <SwapTip>[];
  for (var i = 0; i < l.length; i++) {
    final e = l[i];
    final key = '$date|$i|${e.id}';
    if (_dismissed.contains(key)) continue;
    if (e.id == 'paratha') {
      final saved = (260 - (110 + 45)) * e.servings;
      out.add(SwapTip(key, 'Switch to besan roti with 1 tsp desi ghee to save about ${(saved / 5).round() * 5} kcal and get a little more protein.', i, action: 'Swap it'));
    } else if (e.id == 'rice') {
      out.add(SwapTip(key, 'Mix in 50% boiled daal or a cucumber salad to slow down the sugar rise after this meal.', i));
    } else if (e.id == 'chai' && (!e.custom || (e.label ?? '').contains(' tsp sugar'))) {
      out.add(SwapTip(key, 'Try cinnamon tea or stevia to keep your Clean Burn Score above 85.', i));
    }
  }
  return out.take(2).toList();
}

void dismissTip(SwapTip t) => _dismissed.add(t.key);

/// Replaces a logged paratha with one besan roti per paratha, brushed with a little ghee.
void applySwap(String date, SwapTip t) {
  final l = app.food[date];
  if (l == null || t.entryIndex >= l.length) return;
  final old = l[t.entryIndex];
  if (old.id != 'paratha') return;
  final q = old.servings;
  final r = _roti('besan', true, q);
  l[t.entryIndex] = FoodEntry('roti', q, old.slot, label: r.label, kcalT: r.kcal, pT: r.p, cT: r.c, fT: r.f, clean: r.clean);
  app.save();
}

// ---------------------------------------------------------------- calculations
class Calc {
  final String label;
  final double kcal, p, c, f;
  final int clean;
  const Calc(this.label, this.kcal, this.p, this.c, this.f, this.clean);
}

String _q(double q) => q == q.roundToDouble() ? '${q.round()}' : '$q';

Calc _roti(String flour, bool chupri, double q) {
  final x = _flours[flour]!;
  final kcal = (x.kcal + (chupri ? _chupriKcal : 0)) * q;
  return Calc('Roti (${x.name}, ${chupri ? 'Chupri' : 'Sukhi'}) · ${_q(q)}×', kcal, x.p * q, x.c * q, (x.f + (chupri ? _chupriFat : 0)) * q, x.clean);
}

Calc _salan(Food f, int level, double q) {
  final t = _tari[level];
  final kcal = (f.kcal + t.$3) * q;
  return Calc('${f.name} (${t.$1}) · ${_q(q)}×', kcal, f.p * q, f.c * q, (f.f + t.$4) * q, t.$5);
}

Calc _chai(String milk, String sugar, bool patti, double cups) {
  final m = _milks[milk]!;
  final s = _sugars[sugar]!;
  final mult = patti && milk != 'black' ? 2.1 : 1.0;
  final kcal = (m.kcal * mult + s.$2) * cups;
  final label = 'Chai (${m.name}, ${s.$1}${patti && milk != 'black' ? ', Doodh patti' : ''}) · ${_q(cups)}×';
  final clean = m.clean + s.$3 - (patti && milk != 'black' ? 3 : 0);
  return Calc(label, kcal, m.p * mult * cups, (m.c * mult + s.$2 / 4) * cups, m.f * mult * cups, clean);
}

// ---------------------------------------------------------------- bottom sheet
Future<FoodEntry?> showDesiSheet(BuildContext context, Food f, String kind, String slot) {
  return showModalBottomSheet<FoodEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _DesiSheet(food: f, kind: kind, slot: slot),
  );
}

class _DesiSheet extends StatefulWidget {
  final Food food;
  final String kind, slot;
  const _DesiSheet({required this.food, required this.kind, required this.slot});
  @override
  State<_DesiSheet> createState() => _DesiSheetState();
}

class _DesiSheetState extends State<_DesiSheet> {
  String flour = 'wheat', milk = 'full', sugar = 'one';
  bool chupri = false, patti = false;
  int level = 1;
  double qty = 1;
  late String slot = widget.slot;

  List<double> get _qtys => widget.kind == 'roti' ? [0.5, 1, 1.5, 2, 3, 4] : widget.kind == 'chai' ? [0.5, 1, 2, 3] : [0.5, 1, 1.5, 2];

  Calc get _c => widget.kind == 'roti'
      ? _roti(flour, chupri, qty)
      : widget.kind == 'salan'
          ? _salan(widget.food, level, qty)
          : _chai(milk, sugar, patti, qty);

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)));

  Widget _chips<T>(List<(T, String)> opts, T cur, void Function(T) on) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final o in opts) ChoiceChip(label: Text(o.$2), selected: cur == o.$1, onSelected: (_) => setState(() => on(o.$1)))],
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final k = widget.kind;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H2(k == 'roti' ? 'Roti' : k == 'chai' ? 'Chai' : widget.food.name),
            Muted(k == 'roti' ? 'Pick the flour, the ghee and how many.' : k == 'salan' ? 'How much oil is in it? Oil is where most hidden calories are.' : 'Milk, sugar and how it is brewed.', size: 12.5),
            if (k == 'roti') ...[
              _title('Flour'),
              _chips<String>([for (final e in _flours.entries) (e.key, '${e.value.name} · ${e.value.kcal.round()} kcal')], flour, (v) => flour = v),
              Padding(padding: const EdgeInsets.only(top: 6), child: Muted(_flours[flour]!.note, size: 12)),
              _title('Ghee'),
              _chips<bool>([(false, 'Sukhi roti'), (true, 'Chupri (ghee) +50 kcal')], chupri, (v) => chupri = v),
            ],
            if (k == 'salan') ...[
              _title('Tari (cooking oil)'),
              Slider(value: level.toDouble(), min: 0, max: 2, divisions: 2, label: _tari[level].$1, onChanged: (v) => setState(() => level = v.round())),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < 3; i++)
                  Expanded(child: Text(_tari[i].$1, textAlign: i == 0 ? TextAlign.left : i == 1 ? TextAlign.center : TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: level == i ? FontWeight.w700 : FontWeight.w400))),
              ]),
              Padding(padding: const EdgeInsets.only(top: 6), child: Muted('${_tari[level].$2}: about +${_tari[level].$3.round()} kcal of oil per serving.', size: 12)),
            ],
            if (k == 'chai') ...[
              _title('Milk'),
              _chips<String>([for (final e in _milks.entries) (e.key, '${e.value.name} · ${e.value.kcal.round()} kcal')], milk, (v) {
                milk = v;
                if (v == 'black') patti = false;
              }),
              _title('Sugar'),
              _chips<String>([for (final e in _sugars.entries) (e.key, e.value.$2 == 0 ? e.value.$1 : '${e.value.$1} +${e.value.$2.round()}')], sugar, (v) => sugar = v),
              _title('Brew style'),
              _chips<bool>([(false, 'Standard paani and doodh'), (true, 'Doodh patti (thick)')], patti, (v) {
                if (v && milk == 'black') {
                  milk = 'full';
                }
                patti = v;
              }),
            ],
            _title(k == 'chai' ? 'How many cups' : k == 'roti' ? 'How many roti' : 'Servings (${widget.food.serving})'),
            _chips<double>([for (final q in _qtys) (q, _q(q))], qty, (v) => qty = v),
            _title('Meal'),
            _chips<String>([for (final s in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) (s, s)], slot, (v) => slot = v),
            const SizedBox(height: 14),
            Box(
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('P ${c.p.toStringAsFixed(1)} g', style: const TextStyle(fontSize: 13)),
                Text('C ${c.c.toStringAsFixed(1)} g', style: const TextStyle(fontSize: 13)),
                Text('F ${c.f.toStringAsFixed(1)} g', style: const TextStyle(fontSize: 13)),
                Text('Score ${c.clean >= 0 ? '+' : ''}${c.clean}', style: const TextStyle(fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  buzz(true);
                  Navigator.pop(context, FoodEntry(widget.food.id, qty, slot, label: c.label, kcalT: c.kcal, pT: c.p, cT: c.c, fT: c.f, clean: c.clean));
                },
                child: Text('Add ${c.kcal.round()} kcal'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
