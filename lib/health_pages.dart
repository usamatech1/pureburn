// Health modes: blood sugar and blood pressure logs with general guidance.
// This is a diary and a set of general tips. It never diagnoses and never advises on medicines.
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'ui.dart';

const emergencyNote = 'In an emergency call your local emergency number (1122 in Pakistan) or go to the nearest hospital.';

// ---------- data ----------
List<Map<String, dynamic>> readings() {
  final raw = app.set['hread'];
  if (raw is! List) return [];
  return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
}

void _store(List<Map<String, dynamic>> l) {
  l.sort((a, b) => ('${a['at']}').compareTo('${b['at']}'));
  if (l.length > 300) l.removeRange(0, l.length - 300);
  app.set['hread'] = l;
  app.saveSettings();
  app.save();
}

List<String> activeModes() {
  final raw = app.set['health'];
  return raw is List ? [for (final e in raw) '$e'] : <String>[];
}

bool healthOn(String m) => app.set['healthOk'] == true && activeModes().contains(m);

String? latestOf(String type) {
  final l = readings().where((e) => e['t'] == type).toList();
  if (l.isEmpty) return null;
  final e = l.last;
  return type == 'sugar' ? '${e['v']} mg/dL' : '${e['s']}/${e['di']} mmHg';
}

// ---------- classification ----------
class Status {
  final int level; // 0 fine, 1 watch, 2 high or low, 3 urgent
  final String label, advice;
  const Status(this.level, this.label, this.advice);
}

const sugarCtx = {
  'fast': 'Fasting',
  'before': 'Before a meal',
  'after': '2 hours after a meal',
  'bed': 'Bedtime',
  'random': 'Other time',
};

Status sugarStatus(int v, String ctx) {
  final after = ctx == 'after';
  if (v < 54) return const Status(3, 'Very low', 'This is a dangerously low sugar. Follow the low sugar plan your doctor gave you, and get help right away if you feel confused, shaky or faint. $emergencyNote');
  if (v < 70) return const Status(2, 'Low', 'This is low. Follow the low sugar plan your doctor gave you, then check again in 15 minutes. If you feel unwell, get help.');
  if (v > 300) return const Status(3, 'Very high', 'This is very high. Drink water, check again, and contact your doctor today. If you feel sick, vomit, breathe fast or are very sleepy, get emergency care.');
  if (v <= (after ? 180 : 130)) return const Status(0, 'In the usual target range', 'Good. Keep up your routine. Your doctor may have given you a different target, so follow theirs.');
  if (v <= (after ? 250 : 180)) return const Status(1, 'Above target', 'A little high. Look at your last meal, portion sizes and activity. A short walk after meals helps. Share repeated high readings with your doctor.');
  return const Status(2, 'High', 'This is high. Drink water, avoid sweet drinks and talk to your doctor if it stays high.');
}

Status bpStatus(int s, int d) {
  if (s > 180 || d > 120) return Status(3, 'Very high', 'Sit and rest for 5 minutes, then measure again. If it is still this high, or you have chest pain, trouble breathing, weakness, vision or speech changes, get emergency help now. $emergencyNote');
  if (s >= 140 || d >= 90) return const Status(2, 'High (stage 2 range)', 'This is in the high range. If it stays this way across several days, see your doctor soon. Do not change any medicine on your own.');
  if (s >= 130 || d >= 80) return const Status(1, 'Raised (stage 1 range)', 'A little raised. Less salt, more walking and good sleep help. Share your readings with your doctor.');
  if (s >= 120) return const Status(1, 'Slightly elevated', 'Slightly above ideal. Cut back on salt and keep active.');
  if (s < 90 || d < 60) return const Status(2, 'Low', 'This is low. If you feel dizzy or faint, sit or lie down, drink fluids and tell your doctor.');
  return const Status(0, 'Normal', 'Good. Keep up your healthy habits.');
}

IconData _icon(int level) => level == 0 ? Icons.check_circle_outline : (level == 1 ? Icons.info_outline : Icons.warning_amber_rounded);

// ---------- page ----------
class HealthPage extends StatefulWidget {
  const HealthPage({super.key});
  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final sugar = TextEditingController();
  final sys = TextEditingController();
  final dia = TextEditingController();
  final pulse = TextEditingController();
  String ctx = 'fast';
  Status? lastSugar, lastBp;

  @override
  void dispose() {
    sugar.dispose();
    sys.dispose();
    dia.dispose();
    pulse.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _toggle(String m, bool on) {
    final l = activeModes();
    if (on && !l.contains(m)) l.add(m);
    if (!on) l.remove(m);
    app.set['health'] = l;
    app.saveSettings();
    app.save();
    setState(() {});
  }

  void _saveSugar() {
    final v = int.tryParse(sugar.text.trim());
    if (v == null || v < 20 || v > 600) {
      _toast('Enter your sugar in mg/dL, between 20 and 600.');
      return;
    }
    final l = readings()..add({'t': 'sugar', 'd': app.selDate, 'v': v, 'c': ctx, 'at': DateTime.now().millisecondsSinceEpoch});
    buzz(true);
    _store(l);
    sugar.clear();
    setState(() => lastSugar = sugarStatus(v, ctx));
  }

  void _saveBp() {
    final s = int.tryParse(sys.text.trim());
    final d = int.tryParse(dia.text.trim());
    final p = int.tryParse(pulse.text.trim());
    if (s == null || d == null || s < 60 || s > 260 || d < 30 || d > 160 || d >= s) {
      _toast('Enter the top number (60 to 260) and the bottom number (30 to 160).');
      return;
    }
    final l = readings()..add({'t': 'bp', 'd': app.selDate, 's': s, 'di': d, if (p != null && p >= 30 && p <= 220) 'p': p, 'at': DateTime.now().millisecondsSinceEpoch});
    buzz(true);
    _store(l);
    sys.clear();
    dia.clear();
    pulse.clear();
    setState(() => lastBp = bpStatus(s, d));
  }

  void _delete(Map<String, dynamic> e) {
    final l = readings()..removeWhere((x) => x['at'] == e['at'] && x['t'] == e['t']);
    _store(l);
    setState(() {});
  }

  Widget _statusBox(Status s) => Box(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_icon(s.level), size: 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(s.advice, style: const TextStyle(height: 1.45)),
          ])),
        ]),
      );

  Widget _gate() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Before you start'),
            const Bullets([
              'Health modes are a diary and general tips. They are not medical advice and cannot diagnose anything.',
              'Never change or skip a medicine, or an insulin dose, because of this app. Ask your doctor.',
              'Your doctor\'s targets always come first. The ranges here are common general ranges.',
              'If a reading is very high or very low, or you feel unwell, get medical help. $emergencyNote',
              'Your readings stay in your private account space and on this device.',
            ]),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                app.set['healthOk'] = true;
                app.saveSettings();
                app.save();
                setState(() {});
              },
              child: const Text('I understand'),
            ),
          ]),
        ),
      ]);

  Widget _history(String type) {
    final l = readings().where((e) => e['t'] == type).toList().reversed.take(8).toList();
    if (l.isEmpty) return const Muted('No readings yet.');
    return Column(children: [
      for (final e in l)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(_icon(type == 'sugar' ? sugarStatus(e['v'] as int, '${e['c']}').level : bpStatus(e['s'] as int, e['di'] as int).level), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                type == 'sugar'
                    ? '${e['v']} mg/dL · ${sugarCtx[e['c']] ?? ''}'
                    : '${e['s']}/${e['di']} mmHg${e['p'] != null ? ' · pulse ${e['p']}' : ''}',
              ),
            ),
            Muted('${e['d']}', size: 12),
            IconButton(onPressed: () => _delete(e), icon: const Icon(Icons.close, size: 18), tooltip: 'Delete'),
          ]),
        ),
    ]);
  }

  String _avg(String type) {
    final cut = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final l = readings().where((e) => e['t'] == type && (e['at'] as num) >= cut).toList();
    if (l.isEmpty) return '-';
    if (type == 'sugar') {
      return '${(l.fold<int>(0, (a, e) => a + (e['v'] as int)) / l.length).round()} mg/dL';
    }
    final s = l.fold<int>(0, (a, e) => a + (e['s'] as int)) / l.length;
    final d = l.fold<int>(0, (a, e) => a + (e['di'] as int)) / l.length;
    return '${s.round()}/${d.round()}';
  }

  Widget _sugarSection() {
    final cnt = readings().where((e) => e['t'] == 'sugar').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Blood sugar'),
          const Muted('Log a reading from your glucose meter.', size: 12.5),
          const SizedBox(height: 10),
          TextField(controller: sugar, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sugar (mg/dL)')),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in sugarCtx.entries) ChoiceChip(label: Text(e.value), selected: ctx == e.key, onSelected: (_) => setState(() => ctx = e.key)),
          ]),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saveSugar, child: const Text('Save reading')),
        ]),
      ),
      if (lastSugar != null) ...[const SizedBox(height: 12), _statusBox(lastSugar!)],
      const SizedBox(height: 12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const H2('Recent readings'),
            Pill('7 day average: ${_avg('sugar')}'),
          ]),
          const SizedBox(height: 6),
          _history('sugar'),
          if (cnt > 0) const SizedBox(height: 6),
        ]),
      ),
      const SizedBox(height: 12),
      const Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2('Food tips for sugar'),
          Bullets([
            'Choose whole wheat roti, brown rice or oats over white rice and maida. Keep roti to 1 or 2 at a meal.',
            'Fill half your plate with sabzi and salad, a quarter with daal, chana or chicken, and a quarter with roti or rice.',
            'Take chai and lassi without sugar. Avoid cold drinks, juices and mithai.',
            'Eat at regular times and do not skip meals.',
            'A 10 to 15 minute walk after meals helps bring sugar down.',
            'Take fruit as a whole fruit in small portions, not as juice.',
          ]),
        ]),
      ),
    ]);
  }

  Widget _bpSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Blood pressure'),
          const Muted('Sit quietly for 5 minutes before measuring. Log the top and bottom numbers.', size: 12.5),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: sys, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Top (systolic)'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: dia, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bottom (diastolic)'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: pulse, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pulse (optional)')),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saveBp, child: const Text('Save reading')),
        ]),
      ),
      if (lastBp != null) ...[const SizedBox(height: 12), _statusBox(lastBp!)],
      const SizedBox(height: 12),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const H2('Recent readings'),
            Pill('7 day average: ${_avg('bp')}'),
          ]),
          const SizedBox(height: 6),
          _history('bp'),
        ]),
      ),
      const SizedBox(height: 12),
      const Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2('Food and habit tips for blood pressure'),
          Bullets([
            'Cut down salt. Go easy on achar, papad, namkeen, chips, instant noodles and salty snacks. Aim for under 5 g of salt a day.',
            'Taste food before adding salt at the table.',
            'Add potassium rich foods such as banana, dahi, spinach and beans, unless your doctor limited potassium for you.',
            'Walk for 30 minutes on most days. Keep a healthy weight.',
            'Sleep 7 to 8 hours and find a way to unwind, such as slow breathing for 5 minutes.',
            'Avoid smoking and too much strong chai or coffee.',
          ]),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (app.set['healthOk'] != true) return _gate();
    final modes = activeModes();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Your health modes'),
          const Muted('Turn on what you want to track. You can turn them off any time.', size: 12.5),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChip(label: const Text('Blood sugar'), selected: modes.contains('sugar'), onSelected: (v) => _toggle('sugar', v)),
            FilterChip(label: const Text('Blood pressure'), selected: modes.contains('bp'), onSelected: (v) => _toggle('bp', v)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      if (modes.contains('sugar')) ...[_sugarSection(), const SizedBox(height: 16)],
      if (modes.contains('bp')) ...[_bpSection(), const SizedBox(height: 16)],
      const Box(
        child: Muted(
          'General wellness information only, not medical advice. It does not replace your doctor, your tests or your medicines. Follow the targets your doctor gave you. $emergencyNote',
          size: 12.5,
        ),
      ),
    ]);
  }
}

String healthSummary() {
  if (app.set['healthOk'] != true || activeModes().isEmpty) return 'Track blood sugar and blood pressure with general tips';
  final parts = <String>[];
  final s = latestOf('sugar'), b = latestOf('bp');
  if (activeModes().contains('sugar')) parts.add('Sugar ${s ?? 'no reading yet'}');
  if (activeModes().contains('bp')) parts.add('BP ${b ?? 'no reading yet'}');
  return parts.join(' · ');
}
