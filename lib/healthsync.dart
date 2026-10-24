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
}
