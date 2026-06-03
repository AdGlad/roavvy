import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/globe_projection.dart';
import 'replay_audio_controller.dart';
import 'replay_data_source.dart';
import 'travel_replay_engine.dart';
import 'travel_replay_controller.dart';

// ── LiveScanReplayState ───────────────────────────────────────────────────────

/// Macro state of the live scan replay controller.
enum LiveScanReplayState {
  /// Not yet started.
  idle,

  /// Animating a leg (departureSettle → flight → pulse → hold → overlays).
  presentingLeg,

  /// Between legs; scan is still running; waiting for the next event.
  waitingForEvents,

  /// Queue empty + scan complete. [onComplete] has been called.
  completed,
}

// ── LiveScanReplayController ──────────────────────────────────────────────────

/// Drives the live-scan cinematic globe animation.
///
/// Mirrors [TravelReplayController]'s 7 animation phases but consumes events
/// from a [ReplayDataSource] rather than a static [TravelReplayScript].
/// Handles [waitingForEvents] pauses when the scan is ahead of discoveries,
/// and year transition banners via [YearStartedEvent].
///
/// Exposes the same observable surface as [TravelReplayController] so that
/// [GlobeReplayWidget] can use either controller transparently via getter shims.
class LiveScanReplayController extends ChangeNotifier {
  LiveScanReplayController({
    required this.dataSource,
    required TickerProvider vsync,
    List<String> initialCollectedCodes = const [],
  }) : _vsync = vsync {
    if (initialCollectedCodes.isNotEmpty) {
      collectedCodes = List.unmodifiable(initialCollectedCodes);
    }
    dataSource.addListener(_onDataSourceUpdate);
  }

  final ReplayDataSource dataSource;
  final TickerProvider _vsync;

  // ── Observable state (same surface as TravelReplayController) ─────────────

  LiveScanReplayState liveState = LiveScanReplayState.idle;

  /// Mirrors [TravelReplayController.phase] — used by GlobeReplayWidget.
  ReplayPhase phase = ReplayPhase.idle;

  GlobeProjection projection = const GlobeProjection();
  double arcProgress = 0.0;
  double pulseValue = 0.0;
  int currentLegIndex = 0;
  List<ReplayOverlayEvent> currentOverlayEvents = const [];
  int currentOverlayEventIndex = 0;
  double overlayProgress = 0.0;
  bool reducedMotion = false;
  double speedMultiplier = 1.0;

  // ── First-visit discovery (M133) ───────────────────────────────────────────
  double flagRevealProgress = 0.0;
  double flagFlightProgress = 0.0;

  /// Countries committed to the bottom collection row after fly-in animation.
  List<String> collectedCodes = const [];

  // ── Live-only observable state ─────────────────────────────────────────────

  /// Last processed photo count from [ScanProgressUpdatedEvent].
  int processedCount = 0;

  /// Approximate number of [CountryDiscoveredEvent]s waiting in the queue.
  int get queuedLegCount => _pendingLegCount;

  /// Year currently shown on the year-banner overlay (null when not showing).
  int? activeYearBanner;

  // ── Internal ───────────────────────────────────────────────────────────────

  TravelLeg? _activeLeg;
  final List<TravelLeg> _completedLegs = [];
  List<ReplayOverlayEvent> _pendingOverlayEvents = [];
  int _pendingLegCount = 0;
  bool _scanComplete = false;
  bool _disposed = false;

  // ignore: avoid_setters_without_getters
  set audioController(ReplayAudioController? value) => _audioController = value;
  ReplayAudioController? _audioController;

  VoidCallback? onComplete;

  AnimationController? _phaseCtrl;

  // ── Pacing constants (fallback when leg distance unknown) ──────────────────
  static const _kDepartureSettleMs = 700;
  static const _kDepartureHoldMs = 250;
  static const _kPulseMs = 300;
  static const _kHoldMs = 200;
  static const _kYearBannerMs = 1500;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Completed legs — used by [GlobeReplayWidget] to build the visual trail
  /// and visual state map.
  List<TravelLeg> get completedLegs => List.unmodifiable(_completedLegs);

  /// Currently animating leg (null if waiting or done).
  TravelLeg? get activeLeg => _activeLeg;

  /// Visited heritage site coords accumulated from [HeritageSiteDiscoveredEvent]s.
  final List<(double, double)> visitedHeritageSiteCoords = [];

  void start() {
    liveState = LiveScanReplayState.presentingLeg;
    _processNextEvent();
  }

  void stop() {
    _phaseCtrl?.stop();
    _phaseCtrl?.dispose();
    _phaseCtrl = null;
    phase = ReplayPhase.idle;
    liveState = LiveScanReplayState.idle;
    flagRevealProgress = 0.0;
    flagFlightProgress = 0.0;
    if (!_disposed) notifyListeners();
  }

  // ── Event loop ─────────────────────────────────────────────────────────────

  void _onDataSourceUpdate() {
    if (liveState == LiveScanReplayState.waitingForEvents) {
      _processNextEvent();
    }
  }

  void _processNextEvent() {
    if (_disposed) return;

    final event = dataSource.dequeue();

    if (event == null) {
      if (dataSource.isExhausted || _scanComplete) {
        _complete();
      } else {
        _enterWaiting();
      }
      return;
    }

    switch (event) {
      case YearStartedEvent e:
        _showYearBanner(e.year);
      case CountryDiscoveredEvent e:
        _pendingLegCount = (_pendingLegCount - 1).clamp(0, 9999);
        _runLeg(
          TravelLeg(
            fromCode: e.fromCode,
            toCode: e.toCode,
            date: e.date,
            fromLat: e.fromLat,
            fromLng: e.fromLng,
            toLat: e.toLat,
            toLng: e.toLng,
            isFirstVisit: e.isFirstVisit,
          ),
        );
      case HeritageSiteDiscoveredEvent e:
        _pendingOverlayEvents.add(
          ReplayHeritageEvent(siteName: e.siteName, siteType: e.siteType),
        );
        // Accumulate heritage dot on globe.
        // Coords unknown at this point; omit from visitedHeritageSiteCoords
        // (they are only available when site lat/lng is forwarded from scan).
        _processNextEvent(); // consume until next CountryDiscovered
      case AchievementUnlockedEvent e:
        _pendingOverlayEvents.add(
          ReplayAchievementEvent(
            achievementId: e.achievementId,
            title: e.title,
            subtitle: e.subtitle,
          ),
        );
        _processNextEvent();
      case ScanProgressUpdatedEvent e:
        processedCount = e.processedCount;
        notifyListeners();
        _processNextEvent();
      case ScanCompletedEvent _:
        _scanComplete = true;
        _processNextEvent(); // drain remaining events
    }
  }

  // ── Year banner ────────────────────────────────────────────────────────────

  void _showYearBanner(int year) {
    activeYearBanner = year;
    _audioController?.playYearTransition();
    liveState = LiveScanReplayState.presentingLeg;
    phase = ReplayPhase.hold; // reuse hold phase visuals for year banner
    notifyListeners();

    final ctrl = _makeCtrl(const Duration(milliseconds: _kYearBannerMs));
    _phaseCtrl = ctrl;
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        activeYearBanner = null;
        _processNextEvent();
      }
    });
    ctrl.forward();
  }

  // ── Leg animation phases (mirror TravelReplayController) ──────────────────

  void _runLeg(TravelLeg leg) {
    // Archive previous active leg to completed list.
    final prev = _activeLeg;
    if (prev != null) _completedLegs.add(prev);
    _activeLeg = leg;

    // Ensure the origin country is always in the collection row.
    if (!collectedCodes.contains(leg.fromCode)) {
      collectedCodes = [...collectedCodes, leg.fromCode];
    }

    // Drain pending overlay events accumulated before this leg.
    final overlays = List<ReplayOverlayEvent>.from(_pendingOverlayEvents);
    _pendingOverlayEvents = [];

    arcProgress = 0.0;
    pulseValue = 0.0;
    liveState = LiveScanReplayState.presentingLeg;
    _runDepartureSettle(leg, overlays);
  }

  void _runDepartureSettle(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    final pacing = _pacingFor(leg);
    final fromLat =
        leg.hasFromGps
            ? leg.fromLat! * math.pi / 180.0
            : _centroidLat(leg.fromCode);
    final fromLng =
        leg.hasFromGps
            ? -(leg.fromLng! * math.pi / 180.0)
            : _centroidLng(leg.fromCode);

    final settleMs =
        reducedMotion
            ? pacing.departureSettleMs ~/ 2
            : pacing.departureSettleMs;
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
      if (s == AnimationStatus.completed) _runDepartureHold(leg, overlays);
    });
    ctrl.forward();
  }

  void _runDepartureHold(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    final pacing = _pacingFor(leg);
    final holdMs =
        reducedMotion ? pacing.departureHoldMs ~/ 2 : pacing.departureHoldMs;
    final ctrl = _makeCtrl(Duration(milliseconds: holdMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.departureHold;
    notifyListeners();
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runFlight(leg, overlays);
    });
    ctrl.forward();
  }

  void _runFlight(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    final pacing = _pacingFor(leg);
    final fromLat =
        leg.hasFromGps
            ? leg.fromLat! * math.pi / 180.0
            : _centroidLat(leg.fromCode);
    final fromLng =
        leg.hasFromGps
            ? -(leg.fromLng! * math.pi / 180.0)
            : _centroidLng(leg.fromCode);
    final toLat =
        leg.hasToGps ? leg.toLat! * math.pi / 180.0 : _centroidLat(leg.toCode);
    final toLng =
        leg.hasToGps
            ? -(leg.toLng! * math.pi / 180.0)
            : _centroidLng(leg.toCode);

    final flightMs = reducedMotion ? pacing.flightMs ~/ 2 : pacing.flightMs;
    final ctrl = _makeCtrl(Duration(milliseconds: flightMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.flight;
    arcProgress = 0.0;
    _callAudio('travel', leg: leg);
    notifyListeners();

    final dipAmount = reducedMotion ? 0.0 : pacing.scaleDipAmount;

    ctrl.addListener(() {
      final rawT = ctrl.value;
      final camT = Curves.easeInOutCubic.transform(rawT);
      final arcT = Curves.easeIn.transform(rawT);

      arcProgress = arcT;

      final newLat = _lerp(fromLat, toLat, camT);
      final newLng = _lerpAngle(fromLng, toLng, camT);
      final newScale =
          _lerp(1.7, pacing.peakScale, rawT) -
          dipAmount * math.sin(math.pi * rawT);

      projection = projection.copyWith(
        rotLat: newLat,
        rotLng: newLng,
        scale: newScale,
      );
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runPulse(leg, overlays);
    });
    ctrl.forward();
  }

  void _runPulse(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    final pacing = _pacingFor(leg);
    final pulseMs = reducedMotion ? pacing.pulseMs ~/ 2 : pacing.pulseMs;
    final ctrl = _makeCtrl(Duration(milliseconds: pulseMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.pulse;
    pulseValue = 0.0;
    _callAudio('arrival');
    notifyListeners();

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.elasticOut);
    ctrl.addListener(() {
      pulseValue = anim.value.clamp(0.0, 1.0);
      if (!_disposed) notifyListeners();
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _runHold(leg, overlays);
    });
    ctrl.forward();
  }

  void _runHold(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    final pacing = _pacingFor(leg);
    final holdMs = reducedMotion ? pacing.holdMs ~/ 2 : pacing.holdMs;
    final ctrl = _makeCtrl(Duration(milliseconds: holdMs));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.hold;
    notifyListeners();

    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _afterHold(overlays);
    });
    ctrl.forward();
  }

  void _afterHold(List<ReplayOverlayEvent> overlays) {
    if (_activeLeg?.isFirstVisit == true) {
      _runFlagReveal(overlays);
    } else {
      _proceedToOverlays(overlays);
    }
  }

  void _runFlagReveal(List<ReplayOverlayEvent> overlays) {
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
      if (s == AnimationStatus.completed) _runFlagFlight(overlays);
    });
    ctrl.forward();
  }

  void _runFlagFlight(List<ReplayOverlayEvent> overlays) {
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
        final toCode = _activeLeg?.toCode;
        if (toCode != null && !collectedCodes.contains(toCode)) {
          collectedCodes = [...collectedCodes, toCode];
        }
        notifyListeners();
        _proceedToOverlays(overlays);
      }
    });
    ctrl.forward();
  }

  void _proceedToOverlays(List<ReplayOverlayEvent> overlays) {
    if (overlays.isEmpty) {
      currentLegIndex++;
      _processNextEvent();
    } else {
      currentOverlayEvents = overlays;
      currentOverlayEventIndex = 0;
      overlayProgress = 0.0;
      _runOverlay();
    }
  }

  void _runOverlay() {
    if (_disposed) return;
    final ctrl = _makeCtrl(const Duration(milliseconds: 1600));
    _phaseCtrl = ctrl;
    phase = ReplayPhase.overlay;
    overlayProgress = 0.0;
    final evt = currentOverlayEvents[currentOverlayEventIndex];
    if (evt is ReplayAchievementEvent) _callAudio('achievement');
    if (evt is ReplayHeritageEvent) _callAudio('heritage');
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
        currentLegIndex++;
        _processNextEvent();
      }
    });
    ctrl.forward();
  }

  // ── Waiting state ──────────────────────────────────────────────────────────

  void _enterWaiting() {
    liveState = LiveScanReplayState.waitingForEvents;
    phase = ReplayPhase.idle;
    notifyListeners();
    // _onDataSourceUpdate will call _processNextEvent() when events arrive.
  }

  // ── Completion ─────────────────────────────────────────────────────────────

  void _complete() {
    liveState = LiveScanReplayState.completed;
    phase = ReplayPhase.done;
    _callAudio('end');
    notifyListeners();
    onComplete?.call();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  LegPacing _pacingFor(TravelLeg leg) {
    final dist = ReplayPacingRules.legArcDistance(leg);
    return LegPacing(
      departureSettleMs: _kDepartureSettleMs,
      departureHoldMs: _kDepartureHoldMs,
      flightMs: TravelReplayScriptBuilder.legDurationMs(
        (currentLegIndex + 1).clamp(1, 100),
      ),
      pulseMs: _kPulseMs,
      holdMs: _kHoldMs,
      peakScale: ReplayPacingRules.peakScaleForArc(dist),
      scaleDipAmount: ReplayPacingRules.scaleDipForArc(dist),
    );
  }

  AnimationController _makeCtrl(Duration duration) {
    _phaseCtrl?.dispose();
    final ms =
        speedMultiplier <= 1.0
            ? duration.inMilliseconds
            : (duration.inMilliseconds / speedMultiplier).round().clamp(
              30,
              duration.inMilliseconds,
            );
    return AnimationController(
      vsync: _vsync,
      duration: Duration(milliseconds: ms),
    );
  }

  void _callAudio(String kind, {TravelLeg? leg}) {
    final ac = _audioController;
    if (ac == null) return;
    switch (kind) {
      case 'travel':
        final dist = leg != null ? ReplayPacingRules.legArcDistance(leg) : 45.0;
        ac.playTravelMovement(dist);
      case 'arrival':
        ac.playArrival();
      case 'achievement':
        ac.playAchievement();
      case 'heritage':
        ac.playHeritage();
      case 'discovery':
        ac.playDiscovery();
      case 'collection':
        ac.playCollection();
      case 'end':
        ac.playScanComplete();
    }
  }

  static Map<String, (double, double)> _centroids = const {};

  /// Called once by [GlobeReplayWidget] to inject the centroids map.
  static void setCentroids(Map<String, (double, double)> m) {
    _centroids = m;
  }

  static double _centroidLat(String code) {
    final c = _centroids[code];
    return c != null ? c.$1 * math.pi / 180.0 : 0.0;
  }

  static double _centroidLng(String code) {
    final c = _centroids[code];
    return c != null ? -(c.$2 * math.pi / 180.0) : 0.0;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _lerpAngle(double a, double b, double t) {
    var diff = b - a;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    return a + diff * t;
  }

  @override
  void dispose() {
    _disposed = true;
    dataSource.removeListener(_onDataSourceUpdate);
    _phaseCtrl?.dispose();
    super.dispose();
  }
}
