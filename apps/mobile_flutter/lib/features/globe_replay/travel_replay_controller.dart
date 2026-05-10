import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/globe_projection.dart';
import 'travel_replay_engine.dart';

/// Animation phases for a single replay leg.
enum ReplayPhase {
  idle,
  departureSettle, // rotate + zoom in to departure country (700 ms)
  departureHold,   // hold on departure before flight (250 ms)
  flight,          // arc draws while camera pans to arrival with scale dip (variable)
  pulse,           // arrival country pulses (300 ms)
  hold,            // brief pause before next leg (200 ms)
  done,            // script complete
}

/// Drives the cinematic globe replay (M108).
///
/// Call [play()] to start; listen via [ChangeNotifier] to rebuild the
/// [GlobeReplayWidget]. The controller owns [AnimationController]s internally
/// and requires a [TickerProvider] (pass `this` from a [StateMixin] state).
class TravelReplayController extends ChangeNotifier {
  TravelReplayController({
    required this.script,
    required TickerProvider vsync,
  }) : _vsync = vsync;

  final TravelReplayScript script;
  final TickerProvider _vsync;

  // ── Observable state ───────────────────────────────────────────────────────

  int currentLegIndex = 0;
  ReplayPhase phase = ReplayPhase.idle;

  /// Globe projection driven by the controller.
  GlobeProjection projection = const GlobeProjection();

  /// Arc draw progress 0.0–1.0. Used by [GlobeReplayPainter].
  double arcProgress = 0.0;

  /// Arrival pulse radius 0.0–1.0. Used by [GlobeReplayPainter].
  double pulseValue = 0.0;

  bool get isPlaying =>
      phase != ReplayPhase.idle && phase != ReplayPhase.done;

  // ── Future hooks (deferred — video export / audio) ─────────────────────────

  /// Called when a leg starts. Hook for future audio/music cues.
  void Function(int legIndex)? onLegStart;

  /// Called when a leg completes.
  VoidCallback? onLegComplete;

  /// Called when the entire replay completes.
  VoidCallback? onReplayComplete;

  // ── Internal ───────────────────────────────────────────────────────────────

  AnimationController? _phaseCtrl;
  bool _disposed = false;

  static const _kDepartureSettleDuration = Duration(milliseconds: 700);
  static const _kDepartureHoldDuration = Duration(milliseconds: 250);
  static const _kPulseDuration = Duration(milliseconds: 300);
  static const _kHoldDuration = Duration(milliseconds: 200);

  // ── Public API ─────────────────────────────────────────────────────────────

  void play() {
    if (script.isEmpty) return;
    currentLegIndex = 0;
    arcProgress = 0.0;
    pulseValue = 0.0;
    _startLeg();
  }

  void stop() {
    _phaseCtrl?.stop();
    _phaseCtrl?.dispose();
    _phaseCtrl = null;
    phase = ReplayPhase.idle;
    arcProgress = 0.0;
    pulseValue = 0.0;
    if (!_disposed) notifyListeners();
  }

  // ── Phase sequencer ────────────────────────────────────────────────────────

  void _startLeg() {
    if (_disposed) return;
    if (currentLegIndex >= script.legs.length) {
      phase = ReplayPhase.done;
      onReplayComplete?.call();
      notifyListeners();
      return;
    }
    onLegStart?.call(currentLegIndex);
    arcProgress = 0.0;
    pulseValue = 0.0;
    _runDepartureSettle();
  }

  /// Phase 1: rotate directly to departure country and zoom in slightly.
  void _runDepartureSettle() {
    final leg = script.legs[currentLegIndex];
    final fromLat = _centroidLat(leg.fromCode);
    final fromLng = _centroidLng(leg.fromCode);

    final startProjection = projection;
    final ctrl = _makeCtrl(_kDepartureSettleDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.departureSettle;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);
    ctrl.addListener(() {
      final t = anim.value;
      projection = projection.copyWith(
        rotLat: _lerp(startProjection.rotLat, fromLat, t),
        rotLng: _lerpAngle(startProjection.rotLng, fromLng, t),
        scale: _lerp(startProjection.scale, 1.7, t),
      );
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runDepartureHold();
    });
    ctrl.forward();
  }

  /// Phase 2: brief hold on departure before the arc begins.
  void _runDepartureHold() {
    final ctrl = _makeCtrl(_kDepartureHoldDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.departureHold;
    notifyListeners();
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runFlight();
    });
    ctrl.forward();
  }

  /// Phase 3: arc draws while the camera simultaneously pans from departure
  /// to arrival with a gentle scale dip at mid-flight for cinematic depth.
  ///
  /// Scale curve: departs at 1.7×, dips to ~1.3× at mid-arc, arrives at 1.9×.
  /// Camera pan uses easeInOutSine so it starts and ends smoothly.
  void _runFlight() {
    final leg = script.legs[currentLegIndex];
    final fromLat = _centroidLat(leg.fromCode);
    final fromLng = _centroidLng(leg.fromCode);
    final toLat = _centroidLat(leg.toCode);
    final toLng = _centroidLng(leg.toCode);

    final legCount = script.legs.length;
    final flightMs = TravelReplayScriptBuilder.legDurationMs(legCount);
    final ctrl = _makeCtrl(Duration(milliseconds: flightMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.flight;
    arcProgress = 0.0;
    notifyListeners();

    ctrl.addListener(() {
      final rawT = ctrl.value; // linear 0→1
      final smoothT = Curves.easeInOutSine.transform(rawT);

      // Arc drawing follows the smooth curve.
      arcProgress = smoothT;

      // Camera pans smoothly from departure to arrival.
      final newLat = _lerp(fromLat, toLat, smoothT);
      final newLng = _lerpAngle(fromLng, toLng, smoothT);

      // Scale: 1.7 at departure → dip to ~1.3 at mid-arc → 1.9 at arrival.
      // sin(π·rawT) peaks at 0.5 so the dip is centred on the flight.
      final newScale = _lerp(1.7, 1.9, rawT) - 0.5 * math.sin(math.pi * rawT);

      projection = projection.copyWith(
        rotLat: newLat,
        rotLng: newLng,
        scale: newScale,
      );
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runPulse();
    });
    ctrl.forward();
  }

  void _runPulse() {
    final ctrl = _makeCtrl(_kPulseDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.pulse;
    pulseValue = 0.0;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.elasticOut);
    ctrl.addListener(() {
      pulseValue = anim.value.clamp(0.0, 1.0);
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runHold();
    });
    ctrl.forward();
  }

  void _runHold() {
    final ctrl = _makeCtrl(_kHoldDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.hold;
    notifyListeners();

    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _advanceLeg();
    });
    ctrl.forward();
  }

  void _advanceLeg() {
    onLegComplete?.call();
    currentLegIndex++;
    _startLeg();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AnimationController _makeCtrl(Duration duration) {
    _phaseCtrl?.dispose();
    return AnimationController(vsync: _vsync, duration: duration);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Interpolates angles, taking the shortest path.
  static double _lerpAngle(double a, double b, double t) {
    var diff = b - a;
    // Normalise to [-π, π]
    while (diff > math.pi) { diff -= 2 * math.pi; }
    while (diff < -math.pi) { diff += 2 * math.pi; }
    return a + diff * t;
  }

  static double _centroidLat(String code) {
    // Lazy import avoids circular dependency — centroid map lives in map feature.
    final c = _centroids[code];
    return c != null ? c.$1 * math.pi / 180.0 : 0.0;
  }

  static double _centroidLng(String code) {
    final c = _centroids[code];
    return c != null ? -(c.$2 * math.pi / 180.0) : 0.0;
  }

  // Populated by GlobeReplayWidget via [setCentroids].
  static Map<String, (double, double)> _centroids = const {};

  /// Called once by [GlobeReplayWidget] to inject the centroids map.
  static void setCentroids(Map<String, (double, double)> m) {
    _centroids = m;
  }

  @override
  void dispose() {
    _disposed = true;
    _phaseCtrl?.dispose();
    super.dispose();
  }
}
