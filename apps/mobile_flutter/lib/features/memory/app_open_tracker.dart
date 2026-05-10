import 'package:shared_preferences/shared_preferences.dart';

/// Tracks app-open timestamps to infer the user's preferred notification hour.
///
/// Called fire-and-forget from [MainShell.initState] on every app launch.
/// Used by [MemoryPulseService.scheduleNextAnniversaryNotification] to pick
/// a morning or evening delivery hour instead of a hardcoded 9 AM (M95).
class AppOpenTracker {
  AppOpenTracker._();

  static const _kKey = 'appOpen:lastTimestamp';

  /// Persists the current Unix timestamp (seconds) to SharedPreferences.
  static Future<void> recordNow() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt(_kKey, ts);
  }

  /// Returns the preferred notification delivery hour (local time) based on
  /// the last recorded app-open time:
  ///
  /// - Last open between 06:00–11:59 → 8 (morning user)
  /// - Last open between 16:00–23:59 → 18 (evening user)
  /// - No data or any other hour    → 9 (default)
  static Future<int> preferredHour() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kKey);
    if (ts == null) return 9;

    final lastOpen = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final hour = lastOpen.hour;

    if (hour >= 6 && hour < 12) return 8;
    if (hour >= 16) return 18;
    return 9;
  }
}
