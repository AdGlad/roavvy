import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/globe_replay/travel_replay_engine.dart';
import '../features/scan/live_scan_replay_data_source.dart';

// ── GlobeOverlayState ─────────────────────────────────────────────────────────

/// Immutable state for the full-screen globe animation overlay.
///
/// When [isActive], [MainShell] renders [GlobeReplayWidget] as a non-navigated
/// overlay covering the entire app — giving the user the experience of scan and
/// replay animations happening directly on the main-screen globe.
@immutable
class GlobeOverlayState {
  const GlobeOverlayState({
    this.scanSource,
    this.replayScript,
    this.initialCollectedCodes = const [],
    this.onScanComplete,
  });

  /// Non-null during live scan animation (full or partial).
  final LiveScanReplayDataSource? scanSource;

  /// Non-null during historical travel replay.
  final TravelReplayScript? replayScript;

  /// Countries already collected before a partial scan begins.
  /// Seeded into the flag collection row so existing flags are visible from the
  /// start of the partial-scan animation.
  final List<String> initialCollectedCodes;

  /// Called when the overlay animation completes (scan done or replay done).
  /// The caller is responsible for any follow-on navigation (e.g. summary screen).
  final VoidCallback? onScanComplete;

  bool get isActive => scanSource != null || replayScript != null;
  bool get isScanMode => scanSource != null;
  bool get isReplayMode => replayScript != null;
}

// ── GlobeOverlayNotifier ──────────────────────────────────────────────────────

class GlobeOverlayNotifier extends StateNotifier<GlobeOverlayState> {
  GlobeOverlayNotifier() : super(const GlobeOverlayState());

  /// Shows the live-scan animation overlay.
  ///
  /// [source] feeds discovery events to the animation.
  /// [initialCollectedCodes] pre-populates the flag row for partial scans.
  /// [onScanComplete] is called when the animation drains and replay finishes.
  void showScan(
    LiveScanReplayDataSource source, {
    List<String> initialCollectedCodes = const [],
    VoidCallback? onScanComplete,
  }) {
    state = GlobeOverlayState(
      scanSource: source,
      initialCollectedCodes: initialCollectedCodes,
      onScanComplete: onScanComplete,
    );
  }

  /// Shows the historical travel replay overlay.
  ///
  /// [onDone] is called when replay completes (phase == done).
  void showReplay(TravelReplayScript script, {VoidCallback? onDone}) {
    state = GlobeOverlayState(replayScript: script, onScanComplete: onDone);
  }

  /// Hides the overlay and resets state.
  void hide() {
    state = const GlobeOverlayState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final globeOverlayProvider =
    StateNotifierProvider<GlobeOverlayNotifier, GlobeOverlayState>(
      (ref) => GlobeOverlayNotifier(),
    );
