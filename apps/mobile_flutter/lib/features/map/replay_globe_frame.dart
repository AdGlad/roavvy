import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'country_visual_state.dart';
import 'globe_projection.dart';

/// Animation frame snapshot written by [GlobeReplayWidget] (embedded mode) on
/// every controller tick and read by [GlobeMapWidget] to drive the single main
/// globe during replay and scan animations (M134).
///
/// When the provider value is non-null, [GlobeMapWidget] uses this frame's
/// [projection] and [visualStates] instead of its own, paints [afterPainter]
/// on top of the globe sphere, and disables user interaction.
@immutable
class ReplayGlobeFrame {
  const ReplayGlobeFrame({
    required this.projection,
    required this.visualStates,
    this.afterPainter,
    this.highlightedCode,
    this.pulseValue = 0.0,
    this.heritageSiteCoords = const [],
    this.opacity = 1.0,
  });

  final GlobeProjection projection;
  final Map<String, CountryVisualState> visualStates;

  /// Optional painter called after the globe sphere (draws flight arcs, etc.).
  final CustomPainter? afterPainter;

  /// ISO code of the country to render a celebration halo on (or null).
  final String? highlightedCode;

  /// Halo pulse value 0.0–1.0. 0.0 = hidden.
  final double pulseValue;

  /// Heritage site coords to show as amber dots during replay.
  final List<(double, double)> heritageSiteCoords;

  /// Globe opacity — fades to 0.15 when replay completes (summary backdrop).
  final double opacity;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Holds the current [ReplayGlobeFrame] while a replay or scan overlay is
/// active. Null when the main globe is in its normal interactive state.
final replayGlobeFrameProvider = StateProvider<ReplayGlobeFrame?>(
  (ref) => null,
);
