import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Remote Config initialisation and periodic refresh.
///
/// Defaults are fail-open: if the config cannot be fetched (offline, cold
/// start before first fetch), purchasing stays enabled.
class RemoteConfigService {
  RemoteConfigService._();

  static Future<void> initialise() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      // Debug/emulator: fetch on every call. Production: honour the 1-hour
      // minimum enforced by the Firebase SDK to avoid quota exhaustion.
      minimumFetchInterval:
          kDebugMode ? Duration.zero : const Duration(hours: 1),
    ));
    await rc.setDefaults(const {'purchasing_enabled': true});
    // Best-effort fetch — failure is silent; the default keeps the store open.
    try {
      await rc.fetchAndActivate();
    } catch (_) {}
  }

  /// Re-fetches and activates config. Called on foreground resume.
  /// Failure is silent — cached / default values remain in effect.
  static Future<void> refresh() async {
    try {
      await FirebaseRemoteConfig.instance.fetchAndActivate();
    } catch (_) {}
  }
}
