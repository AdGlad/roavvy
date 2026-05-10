import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/globe_projection.dart';
import 'travel_replay_engine.dart';

/// Animation phases for a single replay leg.
enum ReplayPhase {
  idle,
  rotating,   // globe rotates to midpoint of leg (600 ms)
  zoomIn,     // globe zooms toward departure (400 ms)
  arc,        // great-circle arc draws + marker travels (variable)
  arrivalZoom,// zoom re-centres on arrival (400 ms)
  pulse,      // arrival country pulses (300 ms)
  hold,       // brief pause before next leg (200 ms)
  done,       // script complete
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

  static const _kRotateDuration = Duration(milliseconds: 600);
  static const _kZoomInDuration = Duration(milliseconds: 400);
  static const _kArrivalZoomDuration = Duration(milliseconds: 400);
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
    _runRotate();
  }

  void _runRotate() {
    final leg = script.legs[currentLegIndex];
    final fromLat = _centroidLat(leg.fromCode);
    final fromLng = _centroidLng(leg.fromCode);
    final toLat = _centroidLat(leg.toCode);
    final toLng = _centroidLng(leg.toCode);

    // Target midpoint of the leg so both countries are visible.
    final midLat = (fromLat + toLat) / 2.0;
    final midLng = _midLng(fromLng, toLng);

    final targetRotLat = midLat;
    final targetRotLng = midLng;

    final startProjection = projection;
    final ctrl = _makeCtrl(_kRotateDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.rotating;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);
    ctrl.addListener(() {
      final t = anim.value;
      final newLng = _lerpAngle(startProjection.rotLng, targetRotLng, t);
      final newLat = _lerp(startProjection.rotLat, targetRotLat, t);
      projection = projection.copyWith(rotLng: newLng, rotLat: newLat);
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runZoomIn();
    });
    ctrl.forward();
  }

  void _runZoomIn() {
    final leg = script.legs[currentLegIndex];
    final fromLat = _centroidLat(leg.fromCode);
    final fromLng = _centroidLng(leg.fromCode);

    final startProjection = projection;
    final ctrl = _makeCtrl(_kZoomInDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.zoomIn;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
    ctrl.addListener(() {
      final t = anim.value;
      projection = projection.copyWith(
        rotLat: _lerp(startProjection.rotLat, fromLat, t),
        rotLng: _lerpAngle(startProjection.rotLng, fromLng, t),
        scale: _lerp(startProjection.scale, 1.8, t),
      );
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runArc();
    });
    ctrl.forward();
  }

  void _runArc() {
    final legCount = script.legs.length;
    final arcMs = TravelReplayScriptBuilder.legDurationMs(legCount);
    final ctrl = _makeCtrl(Duration(milliseconds: arcMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.arc;
    arcProgress = 0.0;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutSine);
    ctrl.addListener(() {
      arcProgress = anim.value;
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runArrivalZoom();
    });
    ctrl.forward();
  }

  void _runArrivalZoom() {
    final leg = script.legs[currentLegIndex];
    final toLat = _centroidLat(leg.toCode);
    final toLng = _centroidLng(leg.toCode);

    final startProjection = projection;
    final ctrl = _makeCtrl(_kArrivalZoomDuration);
    _phaseCtrl = ctrl;
    phase = ReplayPhase.arrivalZoom;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInCubic);
    ctrl.addListener(() {
      final t = anim.value;
      projection = projection.copyWith(
        rotLat: _lerp(startProjection.rotLat, toLat, t),
        rotLng: _lerpAngle(startProjection.rotLng, toLng, t),
        scale: _lerp(startProjection.scale, 2.2, t),
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

  /// Midpoint longitude that avoids the antimeridian jump.
  static double _midLng(double a, double b) {
    var diff = b - a;
    while (diff > math.pi) { diff -= 2 * math.pi; }
    while (diff < -math.pi) { diff += 2 * math.pi; }
    return a + diff / 2.0;
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
