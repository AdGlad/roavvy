import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Remote Config initialisation and periodic refresh.
///
/// Defaults are fail-open: if the config cannot be fetched (offline, cold
/// start before first fetch), purchasing stays enabled.
class RemoteConfigService {
  RemoteConfigService._();

  /// Called when real-time RC updates are activated. Callers (e.g. MainShell)
  /// should invalidate purchasing providers when this fires.
  static final onUpdate = StreamController<void>.broadcast();

  static Future<void> initialise() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      // Debug/emulator: fetch on every call. Production: honour the 1-hour
      // minimum enforced by the Firebase SDK to avoid quota exhaustion.
      minimumFetchInterval:
          kDebugMode ? Duration.zero : const Duration(hours: 1),
    ));
    await rc.setDefaults(const {
      'purchasing_enabled': true,
      // Per-template flags — all fail-open.
      'purchasing_enabled_passport': true,
      'purchasing_enabled_flags': true,
      'purchasing_enabled_tour_dates': true,
      'purchasing_enabled_heart_flags': true,
      'purchasing_enabled_ribbon': true,
      'purchasing_enabled_typography': true,
      'purchasing_enabled_badge': true,
      'purchasing_enabled_word_cloud': true,
      'purchasing_enabled_landmark': true,
    });
    // Best-effort fetch — failure is silent; the default keeps the store open.
    try {
      await rc.fetchAndActivate();
    } catch (_) {}

    // Real-time listener: Firebase pushes changes instantly, bypassing the
    // 1-hour minimum fetch interval. When a new value arrives, activate it
    // and notify listeners so Riverpod providers can be invalidated.
    rc.onConfigUpdated.listen((_) async {
      try {
        await rc.activate();
        onUpdate.add(null);
      } catch (_) {}
    });
  }

  /// Re-fetches and activates config. Called on foreground resume.
  /// Failure is silent — cached / default values remain in effect.
  static Future<void> refresh() async {
    try {
      await FirebaseRemoteConfig.instance.fetchAndActivate();
    } catch (_) {}
  }
}
