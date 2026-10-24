// Steps from Health Connect on Android. Google Fit, Samsung Health and most watches write into it.
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'logic.dart';
import 'main.dart' show app;
import 'services.dart' show onAndroid;

class HealthSync {
  static final Health _h = Health();
  static bool _configured = false;
  static bool busy = false;

  static bool get supported => onAndroid;
  static bool get enabled => supported && app.set['hcSync'] == true;

  /// Time of the last good sync, or null.
  static DateTime? get last {
    final v = app.set['hcLast'];
    return v is String ? DateTime.tryParse(v) : null;
  }

  static const _types = [HealthDataType.STEPS];
  static const _sleepTypes = [HealthDataType.SLEEP_SESSION];

  static Future<void> _cfg() async {
    if (_configured) return;
    await _h.configure();
    _configured = true;
  }

  /// Asks for permission and pulls today's steps. Returns null on success, otherwise a short message.
  static Future<String?> connect() async {
    if (!supported) return 'Health sync works in the Android app.';
    try {
      await _cfg();
      final ok = await _h.requestAuthorization(_types, permissions: const [HealthDataAccess.READ]);
      if (!ok) {
        return 'Permission was not given. Make sure Health Connect is installed (free on Google Play) and allow PureBurn to read steps.';
      }
      app.set['hcSync'] = true;
      app.save();
      return await sync();
    } catch (e) {
      return 'Could not reach Health Connect. Install or update it from Google Play, then try again.';
    }
  }

  static Future<void> disconnect() async {
    app.set['hcSync'] = false;
    app.save();
  }

  /// Reads today's steps from Health Connect and stores them. Returns null on success.
  static Future<String?> sync() async {
    if (!enabled || busy) return null;
    busy = true;
    try {
      await _cfg();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final n = await _h.getTotalStepsInInterval(midnight, now);
      if (n == null) return 'Health Connect returned no steps yet. Open your fitness app once and try again.';
      final today = isoDate(now);
      if (n > 0) {
        app.log(today).steps = n.clamp(0, 200000);
      }
      app.set['hcLast'] = now.toIso8601String();
      app.save();
      return null;
    } catch (e) {
      debugPrint('health sync: $e');
      return 'Sync failed. Check that PureBurn is allowed to read steps in Health Connect.';
    } finally {
      busy = false;
    }
  }

  static bool get sleepEnabled => supported && app.set['hcSleep'] == true;

  static DateTime? get lastSleep {
    final v = app.set['hcSleepLast'];
    return v is String ? DateTime.tryParse(v) : null;
  }

  /// Asks for permission to read sleep and pulls last night. Returns null on success.
  static Future<String?> connectSleep() async {
    if (!supported) return 'Health sync works in the Android app.';
    try {
      await _cfg();
      final ok = await _h.requestAuthorization(_sleepTypes, permissions: const [HealthDataAccess.READ]);
      if (!ok) return 'Permission was not given. Make sure Health Connect is installed and allow PureBurn to read sleep.';
      app.set['hcSleep'] = true;
      app.save();
      return await syncSleep();
    } catch (e) {
      return 'Could not reach Health Connect. Install or update it from Google Play, then try again.';
    }
  }

  static Future<void> disconnectSleep() async {
    app.set['hcSleep'] = false;
    app.save();
  }

  /// Reads last night's sleep sessions (from yesterday noon) and stores them under today.
  static Future<String?> syncSleep() async {
    if (!sleepEnabled || busy) return null;
    busy = true;
    try {
      await _cfg();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 12));
      final pts = await _h.getHealthDataFromTypes(types: _sleepTypes, startTime: start, endTime: now);
      final s = pts.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();
      if (s.isEmpty) return 'No sleep found yet. Wear your watch to bed, or open your sleep app once and try again.';
      var mins = 0;
      var bed = s.first.dateFrom, wake = s.first.dateTo;
      for (final p in s) {
        mins += p.dateTo.difference(p.dateFrom).inMinutes;
        if (p.dateFrom.isBefore(bed)) bed = p.dateFrom;
        if (p.dateTo.isAfter(wake)) wake = p.dateTo;
      }
      if (mins < 30) return 'Sleep found was very short, so it was not saved.';
      String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      final l = app.log(isoDate(now));
      l.sleep = (mins / 6).round() / 10;
      l.bed = hm(bed);
      l.wake = hm(wake);
      app.set['hcSleepLast'] = now.toIso8601String();
      app.save();
      return null;
    } catch (e) {
      debugPrint('sleep sync: $e');
      return 'Sleep sync failed. Check that PureBurn is allowed to read sleep in Health Connect.';
    } finally {
      busy = false;
    }
  }
}
