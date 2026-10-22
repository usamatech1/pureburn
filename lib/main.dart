import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'state.dart';
import 'ui.dart';
import 'pages.dart';
import 'services.dart';

final app = AppState();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.load().then((_) async {
    await Reminders.apply();
    await StepService.start();
  });
  runApp(const PureBurnApp());
}

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: Colors.black, brightness: b).copyWith(
    primary: dark ? Colors.white : Colors.black,
    onPrimary: dark ? Colors.black : Colors.white,
    surface: dark ? const Color(0xFF050505) : const Color(0xFFF4F4F4),
    onSurface: dark ? const Color(0xFFF5F5F5) : const Color(0xFF0B0B0B),
    secondaryContainer: dark ? Colors.white : Colors.black,
    onSecondaryContainer: dark ? Colors.black : Colors.white,
    outline: dark ? const Color(0xFF3A3A3A) : const Color(0xFFCBCBCB),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : Colors.transparent),
      checkColor: WidgetStateProperty.all(scheme.onPrimary),
      side: BorderSide(color: scheme.outline, width: 1.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF181818) : const Color(0xFFEFEFEF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14))),
  );
}

class PureBurnApp extends StatelessWidget {
  const PureBurnApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'PureBurn',
        debugShowCheckedModeBanner: false,
        themeMode: app.theme,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Shell(),
      ),
    );
  }
}

class ModDef {
  final String id, title, eyebrow;
  final IconData icon;
  final String? group;
  const ModDef(this.id, this.title, this.eyebrow, this.icon, [this.group]);
}

const mods = [
  ModDef('dashboard', 'Dashboard', 'Overview', Icons.dashboard_outlined, 'Overview'),
  ModDef('profile', 'Profile and goal', 'Setup', Icons.person_outline, 'Setup'),
  ModDef('result', 'Your plan', 'Result', Icons.assignment_turned_in_outlined),
  ModDef('bmi', 'BMI and weight', 'Your body', Icons.speed_outlined),
  ModDef('dex', 'Daily exercise', 'Today', Icons.fitness_center, 'Today'),
  ModDef('workout', 'Workout player', 'Today', Icons.play_circle_outline),
  ModDef('ddiet', 'Daily diet', 'Today', Icons.restaurant_outlined),
  ModDef('foods', 'Food diary', 'Today', Icons.restaurant_menu),
  ModDef('sleep', 'Sleep', 'Today', Icons.bedtime_outlined),
  ModDef('health', 'Health modes', 'Sugar and blood pressure', Icons.monitor_heart_outlined),
  ModDef('explan', 'Exercise plan', 'Weekly plan', Icons.calendar_month_outlined, 'Plans'),
  ModDef('dietplan', 'Diet plan', 'Meal plan', Icons.list_alt_outlined),
  ModDef('shop', 'Shopping list', 'Plans', Icons.shopping_basket_outlined),
  ModDef('progress', 'Progress', 'Tracking', Icons.show_chart, 'Tracking'),
  ModDef('measure', 'Measurements', 'Your body', Icons.straighten),
  ModDef('report', 'Weekly report', 'Share', Icons.ios_share_outlined),
  ModDef('coach', 'AI coach', 'Coach', Icons.psychology_alt_outlined, 'Coach and community'),
  ModDef('challenges', 'Challenges', 'Community', Icons.emoji_events_outlined),
  ModDef('account', 'Account and sync', 'Account', Icons.cloud_sync_outlined),
  ModDef('settings', 'Settings', 'More', Icons.tune, 'More'),
];

class Shell extends StatelessWidget {
  const Shell({super.key});

  Widget _side(BuildContext context, {bool drawer = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = app.d;
    return Container(
      width: 268,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      decoration: BoxDecoration(color: card(context), border: BorderDirectional(end: BorderSide(color: line(context)))),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(children: [
              const BrandMark(size: 40),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text.rich(TextSpan(children: [
                  TextSpan(text: 'PURE', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: 'BURN', style: TextStyle(fontWeight: FontWeight.w300)),
                ]), style: TextStyle(fontSize: 17, letterSpacing: 3.5)),
                const SizedBox(height: 3),
                Text('BURN CLEAN. LIVE PURE.', style: TextStyle(fontSize: 8.5, letterSpacing: 1.6, color: muted(context))),
              ]),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              for (final m in mods) ...[
                if (m.group != null)
                  Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 6), child: Eyebrow(m.group!)),
                _NavBtn(m: m, on: app.mod == m.id, onTap: () {
                  app.go(m.id);
                  if (drawer) Navigator.of(context).pop();
                }),
              ],
            ]),
          ),
          Divider(color: line(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(d.ok ? 'BMI ${d.bmi.toStringAsFixed(1)} · ${d.cat}' : 'BMI --', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 0.8)),
          ),
          OutlinedButton(onPressed: () => app.toggleTheme(dark), child: Text(dark ? 'Light mode' : 'Dark mode')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final m = mods.firstWhere((x) => x.id == app.mod);
    final body = SingleChildScrollView(
      key: ValueKey(app.mod),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (app.mod != 'dashboard') ...[
              Eyebrow(m.eyebrow),
              const SizedBox(height: 6),
              H1(m.title),
              const SizedBox(height: 20),
            ],
            ModuleView(id: app.mod),
          ]),
        ),
      ),
    );
    if (wide) {
      return LockGate(child: Scaffold(body: Row(children: [_side(context), Expanded(child: body)])));
    }
    return LockGate(child: Scaffold(
      appBar: AppBar(title: app.mod == 'dashboard' ? const BrandLockup() : Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)), backgroundColor: Theme.of(context).scaffoldBackgroundColor, elevation: 0),
      drawer: Builder(builder: (ctx) => Drawer(width: 268, child: _side(ctx, drawer: true))),
      body: body,
    ));
  }
}

class _NavBtn extends StatelessWidget {
  final ModDef m;
  final bool on;
  final VoidCallback onTap;
  const _NavBtn({required this.m, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final bg = on ? fg(context) : Colors.transparent;
    final ink = on ? Theme.of(context).colorScheme.surface : muted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(m.icon, size: 19, color: ink),
            const SizedBox(width: 12),
            Text(m.title, style: TextStyle(color: ink, fontWeight: on ? FontWeight.w600 : FontWeight.w500, fontSize: 14.5)),
          ]),
        ),
      ),
    );
  }
}
