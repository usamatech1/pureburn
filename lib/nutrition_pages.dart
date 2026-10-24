// Food diary, macro dashboard, meal swap, diet preferences, Ramadan mode and shopping list.
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'desi.dart';
import 'dietfit.dart';
import 'foods.dart';
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'pages.dart' show WeekStrip, WeekBars;
import 'state.dart';
import 'ui.dart';
import 'diet_extras.dart';

Widget _g([double h = 16]) => SizedBox(height: h);

void _snack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

List<String> _allergies() => [for (final a in (app.set['allergies'] ?? const []) as List) '$a'];
Set<String> blockedNow() => blockedTags('${app.set['dietType'] ?? 'any'}', _allergies());

// ---------------------------------------------------------------- calorie and macro dashboard
class MacroDash extends StatelessWidget {
  final DayInfo info;
  const MacroDash(this.info, {super.key});

  Widget _row(String label, double have, int goal) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Text('${have.round()} of $goal g', style: const TextStyle(fontSize: 12.5)),
          ]),
          const SizedBox(height: 6),
          Bar(goal > 0 ? have / goal : 0),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final pl = app.d.plan!;
    final left = pl.kcal - info.kcal;
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RingGauge(fraction: info.kcal / pl.kcal, center: '${(info.kcal * 100 / pl.kcal).round()}%', size: 92),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Calories today'),
              const SizedBox(height: 4),
              Text('${info.kcal}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: -1)),
              Muted(left >= 0 ? 'of ${pl.kcal} kcal, $left left' : 'of ${pl.kcal} kcal, ${-left} over', size: 12.5),
            ]),
          ),
        ]),
        _g(16),
        _row('Protein', info.p, pl.pG),
        _row('Carbs', info.c, pl.cG),
        _row('Fat', info.f, pl.fG),
        Muted('From plan meals: ${info.kcal - info.dK} kcal. From your food diary: ${info.dK} kcal. Macros of plan meals are estimates.', size: 12),
      ]),
    );
  }
}

// ---------------------------------------------------------------- food diary
class FoodDiaryPage extends StatefulWidget {
  const FoodDiaryPage({super.key});
  @override
  State<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

class _FoodDiaryPageState extends State<FoodDiaryPage> {
  final q = TextEditingController();

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  List<Food> _results() {
    final all = [...app.customFoods, ...foodDb];
    final s = q.text.trim().toLowerCase();
    if (s.isEmpty) return all.take(10).toList();
    return all.where((f) => f.name.toLowerCase().contains(s)).take(12).toList();
  }

  Future<void> _add(Food f) async {
    var servings = 1.0;
    var slot = 'Snack';
    final h = DateTime.now().hour;
    slot = h < 11 ? 'Breakfast' : h < 16 ? 'Lunch' : h < 19 ? 'Snack' : 'Dinner';
    final kind = desiKind(f);
    if (kind != null) {
      final e = await showDesiSheet(context, f, kind, slot);
      if (e != null) {
        app.addFood(app.selDate, e);
        _snack(context, 'Added to your food diary.');
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(f.name),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Muted('1 serving = ${f.serving}', size: 12.5),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.outlined(onPressed: () => set(() => servings = (servings - f.step).clamp(f.step, 20)), icon: const Icon(Icons.remove)),
              SizedBox(width: 90, child: Center(child: Text(fmtS(servings), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300)))),
              IconButton.outlined(onPressed: () => set(() => servings = (servings + f.step).clamp(f.step, 20)), icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
                ChoiceChip(label: Text(s), selected: slot == s, onSelected: (_) => set(() => slot = s)),
            ]),
            const SizedBox(height: 14),
            Text('${(f.kcal * servings).round()} kcal  ·  P ${(f.p * servings).round()} g  ·  C ${(f.c * servings).round()} g  ·  F ${(f.f * servings).round()} g', style: const TextStyle(fontSize: 12.5)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true) {
      app.addFood(app.selDate, FoodEntry(f.id, servings, slot));
      _snack(context, 'Added to your food diary.');
    }
  }

  Future<void> _create() async {
    final n = TextEditingController(), sv = TextEditingController(text: '1 serving');
    final k = TextEditingController(), p = TextEditingController(), c = TextEditingController(), f = TextEditingController();
    String err = '';
    Widget num(String label, TextEditingController t) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6, top: 8),
            child: TextField(controller: t, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label)),
          ),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add my own food'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: n, decoration: const InputDecoration(labelText: 'Food name')),
              const SizedBox(height: 8),
              TextField(controller: sv, decoration: const InputDecoration(labelText: 'One serving is')),
              Row(children: [num('kcal', k), num('Protein g', p)]),
              Row(children: [num('Carbs g', c), num('Fat g', f)]),
              if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(fontSize: 12.5))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final kc = double.tryParse(k.text.replaceAll(',', '.'));
                if (n.text.trim().isEmpty || kc == null || kc <= 0 || kc > 3000) {
                  set(() => err = 'Enter a name and the calories for one serving.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      double v(TextEditingController t) => double.tryParse(t.text.replaceAll(',', '.')) ?? 0;
      app.addCustomFood(Food('u${DateTime.now().millisecondsSinceEpoch}', n.text.trim(), sv.text.trim().isEmpty ? '1 serving' : sv.text.trim(), v(k).round(), v(p), v(c), v(f), 0, mine: true));
      _snack(context, 'Saved. Search for it to add it to a meal.');
    }
    for (final t in [n, sv, k, p, c, f]) {
      t.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = app.selDate;
    final info = app.dayInfo(date);
    final entries = app.food[date] ?? const <FoodEntry>[];
    final res = _results();
    final wk = app.weekDates();
    final infos = wk.map(app.dayInfo).toList();
    final target = app.d.plan!.kcal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const WeekStrip(),
      MacroDash(info),
      _g(),
      const CleanScoreCard(),
      for (final t in swapTips(date)) ...[
        _g(12),
        Box(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2, right: 12), child: Icon(Icons.tips_and_updates_outlined, size: 22)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Clean Burn tip'),
                const SizedBox(height: 4),
                Text(t.text, style: const TextStyle(height: 1.45)),
                if (t.action != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      buzz();
                      applySwap(date, t);
                    },
                    child: Text(t.action!),
                  ),
                ],
              ]),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: () => setState(() => dismissTip(t)),
              icon: const Icon(Icons.close, size: 18),
            ),
          ]),
        ),
      ],
      _g(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Add food'),
          TextField(
            controller: q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search roti, daal, biryani, chai...'),
          ),
          const SizedBox(height: 10),
          for (final f in res)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _add(f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Muted(f.serving, size: 12),
                    ]),
                  ),
                  if (f.mine) const Padding(padding: EdgeInsets.only(right: 8), child: Pill('Mine')),
                  Text('${f.kcal} kcal', style: const TextStyle(fontSize: 13)),
                  IconButton(
                    tooltip: 'Quick add 1 serving',
                    onPressed: () {
                      buzz();
                      final hh = DateTime.now().hour;
                      app.addFood(app.selDate, FoodEntry(f.id, 1, hh < 11 ? 'Breakfast' : hh < 16 ? 'Lunch' : hh < 19 ? 'Snack' : 'Dinner'));
                      _snack(context, 'Added 1 × ${f.name}. Tap the food to customise it.');
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                  ),
                ]),
              ),
            ),
          if (res.isEmpty) const Muted('No food found. Add your own below.'),
          _g(8),
          OutlinedButton.icon(onPressed: _create, icon: const Icon(Icons.edit_note), label: const Text('Add my own food')),
        ]),
      ),
      _g(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Eaten from your diary'),
          if (entries.isEmpty) const Muted('Nothing added for this day yet. Foods you add here count toward your calories.'),
          for (final slot in ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
            if (entries.any((e) => e.slot == slot)) ...[
              Padding(padding: const EdgeInsets.only(top: 6, bottom: 4), child: Eyebrow(slot)),
              for (var i = 0; i < entries.length; i++)
                if (entries[i].slot == slot && findFood(entries[i].id, app.customFoods) != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(child: Text(entries[i].label ?? '${fmtS(entries[i].servings)} × ${findFood(entries[i].id, app.customFoods)!.name}', style: const TextStyle(fontSize: 13.5))),
                      Text('${entries[i].custom ? entries[i].kcalT!.round() : (findFood(entries[i].id, app.customFoods)!.kcal * entries[i].servings).round()} kcal', style: const TextStyle(fontSize: 13)),
                      IconButton(onPressed: () => app.removeFood(date, i), icon: const Icon(Icons.close, size: 18)),
                    ]),
                  ),
            ],
        ]),
      ),
      if (app.customFoods.isNotEmpty) ...[
        _g(),
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('My foods'),
            for (final f in app.customFoods)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: Text('${f.name}  ·  ${f.kcal} kcal per ${f.serving}', style: const TextStyle(fontSize: 13))),
                  IconButton(onPressed: () => app.removeCustomFood(f.id), icon: const Icon(Icons.delete_outline, size: 19)),
                ]),
              ),
          ]),
        ),
      ],
      _g(),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Calories this week'),
          WeekBars(
            dates: wk,
            fracs: [for (final x in infos) x.kcal / target],
            labels: [for (final x in infos) x.kcal == 0 ? '-' : '${x.kcal}'],
          ),
          const SizedBox(height: 6),
          Muted('Full bar is your target of $target kcal. Counts plan meals and your diary.', size: 12),
        ]),
      ),
      _g(),
      const Muted('Calories and macros are typical values for home-cooked food and are estimates. A general guide only.', size: 12),
    ]);
  }
}

// ---------------------------------------------------------------- meal swap
void showSwapSheet(BuildContext context, Meal m) {
  final alts = alternatives(m.id, m.kcal, blockedNow(), exclude: m.tmpl);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), shrinkWrap: true, children: [
          H2('Swap ${m.name}'),
          Muted('Choices with about the same calories (${m.kcal} kcal). They follow your diet type and allergies.', size: 12.5),
          _g(12),
          for (final a in alts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  app.setSwap(m.id, a.$1.id);
                  Navigator.pop(c);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(a.$1.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Pill(rs(partsCost(a.$2, app.customFoods), 5)),
                    ]),
                    const SizedBox(height: 6),
                    Bullets(partsText(a.$2, app.customFoods)),
                  ]),
                ),
              ),
            ),
          if (alts.isEmpty) const Muted('No other choice fits your diet filters for this meal.'),
          if (app.swaps.containsKey(m.id))
            OutlinedButton.icon(
              onPressed: () {
                app.setSwap(m.id, null);
                Navigator.pop(c);
              },
              icon: const Icon(Icons.undo),
              label: const Text('Back to the original meal'),
            ),
        ]),
      ),
    ),
  );
}

// ---------------------------------------------------------------- diet preferences and Ramadan
class DietPrefsBox extends StatelessWidget {
  const DietPrefsBox({super.key});

  String _t(String k, String dflt) => '${app.set[k] ?? dflt}';

  Future<void> _pick(BuildContext context, String key, String dflt) async {
    final a = _t(key, dflt).split(':');
    final r = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(a[0]) ?? 4, minute: int.tryParse(a.length > 1 ? a[1] : '0') ?? 0));
    if (r != null) app.setPref(key, '${two(r.hour)}:${two(r.minute)}');
  }

  @override
  Widget build(BuildContext context) {
    final al = _allergies();
    final ram = app.set['ramadan'] == true;
    Widget chip(String k, String label) => FilterChip(
          label: Text(label),
          selected: al.contains(k),
          onSelected: (v) {
            final n = [...al];
            v ? n.add(k) : n.remove(k);
            app.setPref('allergies', n);
          },
        );
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Diet preferences'),
        Field(
          'Diet type',
          Seg<String>(opts: const [('any', 'Anything'), ('veg', 'Vegetarian'), ('vegan', 'Vegan')], value: _t('dietType', 'any'), onChanged: (v) => app.setPref('dietType', v)),
          hint: 'Vegetarian has no meat or fish. Vegan also has no egg or dairy.',
        ),
        Field(
          'Allergies and foods to avoid',
          Wrap(spacing: 8, runSpacing: 8, children: [chip('egg', 'Egg'), chip('dairy', 'Dairy'), chip('nuts', 'Nuts'), chip('fish', 'Fish')]),
          hint: 'Meals with these foods are swapped for a similar meal with about the same calories.',
        ),
        Field(
          'Your food budget',
          Seg<String>(opts: const [('low', 'Tight'), ('std', 'Standard'), ('high', 'Comfortable')], value: app.p.budget, onChanged: (v) {
            app.p.budget = v;
            app.save();
          }),
        ),
        const Divider(),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ramadan mode', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Muted('Plans your food as sehri, iftar and a dinner after taraweeh.', size: 12),
            ]),
          ),
          Switch(
            value: ram,
            onChanged: (v) {
              buzz();
              app.setPref('ramadan', v);
              _snack(context, v ? 'Ramadan mode is on. Your meals are now sehri, iftar and a dinner after taraweeh.' : 'Ramadan mode is off. Your normal meals are back.');
            },
          ),
        ]),
        if (ram) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(onPressed: () => _pick(context, 'sehri', '04:30'), icon: const Icon(Icons.nightlight_outlined, size: 18), label: Text('Sehri ${_t('sehri', '04:30')}')),
            OutlinedButton.icon(onPressed: () => _pick(context, 'iftar', '18:30'), icon: const Icon(Icons.wb_twilight, size: 18), label: Text('Iftar ${_t('iftar', '18:30')}')),
          ]),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- shopping list
class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});
  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  int days = 7;

  @override
  Widget build(BuildContext context) {
    final diet = app.d.diet!;
    final tot = shoppingTotals(diet, days, app.customFoods);
    final keys = tot.keys.where((k) => ingredients.containsKey(k) && tot[k]! > 0).toList();
    final groups = <String, List<String>>{};
    for (final k in keys) {
      groups.putIfAbsent(ingredients[k]!.group, () => []).add(k);
    }
    var cost = 0.0, left = 0.0;
    for (final k in keys) {
      final c = tot[k]! * ingredients[k]!.rate;
      cost += c;
      if (!app.shopDone.contains(k)) left += c;
    }
    String text() {
      final b = StringBuffer('PUREBURN - SHOPPING LIST ($days days)\n\n');
      for (final g in groups.entries) {
        b.writeln(g.key.toUpperCase());
        for (final k in g.value) {
          b.writeln('- ${ingredients[k]!.label}: ${fmtQty(k, tot[k]!)}');
        }
        b.writeln();
      }
      b.writeln('About ${rs(cost, 50)}');
      return b.toString();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        dark: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Estimated cost', onDark: true),
          const SizedBox(height: 6),
          Text(rs(cost, 50), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('${rs(left, 50)} still to buy', style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6A6A6))),
        ]),
      ),
      _g(12),
      Seg<int>(opts: const [(3, '3 days'), (7, '1 week'), (14, '2 weeks')], value: days, onChanged: (v) => setState(() => days = v)),
      _g(12),
      for (final g in groups.entries) ...[
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H2(g.key),
            for (final k in g.value)
              InkWell(
                onTap: () {
                  app.shopDone.contains(k) ? app.shopDone.remove(k) : app.shopDone.add(k);
                  app.save();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Checkbox(
                      value: app.shopDone.contains(k),
                      onChanged: (v) {
                        v == true ? app.shopDone.add(k) : app.shopDone.remove(k);
                        app.save();
                      },
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: app.shopDone.contains(k) ? 0.5 : 1,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ingredients[k]!.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Muted(fmtQty(k, tot[k]!), size: 12.5),
                        ]),
                      ),
                    ),
                    Text(rs(tot[k]! * ingredients[k]!.rate, 5), style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
          ]),
        ),
        _g(12),
      ],
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text()));
            _snack(context, 'List copied. You can paste it in WhatsApp or notes.');
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy list'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855), foregroundColor: Colors.white),
          onPressed: () => shareWhatsApp(context, text()),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Share on WhatsApp'),
        ),
        OutlinedButton(
          onPressed: () {
            app.shopDone.clear();
            app.save();
          },
          child: const Text('Clear ticks'),
        ),
      ]),
      _g(),
      const Muted('Made from your current diet plan, including swaps, diet filters and Ramadan mode. Quantities are raw ingredients and rates are rough national averages. Prices change by city and season.', size: 12),
    ]);
  }
}
