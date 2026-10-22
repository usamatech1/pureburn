// Phone features: reminders, automatic steps and app lock.
// Everything here quietly does nothing on the web version, so the website keeps working.
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'i18n.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'ui.dart';

bool get onAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

// ------------------------------------------------------------------ reminders
class Reminders {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready || !onAndroid) return;
    await _p.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Asks Android for permission to show notifications. Returns true when allowed.
  static Future<bool> allow() async {
    if (!onAndroid) return false;
    try {
      await _init();
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return (await a?.requestNotificationsPermission()) ?? false;
    } catch (_) {
      return false;
    }
  }

  static const NotificationDetails _nd = NotificationDetails(
    android: AndroidNotificationDetails(
      'pureburn_reminders',
      'PureBurn reminders',
      channelDescription: 'Water, workout and meal reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  // The next time the clock shows h:m (on the given weekday, 1 = Monday). It is stored as one exact moment,
  // and the reminder repeats at that same time of day. It is refreshed every time the app opens.
  static tz.TZDateTime _next(int h, int m, {int? weekday}) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, h, m);
    if (weekday != null) {
      while (t.weekday != weekday || !t.isAfter(now)) {
        t = t.add(const Duration(days: 1));
      }
    } else if (!t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(t, tz.UTC);
  }

  static bool get anyOn => app.set['water'] == true || app.set['wk'] == true || app.set['meals'] == true;

  static Future<void> apply() async {
    if (!onAndroid) return;
    try {
      await _init();
      await _p.cancelAll();
      if (!anyOn) return;
      final s = app.set;
      if (s['water'] == true) {
        final every = ((s['waterEvery'] ?? 2) as num).toInt().clamp(1, 6);
        for (var h = 8; h <= 20; h += every) {
          await _p.zonedSchedule(
            id: 100 + h,
            title: tr('Time for a glass of water'),
            body: tr('Stay hydrated. Tap to log it in PureBurn.'),
            scheduledDate: _next(h, 0),
            notificationDetails: _nd,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        }
      }
      final d = app.d;
      if (s['wk'] == true && d.ok && d.plan != null) {
        const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        for (final r in d.plan!.sched) {
          final wd = names.indexOf(r.day) + 1;
          if (wd == 0) continue;
          await _p.zonedSchedule(
            id: 300 + wd,
            title: tr('Workout time'),
            body: '${r.name}. ${tr("Today's session is waiting for you.")}',
            scheduledDate: _next(((s['wkH'] ?? 18) as num).toInt(), ((s['wkM'] ?? 0) as num).toInt(), weekday: wd),
            notificationDetails: _nd,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
      if (s['meals'] == true && d.ok && d.diet != null) {
        var i = 0;
        for (final m in d.diet!.meals) {
          i++;
          final mm = RegExp(r'(\d+):(\d+)\s*(am|pm)').firstMatch(m.time);
          if (mm == null) continue;
          var h = int.parse(mm[1]!) % 12;
          if (mm[3] == 'pm') h += 12;
          await _p.zonedSchedule(
            id: 200 + i,
            title: tr('Meal time'),
            body: tr(m.name),
            scheduledDate: _next(h, int.parse(mm[2]!)),
            notificationDetails: _nd,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        }
      }
    } catch (_) {}
  }
}

// ------------------------------------------------------------------ automatic steps
class StepService {
  static StreamSubscription<StepCount>? _sub;
  static DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static int sensorToday = 0;

  static Future<String?> start() async {
    if (!onAndroid || app.set['autoSteps'] != true) return null;
    try {
      final st = await Permission.activityRecognition.request();
      if (!st.isGranted) return 'Permission was not given, so steps stay manual.';
      await _sub?.cancel();
      _sub = Pedometer.stepCountStream.listen(_onStep, onError: (_) {});
      return null;
    } catch (_) {
      return 'Automatic steps work in the Android app on phones with a step sensor.';
    }
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static void _onStep(StepCount e) {
    final total = e.steps;
    final today = isoDate(DateTime.now());
    Map<String, dynamic>? st;
    try {
      final raw = app.prefs?.getString('pureburn-stepbase');
      if (raw != null) st = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    final logged = app.logs[today]?.steps ?? 0;
    int base;
    if (st == null) {
      base = total - logged;
    } else {
      final last = (st['last'] as num).toInt();
      final date = st['date'] as String;
      if (total < last) {
        // The phone restarted, so its counter began again from zero.
        base = total - logged;
      } else if (date == today) {
        base = (st['base'] as num).toInt();
      } else if (date == isoDate(DateTime.now().subtract(const Duration(days: 1)))) {
        base = last;
      } else {
        base = total;
      }
    }
    final steps = (total - base).clamp(0, 200000);
    sensorToday = steps;
    app.prefs?.setString('pureburn-stepbase', jsonEncode({'date': today, 'base': base, 'last': total}));
    final now = DateTime.now();
    if (now.difference(_lastWrite).inSeconds >= 5 && steps != logged) {
      _lastWrite = now;
      app.log(today).steps = steps;
      app.save();
    }
  }
}

// ------------------------------------------------------------------ app lock
String hashPin(String pin) => sha256.convert(utf8.encode('pureburn:$pin')).toString();

class Biometric {
  static final LocalAuthentication _a = LocalAuthentication();

  static Future<bool> available() async {
    if (!onAndroid) return false;
    try {
      return (await _a.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> check() async {
    try {
      return await _a.authenticate(localizedReason: 'PureBurn', biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}

class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  DateTime? _away;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.hidden) {
      app.flushNow();
    }
    if (s == AppLifecycleState.paused) {
      _away = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final lockOn = app.set['lock'] == true && (app.set['pinHash'] as String).isNotEmpty;
      if (lockOn && _away != null && DateTime.now().difference(_away!).inSeconds > 20) {
        app.unlocked = false;
        app.refresh();
      }
      _away = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!app.loaded) return const Scaffold(body: Center(child: BrandMark(size: 56)));
    return app.unlocked ? widget.child : const LockScreen();
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String pin = '';
  String msg = '';

  @override
  void initState() {
    super.initState();
    if (app.set['bio'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  Future<void> _bio() async {
    if (await Biometric.check()) {
      app.unlocked = true;
      app.refresh();
    }
  }

  void _tap(String k) {
    if (pin.length >= 4) return;
    setState(() {
      pin += k;
      msg = '';
    });
    if (pin.length == 4) {
      if (hashPin(pin) == app.set['pinHash']) {
        app.unlocked = true;
        app.refresh();
      } else {
        HapticFeedback.mediumImpact();
        setState(() {
          pin = '';
          msg = 'Wrong PIN. Try again.';
        });
      }
    }
  }

  Widget _key(String k, {IconData? icon, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? (k.isEmpty ? null : () => _tap(k)),
          child: Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: k.isEmpty && icon == null ? null : Border.all(color: line(context))),
            child: icon != null ? Icon(icon) : Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(size: 56),
                const SizedBox(height: 14),
                const BrandLockup(height: 26),
                const SizedBox(height: 28),
                Text('Enter your PIN', style: TextStyle(color: muted(context))),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? fg(context) : Colors.transparent, border: Border.all(color: fg(context))),
                    ),
                ]),
                SizedBox(height: 28, child: Center(child: Text(msg, style: const TextStyle(fontSize: 12.5)))),
                for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
                  Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) _key(k)]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  app.set['bio'] == true ? _key('', icon: Icons.fingerprint, onTap: _bio) : _key(''),
                  _key('0'),
                  _key('', icon: Icons.backspace_outlined, onTap: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1))),
                ]),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 36),
                  child: Muted('Forgot your PIN? Restore is only possible by clearing the app data, which erases everything. Keep a backup.', size: 11),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ settings blocks
class ServiceSettings extends StatefulWidget {
  const ServiceSettings({super.key});
  @override
  State<ServiceSettings> createState() => _ServiceSettingsState();
}

class _ServiceSettingsState extends State<ServiceSettings> {
  String stepNote = '';

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggleRem(String key, bool on) async {
    if (on && !onAndroid) {
      _snack('Reminders work in the Android app. Install it on your phone to use them.');
      return;
    }
    if (on && !await Reminders.allow()) {
      _snack('Notifications are blocked. Allow them in your phone settings.');
      return;
    }
    app.set[key] = on;
    app.saveSettings();
    await Reminders.apply();
  }

  Widget _row(String title, String sub, bool on, ValueChanged<bool> ch, {Widget? extra}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Muted(sub, size: 12),
              ]),
            ),
            Switch(value: on, onChanged: ch),
          ]),
          if (extra != null && on) Padding(padding: const EdgeInsets.only(top: 8), child: extra),
        ]),
      );

  Future<void> _setPin() async {
    final a = TextEditingController(), b = TextEditingController();
    String err = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Set a PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: a, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: tr('Enter a new 4-digit PIN'))),
            TextField(controller: b, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: tr('Enter the PIN again to confirm'))),
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(fontSize: 12.5))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (a.text.length != 4 || a.text != b.text) {
                  set(() => err = 'The PINs do not match. Try again.');
                  return;
                }
                Navigator.pop(c, true);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      app.set['pinHash'] = hashPin(a.text);
      app.set['lock'] = true;
      app.unlocked = true;
      app.saveSettings();
      _snack('PIN is on. PureBurn will ask for it when it opens.');
    }
    a.dispose();
    b.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = app.set;
    final hasPin = s['lock'] == true && (s['pinHash'] as String).isNotEmpty;
    final every = ((s['waterEvery'] ?? 2) as num).toInt();
    final wkH = ((s['wkH'] ?? 18) as num).toInt(), wkM = ((s['wkM'] ?? 0) as num).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Reminders'),
          _row('Remind me to drink water', 'Every $every hours, from 8 am to 8 pm', s['water'] == true, (v) => _toggleRem('water', v),
              extra: Seg<int>(
                opts: const [(1, '1'), (2, '2'), (3, '3')],
                value: every,
                onChanged: (v) async {
                  s['waterEvery'] = v;
                  app.saveSettings();
                  await Reminders.apply();
                },
              )),
          _row('Workout reminder', 'On your workout days', s['wk'] == true, (v) => _toggleRem('wk', v),
              extra: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: wkH, minute: wkM));
                    if (t != null) {
                      s['wkH'] = t.hour;
                      s['wkM'] = t.minute;
                      app.saveSettings();
                      await Reminders.apply();
                    }
                  },
                  child: Text('${wkH.toString().padLeft(2, '0')}:${wkM.toString().padLeft(2, '0')}'),
                ),
              )),
          _row('Meal reminders', 'At each meal time in your plan', s['meals'] == true, (v) => _toggleRem('meals', v)),
          if (!onAndroid) const Muted('Reminders work in the Android app. Install it on your phone to use them.', size: 12),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Steps'),
          _row('Count steps automatically', 'Uses your phone step sensor. Needs permission to see your physical activity.', s['autoSteps'] == true, (v) async {
            if (v && !onAndroid) {
              _snack('Automatic steps work in the Android app on phones with a step sensor.');
              return;
            }
            s['autoSteps'] = v;
            app.saveSettings();
            if (v) {
              final e = await StepService.start();
              if (e != null) {
                s['autoSteps'] = false;
                app.saveSettings();
                _snack(e);
              }
            } else {
              await StepService.stop();
            }
          }),
          if (!onAndroid) const Muted('Automatic steps work in the Android app on phones with a step sensor.', size: 12),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('App lock'),
          _row('Ask for a PIN when PureBurn opens', hasPin ? 'On' : 'Off', hasPin, (v) async {
            if (v) {
              await _setPin();
            } else {
              s['lock'] = false;
              s['pinHash'] = '';
              s['bio'] = false;
              app.unlocked = true;
              app.saveSettings();
              _snack('Lock is off.');
            }
          }),
          if (hasPin) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [OutlinedButton(onPressed: _setPin, child: const Text('Change PIN'))]),
            const SizedBox(height: 12),
            _row('Use fingerprint too', 'Opens the app without typing the PIN', s['bio'] == true, (v) async {
              if (v) {
                if (!await Biometric.available()) {
                  _snack('Fingerprint is not available on this phone.');
                  return;
                }
                if (!await Biometric.check()) return;
              }
              s['bio'] = v;
              app.saveSettings();
            }),
          ],
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }
}
