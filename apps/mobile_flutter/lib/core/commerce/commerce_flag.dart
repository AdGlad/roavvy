import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this binary was built with commerce (t-shirt generation and
/// purchasing) compiled in. ADR-180.
///
/// Off unless the build passes `--dart-define=ROAVVY_COMMERCE=true`. A release
/// build without the define has no commerce, whatever the server says.
const bool kCommerceBuild = bool.fromEnvironment('ROAVVY_COMMERCE');

/// Remote Config key for the commerce kill switch.
const String kCommerceEnabledRemoteKey = 'commerce_enabled';

/// The build capability, as a provider so tests can override it.
final commerceBuildProvider = Provider<bool>((ref) => kCommerceBuild);

/// The Remote Config kill switch. It can only turn commerce OFF: it is ANDed
/// with [commerceBuildProvider] and never read when the build is off.
///
/// When Remote Config is unavailable (dev entrypoints, tests) it falls back to
/// `true`, which keeps the build setting in charge rather than opening
/// anything the build has not.
final commerceRemoteSwitchProvider = Provider<bool>((ref) {
  try {
    return FirebaseRemoteConfig.instance.getBool(kCommerceEnabledRemoteKey);
  } catch (_) {
    return true;
  }
});

/// The single source of truth for whether any commerce is available: shop,
/// cart, orders, t-shirt generation, print CTAs, checkout. ADR-180.
///
/// Every other commerce flag derives from this one and is `false` when it is.
final commerceEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(commerceBuildProvider)) return false;
  return ref.watch(commerceRemoteSwitchProvider);
});
