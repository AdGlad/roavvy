import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

// Tab index contract from ADR-052 / MainShell:
const int _kStatsTab = 2;
const int _kScanTab = 3;

const int _kNudgeNotificationId = 0;
const int _kAchievementNotificationId = 1;

/// Singleton service for local push notifications (ADR-056).
///
/// Schedules:
/// - An immediate notification when an achievement is unlocked (tapping
///   navigates to the Stats tab).
/// - A 30-day nudge after each scan completes (tapping navigates to Scan tab).
///
/// All public methods are no-ops when [init] has not been called, which keeps
/// widget tests safe without needing to mock the plugin.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Emits the tab index to switch to when a notification is tapped.
  /// [MainShell] adds a listener in [State.initState].
  final ValueNotifier<int?> pendingTabIndex = ValueNotifier(null);

  bool _initialized = false;

  /// Initialises the plugin. Must be called once in [main] before [runApp].
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const iosSettings = DarwinInitializationSettings(
      // Permissions are requested explicitly via [requestPermission].
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('tab:')) return;
    final tabIndex = int.tryParse(payload.substring(4));
    if (tabIndex != null) pendingTabIndex.value = tabIndex;
  }

  /// Returns the tab index embedded in the notification that cold-started the
  /// app, or null if the app was not launched from a notification.
  Future<int?> getLaunchTab() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    if (payload == null || !payload.startsWith('tab:')) return null;
    return int.tryParse(payload.substring(4));
  }

  /// Requests notification permission from iOS. Returns true if granted.
  /// Call once, after the first successful scan (ADR-056).
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (impl == null) return false;
    final granted = await impl.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  /// Returns true if the system permission status is no longer undetermined
  /// (i.e. the user has already been prompted — granted or denied).
  Future<bool> hasRequestedPermission() async {
    if (!_initialized) return false;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (impl == null) return false;
    final settings = await impl.checkPermissions();
    // isEnabled is null only when status is truly undetermined (never asked).
    return settings?.isEnabled != null;
  }

  /// Fires an immediate local notification for an achievement unlock.
  /// Tapping it switches to the Stats tab (index 2).
  Future<void> scheduleAchievementUnlock({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      _kAchievementNotificationId,
      title,
      body,
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      payload: 'tab:$_kStatsTab',
    );
  }

  /// Cancels any pending scan nudge and schedules a new one 30 days from now.
  /// Tapping it switches to the Scan tab (index 3).
  Future<void> scheduleNudge() async {
    if (!_initialized) return;
    await _plugin.cancel(_kNudgeNotificationId);
    await _plugin.zonedSchedule(
      _kNudgeNotificationId,
      'Time to explore',
      'Scan your recent photos to discover new countries.',
      tz.TZDateTime.now(tz.UTC).add(const Duration(days: 30)),
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      payload: 'tab:$_kScanTab',
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
