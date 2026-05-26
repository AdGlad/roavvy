import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/globe_projection.dart';
import 'replay_audio_controller.dart';
import 'travel_replay_engine.dart';

/// Animation phases for a single replay leg.
enum ReplayPhase {
  idle,
  departureSettle, // rotate + zoom in to departure country
  departureHold,   // hold on departure before flight
  flight,          // arc draws while camera pans to arrival with scale dip (variable)
  pulse,           // arrival country pulses
  hold,            // brief pause before next leg
  flagReveal,      // large emoji flag appears over country + confetti (M133, first visit only)
  flagFlight,      // flag flies down into collection row (M133)
  overlay,         // achievement / stat overlay reveal (M110, 1 600 ms × N events)
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

  // ── Overlay state (M110) ───────────────────────────────────────────────────

  /// Events scheduled to show for the current leg (set before [overlay] phase).
  List<ReplayOverlayEvent> currentOverlayEvents = const [];

  /// Index into [currentOverlayEvents] of the event currently being shown.
  int currentOverlayEventIndex = 0;

  /// 0.0–1.0 progress of the current overlay event animation.
  /// Opacity = sin(π × overlayProgress) — bell-curve fade.
  double overlayProgress = 0.0;

  // ── First-visit discovery (M133) ───────────────────────────────────────────

  /// Progress 0.0–1.0 of the [flagReveal] phase (flag scale-in).
  double flagRevealProgress = 0.0;

  /// Progress 0.0–1.0 of the [flagFlight] phase (flag flies to row).
  double flagFlightProgress = 0.0;

  /// Country codes that have completed their discovery animation and are
  /// committed to the bottom collection row. The flag row only shows these.
  List<String> collectedCodes = const [];

  bool get isPlaying =>
      phase != ReplayPhase.idle && phase != ReplayPhase.done;

  // ── Audio (M111) ───────────────────────────────────────────────────────────

  /// Injected by [GlobeReplayWidget] before [play()] is called (M111).
  ///
  /// When null, all audio is silently skipped. This keeps the controller
  /// working in test and non-audio contexts.
  // ignore: avoid_setters_without_getters
  set audioController(ReplayAudioController? value) => _audioController = value;
  ReplayAudioController? _audioController;

  // ── Pacing & accessibility (M111) ─────────────────────────────────────────

  /// When true (set from [MediaQuery.disableAnimations]), all phase durations
  /// are halved and the scale dip is zeroed.
  bool reducedMotion = false;

  /// Playback speed multiplier. 1.0 = normal, 2.0 = 2× faster, etc.
  ///
  /// Takes effect at the start of the next animation phase; the currently
  /// running phase is not interrupted. Set via the speed selector in
  /// [GlobeReplayWidget].
  double speedMultiplier = 1.0;

  // ── Hooks ──────────────────────────────────────────────────────────────────

  /// Called when a leg starts. Wired to audio in [GlobeReplayWidget] (M111).
  void Function(int legIndex)? onLegStart;

  /// Called when a leg completes.
  VoidCallback? onLegComplete;

  /// Called when the entire replay completes.
  VoidCallback? onReplayComplete;

  // ── Internal ───────────────────────────────────────────────────────────────

  AnimationController? _phaseCtrl;
  bool _disposed = false;

  // Fallback constants used when script.legPacing is empty.
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
    // Seed collection row with the starting country (leg[0].fromCode).
    collectedCodes = script.legs.isNotEmpty ? [script.legs[0].fromCode] : const [];
    _startLeg();
  }

  void stop() {
    _phaseCtrl?.stop();
    _phaseCtrl?.dispose();
    _phaseCtrl = null;
    phase = ReplayPhase.idle;
    arcProgress = 0.0;
    pulseValue = 0.0;
    currentOverlayEvents = const [];
    currentOverlayEventIndex = 0;
    overlayProgress = 0.0;
    flagRevealProgress = 0.0;
    flagFlightProgress = 0.0;
    if (!_disposed) notifyListeners();
  }

  // ── Phase sequencer ────────────────────────────────────────────────────────

  void _startLeg() {
    if (_disposed) return;
    if (currentLegIndex >= script.legs.length) {
      phase = ReplayPhase.done;
      _callAudio('end');
      onReplayComplete?.call();
      notifyListeners();
      return;
    }
    onLegStart?.call(currentLegIndex);
    arcProgress = 0.0;
    pulseValue = 0.0;
    _runDepartureSettle();
  }

  /// Phase 1: rotate directly to departure point and zoom in slightly.
  ///
  /// Uses the leg's actual GPS departure coordinates when available (M109);
  /// falls back to country centroid.
  ///
  /// M111: duration and easing from [LegPacing]. Uses [Curves.easeInOutQuart]
  /// (more weighted than the previous easeInOutCubic) for a weightier camera.
  void _runDepartureSettle() {
    final leg = script.legs[currentLegIndex];
    final pacing = _currentPacing();
    final fromLat = leg.hasFromGps
        ? leg.fromLat! * math.pi / 180.0
        : _centroidLat(leg.fromCode);
    final fromLng = leg.hasFromGps
        ? -(leg.fromLng! * math.pi / 180.0)
        : _centroidLng(leg.fromCode);

    final settleMs =
        reducedMotion ? pacing.departureSettleMs ~/ 2 : pacing.departureSettleMs;
    final startProjection = projection;
    final ctrl = _makeCtrl(Duration(milliseconds: settleMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.departureSettle;
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutQuart);
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
    final pacing = _currentPacing();
    final holdMs =
        reducedMotion ? pacing.departureHoldMs ~/ 2 : pacing.departureHoldMs;
    final ctrl = _makeCtrl(Duration(milliseconds: holdMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.departureHold;
    notifyListeners();
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runFlight();
    });
    ctrl.forward();
  }

  /// Phase 3: arc draws while the camera simultaneously pans from departure
  /// to arrival with a scale dip at mid-flight for cinematic depth.
  ///
  /// M111: camera pan uses [Curves.easeInOutCubic] (stronger than easeInOutSine);
  /// arc draw uses [Curves.easeIn] so the arc launches slowly then accelerates.
  /// Scale dip magnitude is driven by [LegPacing.scaleDipAmount] — longer arcs
  /// zoom out more, creating a greater sense of distance.
  ///
  /// M109: uses leg GPS coordinates when available; falls back to centroids.
  void _runFlight() {
    final leg = script.legs[currentLegIndex];
    final pacing = _currentPacing();
    final fromLat = leg.hasFromGps
        ? leg.fromLat! * math.pi / 180.0
        : _centroidLat(leg.fromCode);
    final fromLng = leg.hasFromGps
        ? -(leg.fromLng! * math.pi / 180.0)
        : _centroidLng(leg.fromCode);
    final toLat = leg.hasToGps
        ? leg.toLat! * math.pi / 180.0
        : _centroidLat(leg.toCode);
    final toLng = leg.hasToGps
        ? -(leg.toLng! * math.pi / 180.0)
        : _centroidLng(leg.toCode);

    final flightMs =
        reducedMotion ? pacing.flightMs ~/ 2 : pacing.flightMs;
    final ctrl = _makeCtrl(Duration(milliseconds: flightMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.flight;
    arcProgress = 0.0;
    // M111: play travel sound appropriate to arc distance.
    _callAudio('travel', pacing: pacing);
    notifyListeners();

    final dipAmount = reducedMotion ? 0.0 : pacing.scaleDipAmount;

    ctrl.addListener(() {
      final rawT = ctrl.value;
      // Camera pan: easeInOutCubic — stronger deceleration at arrival.
      final camT = Curves.easeInOutCubic.transform(rawT);
      // Arc draw: easeIn — starts slow (rocket launch), accelerates mid-flight.
      final arcT = Curves.easeIn.transform(rawT);

      arcProgress = arcT;

      final newLat = _lerp(fromLat, toLat, camT);
      final newLng = _lerpAngle(fromLng, toLng, camT);

      // Scale: 1.7 at departure → dip at mid-arc → peakScale at arrival.
      // Dip magnitude scales with arc distance for a sense of global height.
      final newScale = _lerp(1.7, pacing.peakScale, rawT)
          - dipAmount * math.sin(math.pi * rawT);

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
    final pacing = _currentPacing();
    final pulseMs = reducedMotion ? pacing.pulseMs ~/ 2 : pacing.pulseMs;
    final ctrl = _makeCtrl(Duration(milliseconds: pulseMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.pulse;
    pulseValue = 0.0;
    // M111: arrival chime.
    _callAudio('arrival');
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
    final pacing = _currentPacing();
    final holdMs = reducedMotion ? pacing.holdMs ~/ 2 : pacing.holdMs;
    final ctrl = _makeCtrl(Duration(milliseconds: holdMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.hold;
    notifyListeners();

    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _afterHold();
    });
    ctrl.forward();
  }

  /// After hold: show flag reveal for first visits, then overlays.
  void _afterHold() {
    final leg = script.legs[currentLegIndex];
    if (leg.isFirstVisit) {
      _runFlagReveal();
    } else {
      _proceedToOverlays();
    }
  }

  void _runFlagReveal() {
    if (_disposed) return;
    phase = ReplayPhase.flagReveal;
    flagRevealProgress = 0.0;
    _callAudio('discovery');
    notifyListeners();
    final ctrl = _makeCtrl(const Duration(milliseconds: 1500));
    _phaseCtrl = ctrl;
    ctrl.addListener(() {
      flagRevealProgress = ctrl.value;
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runFlagFlight();
    });
    ctrl.forward();
  }

  void _runFlagFlight() {
    if (_disposed) return;
    phase = ReplayPhase.flagFlight;
    flagFlightProgress = 0.0;
    _callAudio('collection');
    notifyListeners();
    final ctrl = _makeCtrl(const Duration(milliseconds: 1000));
    _phaseCtrl = ctrl;
    ctrl.addListener(() {
      flagFlightProgress = ctrl.value;
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        final toCode = script.legs[currentLegIndex].toCode;
        if (!collectedCodes.contains(toCode)) {
          collectedCodes = [...collectedCodes, toCode];
        }
        _proceedToOverlays();
      }
    });
    ctrl.forward();
  }

  /// Run overlay events for this leg (if any), then advance to the next leg.
  void _proceedToOverlays() {
    final events = script.overlayEvents[currentLegIndex] ?? const [];
    if (events.isEmpty) {
      _advanceLeg();
    } else {
      currentOverlayEvents = events;
      currentOverlayEventIndex = 0;
      overlayProgress = 0.0;
      _runOverlay();
    }
  }

  /// Shows one overlay event (1 600 ms: 400 fade-in + 800 hold + 400 fade-out).
  /// Opacity = sin(π × overlayProgress) peaks at 0.5.
  void _runOverlay() {
    if (_disposed) return;
    final ctrl = _makeCtrl(const Duration(milliseconds: 1600));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.overlay;
    overlayProgress = 0.0;
    // M111: achievement swell for achievement events; stat events are silent.
    if (currentOverlayEventIndex == 0 ||
        currentOverlayEventIndex < currentOverlayEvents.length) {
      final evt = currentOverlayEvents[currentOverlayEventIndex];
      if (evt is ReplayAchievementEvent) _callAudio('achievement');
    }
    notifyListeners();

    ctrl.addListener(() {
      overlayProgress = ctrl.value;
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      currentOverlayEventIndex++;
      if (currentOverlayEventIndex < currentOverlayEvents.length) {
        _runOverlay();
      } else {
        currentOverlayEvents = const [];
        currentOverlayEventIndex = 0;
        overlayProgress = 0.0;
        _advanceLeg();
      }
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
    final ms = speedMultiplier <= 1.0
        ? duration.inMilliseconds
        : (duration.inMilliseconds / speedMultiplier).round().clamp(30, duration.inMilliseconds);
    return AnimationController(vsync: _vsync, duration: Duration(milliseconds: ms));
  }

  /// Dispatches audio cue [kind] to [_audioController].
  ///
  /// [kind] is one of: 'travel', 'arrival', 'achievement', 'end'.
  /// Falls back silently when [_audioController] is null.
  void _callAudio(String kind, {LegPacing? pacing}) {
    final ac = _audioController;
    if (ac == null) return;
    switch (kind) {
      case 'travel':
        final dist = pacing != null
            ? ReplayPacingRules.legArcDistance(script.legs[currentLegIndex])
            : 45.0;
        ac.playTravelMovement(dist);
      case 'arrival':
        ac.playArrival();
      case 'achievement':
        ac.playAchievement();
      case 'discovery':
        ac.playDiscovery();
      case 'collection':
        ac.playCollection();
      case 'end':
        ac.playReplayEnd();
    }
  }

  /// Returns the [LegPacing] for the current leg, or a fallback derived from
  /// the fixed constants when [script.legPacing] is empty (e.g. in tests or
  /// when the script was built without calling [ReplayPacingRules]).
  LegPacing _currentPacing() {
    final pacing = script.legPacing;
    if (pacing.isNotEmpty && currentLegIndex < pacing.length) {
      return pacing[currentLegIndex];
    }
    // Fallback to fixed constants for backward compatibility.
    return LegPacing(
      departureSettleMs: _kDepartureSettleDuration.inMilliseconds,
      departureHoldMs: _kDepartureHoldDuration.inMilliseconds,
      flightMs: TravelReplayScriptBuilder.legDurationMs(script.legs.length),
      pulseMs: _kPulseDuration.inMilliseconds,
      holdMs: _kHoldDuration.inMilliseconds,
      peakScale: 1.9,
      scaleDipAmount: 0.5,
    );
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
