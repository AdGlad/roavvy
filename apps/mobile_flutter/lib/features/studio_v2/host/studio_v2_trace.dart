import 'package:flutter/foundation.dart';

/// Temporary **startup diagnostics** for Studio V2 (M11). Zero-cost unless the
/// build enables it, so it can live in the tree while we hunt the on-device
/// startup runaway (spinning / high CPU / high memory) without touching release
/// behaviour.
///
/// Enable on device:
///   flutter run -t lib/main_studio_v2.dart --dart-define=STUDIO_V2_TRACE=true
/// (or add the same `--dart-define` to the production launch). Every trace line
/// is prefixed `[v2trace]` so it is greppable in the device console; a counter
/// that keeps climbing while the UI is idle is the runaway.
const bool kStudioV2Trace = bool.fromEnvironment('STUDIO_V2_TRACE');

/// Monotonic named counters — call [bump] and the running total prints, so a
/// loop shows up as a number that never stops rising.
final Map<String, int> _counts = {};

void v2trace(String message) {
  if (!kStudioV2Trace) return;
  debugPrint('[v2trace] $message');
}

int v2bump(String name, {String? detail}) {
  if (!kStudioV2Trace) return 0;
  final n = (_counts[name] ?? 0) + 1;
  _counts[name] = n;
  debugPrint('[v2trace] $name #$n${detail == null ? '' : '  $detail'}');
  return n;
}
