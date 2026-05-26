# M132 — Live Scan Replay

**Status:** Complete (2026-05-26)
**Branch:** `milestone/m132-live-scan-replay`
**Phase:** 25 — Scan UX Transformation
**Depends on:** M131 ✅

---

## Goal

Replace M131's post-scan cinematic (scan finishes → build script → push replay) with a **fully live replay** — `GlobeReplayWidget` opens the instant scanning begins, receives country/heritage/achievement events in real time as the scan engine finds them, queues and presents each event through the same cinematic sequence used by historical replay, and transitions to `ScanSummaryScreen` when both the scan is complete and the queue is drained.

The existing historical replay (launched from the map) must continue working unchanged, using the same UI.

---

## Context

M131 gave us a working post-scan cinematic using `GlobeReplayWidget` driven by a `TravelReplayScript` built from `inferredTrips`. The limitation: the user watches a plain scanning screen during the entire scan, then sees a replay of their full history — not their new discoveries. M132 makes the replay the scanning UI itself, so the user watches their new discoveries appear one by one in real time.

---

## Architecture Overview

```
Historical replay (unchanged):
  GlobeReplayWidget(script: TravelReplayScript)
    └── TravelReplayController (unchanged)

Live scan replay (new):
  GlobeReplayWidget(dataSource: LiveScanReplayDataSource)
    └── LiveScanReplayController
          └── reads from LiveScanReplayDataSource
                └── fed by _ScanScreenState per batch
```

Two new abstractions are introduced:
1. **`ReplayDataSource`** — abstract interface consumed by `LiveScanReplayController`
2. **`LiveScanReplayDataSource`** — concrete implementation fed by the scan engine

`TravelReplayController` and `TravelReplayScript` are **not modified**.
`GlobeReplayWidget` gains a `dataSource` parameter as an alternative to `script`.

---

## New Files

### `lib/features/globe_replay/replay_data_source.dart`

Contains the sealed event hierarchy, abstract data source interface, and `HistoricalReplayDataSource`.

```dart
// ── ReplayEvent sealed hierarchy ──────────────────────────────────────────────

sealed class ReplayEvent { const ReplayEvent(); }

/// Emitted when the scan (or historical script) crosses a calendar year
/// boundary. The controller shows a year banner overlay before the next leg.
class YearStartedEvent extends ReplayEvent {
  const YearStartedEvent({required this.year});
  final int year;
}

/// A country-to-country transition — maps directly to a [TravelLeg].
class CountryDiscoveredEvent extends ReplayEvent {
  const CountryDiscoveredEvent({
    required this.fromCode,
    required this.toCode,
    required this.date,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });
  final String fromCode;
  final String toCode;
  final DateTime date;
  final double? fromLat, fromLng, toLat, toLng;
}

/// A UNESCO heritage site discovered in the currently active country.
/// Queued as an overlay event for the active or next [CountryDiscoveredEvent].
class HeritageSiteDiscoveredEvent extends ReplayEvent {
  const HeritageSiteDiscoveredEvent({
    required this.countryCode,
    required this.siteName,
    required this.siteType, // 'cultural' | 'natural' | 'mixed' | null
  });
  final String countryCode;
  final String siteName;
  final String? siteType;
}

/// An achievement unlocked during the active or next [CountryDiscoveredEvent].
class AchievementUnlockedEvent extends ReplayEvent {
  const AchievementUnlockedEvent({
    required this.achievementId,
    required this.title,
    required this.subtitle,
    this.countryCode, // null = global, attach to next leg
  });
  final String achievementId;
  final String title;
  final String subtitle;
  final String? countryCode;
}

/// Scan engine progress update — used to drive the "Scanning live…" indicator.
class ScanProgressUpdatedEvent extends ReplayEvent {
  const ScanProgressUpdatedEvent({required this.processedCount});
  final int processedCount;
}

/// Signals the scan engine has finished. After this arrives and the queue
/// drains, [LiveScanReplayController] transitions to [LiveScanReplayState.completed].
class ScanCompletedEvent extends ReplayEvent {
  const ScanCompletedEvent();
}

// ── ReplayDataSource interface ─────────────────────────────────────────────────

/// Abstract data source consumed by [LiveScanReplayController].
///
/// Implementations notify listeners when new events become available so
/// the controller can resume after a [waitingForEvents] pause.
abstract interface class ReplayDataSource implements Listenable {
  /// True if at least one event is ready to dequeue.
  bool get hasNextEvent;

  /// True when no further events will ever arrive (scan complete + queue empty,
  /// or historical script fully consumed).
  bool get isExhausted;

  /// Returns and removes the next event. Returns null if [hasNextEvent] is false.
  ReplayEvent? dequeue();
}

// ── HistoricalReplayDataSource ─────────────────────────────────────────────────

/// Wraps a pre-built [TravelReplayScript] as a [ReplayDataSource].
///
/// Converts legs to [CountryDiscoveredEvent]s and per-leg overlay events
/// to [HeritageSiteDiscoveredEvent] / [AchievementUnlockedEvent], inserting
/// a [YearStartedEvent] whenever the leg year changes.
///
/// [isExhausted] becomes true as soon as all events have been dequeued.
class HistoricalReplayDataSource extends ChangeNotifier
    implements ReplayDataSource {
  HistoricalReplayDataSource(TravelReplayScript script) {
    _buildQueue(script);
  }

  final Queue<ReplayEvent> _queue = Queue();

  void _buildQueue(TravelReplayScript script) {
    int? lastYear;
    for (var i = 0; i < script.legs.length; i++) {
      final leg = script.legs[i];
      // Year banner before first leg of each new calendar year.
      if (lastYear == null || leg.date.year != lastYear) {
        _queue.add(YearStartedEvent(year: leg.date.year));
        lastYear = leg.date.year;
      }
      _queue.add(CountryDiscoveredEvent(
        fromCode: leg.fromCode,
        toCode: leg.toCode,
        date: leg.date,
        fromLat: leg.fromLat,
        fromLng: leg.fromLng,
        toLat: leg.toLat,
        toLng: leg.toLng,
      ));
      // Per-leg overlay events (heritage, achievements, stats).
      for (final oe in script.overlayEvents[i] ?? const []) {
        switch (oe) {
          case ReplayHeritageEvent e:
            _queue.add(HeritageSiteDiscoveredEvent(
              countryCode: leg.toCode,
              siteName: e.siteName,
              siteType: e.siteType,
            ));
          case ReplayAchievementEvent e:
            _queue.add(AchievementUnlockedEvent(
              achievementId: e.achievementId,
              title: e.title,
              subtitle: e.subtitle,
              countryCode: leg.toCode,
            ));
          case ReplayStatEvent _:
            break; // stat events not surfaced through this interface
        }
      }
    }
  }

  @override bool get hasNextEvent => _queue.isNotEmpty;
  @override bool get isExhausted => _queue.isEmpty;

  @override
  ReplayEvent? dequeue() {
    if (_queue.isEmpty) return null;
    final ev = _queue.removeFirst();
    if (_queue.isEmpty) notifyListeners(); // signal exhaustion
    return ev;
  }
}
```

---

### `lib/features/scan/live_scan_replay_data_source.dart`

```dart
/// Live data source fed by [_ScanScreenState] during an active photo scan.
///
/// The scan engine calls [addEvent] after each batch. Events are buffered in
/// [_queue] and sorted by [CountryDiscoveredEvent.date] before being consumed
/// so that out-of-order batch arrivals are replayed chronologically.
///
/// [markScanComplete] appends [ScanCompletedEvent] and notifies listeners.
/// After that point no further events can be added.
class LiveScanReplayDataSource extends ChangeNotifier
    implements ReplayDataSource {
  final Queue<ReplayEvent> _queue = Queue();
  bool _scanComplete = false;

  // Pending overlay events (heritage, achievements) not yet attached to a leg.
  // Keyed by countryCode; flushed as overlay events for the next leg with
  // a matching toCode.
  final Map<String, List<ReplayEvent>> _pendingOverlays = {};

  /// Called by [_ScanScreenState] after each batch.
  ///
  /// [CountryDiscoveredEvent]s are inserted in date order (chronological).
  /// Overlay events are queued immediately after the matching country event.
  void addEvent(ReplayEvent event) {
    assert(!_scanComplete, 'addEvent called after markScanComplete');
    if (event is CountryDiscoveredEvent) {
      // Insert in date order — find first event after this date.
      final insertIdx = _insertionIndexFor(event.date);
      _queue.toList() // rebuild with insertion
        ..insert(insertIdx, event);
      // Re-queue pending overlays for this country immediately after the leg.
      final overlays = _pendingOverlays.remove(event.toCode) ?? [];
      for (final o in overlays.reversed) {
        _queue.toList()..insert(insertIdx + 1, o);
      }
    } else if (event is HeritageSiteDiscoveredEvent) {
      _pendingOverlays
          .putIfAbsent(event.countryCode, () => [])
          .add(event);
    } else if (event is AchievementUnlockedEvent) {
      final code = event.countryCode;
      if (code != null) {
        _pendingOverlays.putIfAbsent(code, () => []).add(event);
      } else {
        _queue.addLast(event); // global: show after current leg
      }
    } else if (event is YearStartedEvent) {
      _insertYearBannerFor(event);
    } else if (event is ScanProgressUpdatedEvent) {
      _queue.addLast(event);
    }
    notifyListeners();
  }

  /// Signals scan completion. Flushes any remaining pending overlays then
  /// appends [ScanCompletedEvent]. No further [addEvent] calls after this.
  void markScanComplete() {
    _scanComplete = true;
    // Flush any pending overlays not yet matched to a leg.
    for (final overlays in _pendingOverlays.values) {
      _queue.addAll(overlays);
    }
    _pendingOverlays.clear();
    _queue.addLast(const ScanCompletedEvent());
    notifyListeners();
  }

  @override bool get hasNextEvent => _queue.isNotEmpty;
  @override bool get isExhausted =>
      _queue.isEmpty && _scanComplete;

  @override
  ReplayEvent? dequeue() {
    if (_queue.isEmpty) return null;
    final ev = _queue.removeFirst();
    notifyListeners();
    return ev;
  }

  int _insertionIndexFor(DateTime date) { /* ... */ }
  void _insertYearBannerFor(YearStartedEvent event) { /* ... */ }
}
```

---

### `lib/features/globe_replay/live_scan_replay_controller.dart`

```dart
/// Live scan replay state — what the controller is doing at the macro level.
enum LiveScanReplayState {
  /// Not yet started.
  idle,

  /// Animating a leg (departureSettle → flight → pulse → hold → overlays).
  presentingLeg,

  /// Between legs; scan is still running; waiting for the next event.
  waitingForEvents,

  /// All legs presented; scan complete; queue draining overlay events.
  queueDraining,

  /// Queue empty + scan complete. [onComplete] has been called.
  completed,
}

/// Drives the live-scan cinematic globe animation.
///
/// Mirrors [TravelReplayController]'s 7 animation phases but consumes events
/// from a [ReplayDataSource] rather than a static [TravelReplayScript].
/// Handles [waitingForEvents] pauses when the scan is ahead of discoveries,
/// and year transition banners via [YearStartedEvent].
///
/// Exposes the same observable surface as [TravelReplayController] so that
/// [GlobeReplayWidget] can use either controller transparently.
class LiveScanReplayController extends ChangeNotifier {
  LiveScanReplayController({
    required this.dataSource,
    required TickerProvider vsync,
  }) : _vsync = vsync {
    dataSource.addListener(_onDataSourceUpdate);
  }

  final ReplayDataSource dataSource;
  final TickerProvider _vsync;

  // ── Observable state (same surface as TravelReplayController) ─────────────

  LiveScanReplayState liveState = LiveScanReplayState.idle;

  /// Mirrors [TravelReplayController.phase] — used by GlobeReplayWidget build.
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

  // ── Live-only state ────────────────────────────────────────────────────────

  /// Last processed photo count from [ScanProgressUpdatedEvent].
  int processedCount = 0;

  /// Approximate number of [CountryDiscoveredEvent]s waiting in the queue.
  int get queuedLegCount =>
      _pendingLegCount; // tracked separately for O(1) access

  /// ISO code of the year-transition year currently on screen (or null).
  int? activeYearBanner;

  // ── Live-only state ────────────────────────────────────────────────────────

  // Tracks current leg being animated.
  TravelLeg? _activeLeg;
  List<ReplayOverlayEvent> _pendingOverlayEvents = [];
  int _pendingLegCount = 0;
  bool _scanComplete = false;
  bool _disposed = false;

  set audioController(ReplayAudioController? value) =>
      _audioController = value;
  ReplayAudioController? _audioController;

  VoidCallback? onComplete;

  AnimationController? _phaseCtrl;

  // ── Fallback pacing constants ──────────────────────────────────────────────
  static const _kDepartureSettleMs = 700;
  static const _kDepartureHoldMs = 250;
  static const _kPulseMs = 300;
  static const _kHoldMs = 200;
  static const _kYearBannerMs = 1500;
  static const _kWaitPollMs = 300; // how often to re-check queue when waiting

  // ── Public API ─────────────────────────────────────────────────────────────

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
    if (!_disposed) notifyListeners();
  }

  // ── Event loop ─────────────────────────────────────────────────────────────

  /// Called when [dataSource] notifies (new events available).
  void _onDataSourceUpdate() {
    if (liveState == LiveScanReplayState.waitingForEvents) {
      _processNextEvent();
    }
  }

  /// Dequeues and dispatches the next event.
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
        _pendingLegCount = (_pendingLegCount - 1).clamp(0, 999);
        _runLeg(TravelLeg(
          fromCode: e.fromCode, toCode: e.toCode, date: e.date,
          fromLat: e.fromLat, fromLng: e.fromLng,
          toLat: e.toLat, toLng: e.toLng,
        ), overlays: []);
      case HeritageSiteDiscoveredEvent e:
        _pendingOverlayEvents.add(ReplayHeritageEvent(
            siteName: e.siteName, siteType: e.siteType));
        _processNextEvent(); // consume until next CountryDiscovered
      case AchievementUnlockedEvent e:
        _pendingOverlayEvents.add(ReplayAchievementEvent(
            achievementId: e.achievementId,
            title: e.title,
            subtitle: e.subtitle));
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
    phase = ReplayPhase.hold; // reuse hold phase for year banner
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
  // NOTE: These methods duplicate TravelReplayController's phase logic.
  // In a future refactor, extract to a shared ReplayPhaseRunner mixin.

  void _runLeg(TravelLeg leg, {required List<ReplayOverlayEvent> overlays}) {
    _activeLeg = leg;
    // Drain any pending overlay events accumulated before this leg.
    final allOverlays = [..._pendingOverlayEvents, ...overlays];
    _pendingOverlayEvents = [];
    arcProgress = 0.0;
    pulseValue = 0.0;
    liveState = LiveScanReplayState.presentingLeg;
    _runDepartureSettle(leg, allOverlays);
  }

  void _runDepartureSettle(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    // Identical to TravelReplayController._runDepartureSettle but reads
    // from local _activeLeg instead of script.legs[currentLegIndex].
    phase = ReplayPhase.departureSettle;
    // ... [same animation logic as TravelReplayController] ...
    // On complete → _runDepartureHold(leg, overlays)
  }

  void _runDepartureHold(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    phase = ReplayPhase.departureHold;
    // ... → _runFlight(leg, overlays)
  }

  void _runFlight(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    phase = ReplayPhase.flight;
    _callAudio('travel', leg: leg);
    // ... → _runPulse(leg, overlays)
  }

  void _runPulse(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    phase = ReplayPhase.pulse;
    _callAudio('arrival');
    // ... → _runHold(leg, overlays)
  }

  void _runHold(TravelLeg leg, List<ReplayOverlayEvent> overlays) {
    phase = ReplayPhase.hold;
    // ... → _afterHold(overlays)
  }

  void _afterHold(List<ReplayOverlayEvent> overlays) {
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
    phase = ReplayPhase.overlay;
    final evt = currentOverlayEvents[currentOverlayEventIndex];
    if (evt is ReplayAchievementEvent) _callAudio('achievement');
    if (evt is ReplayHeritageEvent) _callAudio('heritage');
    // 1600 ms bell-curve fade — identical to TravelReplayController._runOverlay
    // On last overlay complete:
    //   currentLegIndex++; _processNextEvent();
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

  // ── Helpers (same as TravelReplayController) ───────────────────────────────

  LegPacing _pacingFor(TravelLeg leg) {
    final legCount = currentLegIndex + 1; // approximate
    return LegPacing(
      departureSettleMs: _kDepartureSettleMs,
      departureHoldMs: _kDepartureHoldMs,
      flightMs: TravelReplayScriptBuilder.legDurationMs(legCount.clamp(1, 100)),
      pulseMs: _kPulseMs,
      holdMs: _kHoldMs,
      peakScale: ReplayPacingRules.peakScaleForArc(
          ReplayPacingRules.legArcDistance(leg)),
      scaleDipAmount: ReplayPacingRules.scaleDipForArc(
          ReplayPacingRules.legArcDistance(leg)),
    );
  }

  AnimationController _makeCtrl(Duration duration) {
    _phaseCtrl?.dispose();
    final ms = speedMultiplier <= 1.0
        ? duration.inMilliseconds
        : (duration.inMilliseconds / speedMultiplier)
            .round()
            .clamp(30, duration.inMilliseconds);
    return AnimationController(
        vsync: _vsync, duration: Duration(milliseconds: ms));
  }

  void _callAudio(String kind, {TravelLeg? leg}) {
    final ac = _audioController;
    if (ac == null) return;
    switch (kind) {
      case 'travel':
        final dist = leg != null
            ? ReplayPacingRules.legArcDistance(leg)
            : 45.0;
        ac.playTravelMovement(dist);
      case 'arrival': ac.playArrival();
      case 'achievement': ac.playAchievement();
      case 'heritage': ac.playHeritage();
      case 'end': ac.playScanComplete();
    }
  }

  static Map<String, (double, double)> _centroids = const {};
  static void setCentroids(Map<String, (double, double)> m) =>
      _centroids = m;

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
    while (diff > math.pi) { diff -= 2 * math.pi; }
    while (diff < -math.pi) { diff += 2 * math.pi; }
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
```

---

## Modified Files

### `lib/features/globe_replay/replay_audio_controller.dart`

Add two new sound slots to cover live-scan-specific events:

```dart
// New players
final AudioPlayer _heritage;   // gold chime variant for heritage reveals
final AudioPlayer _yearChange; // rising two-note for year transition

// New methods
void playHeritage() { if (isMuted) return; _play(_heritage, _heritageBytes); }
void playYearTransition() { if (isMuted) return; _play(_yearChange, _yearBytes); }
void playScanComplete() { if (isMuted) return; _play(_end, _endBytes); }
// Note: playScanComplete reuses the existing _end player/bytes.
```

New tones in `replay_tone_generator.dart`:
```dart
/// Gold chime for UNESCO heritage reveals — 880 Hz + 1100 Hz overtone, 0.6 s.
static Uint8List heritage() { ... }

/// Rising two-note for year transitions — 523 Hz (C5) → 784 Hz (G5), 0.4 s.
static Uint8List yearTransition() { ... }
```

---

### `lib/features/globe_replay/globe_replay_widget.dart`

Add `dataSource` as an alternative constructor parameter to `GlobeReplayWidget`:

```dart
class GlobeReplayWidget extends ConsumerStatefulWidget {
  const GlobeReplayWidget({
    super.key,
    this.script,
    this.dataSource,
    this.onScanComplete,
  }) : assert(script != null || dataSource != null,
               'Either script or dataSource must be provided');

  final TravelReplayScript? script;       // historical mode
  final ReplayDataSource? dataSource;     // live scan mode
  final VoidCallback? onScanComplete;
```

State holds both controller types; only one is active:

```dart
class _GlobeReplayWidgetState extends ConsumerState<GlobeReplayWidget>
    with TickerProviderStateMixin {
  TravelReplayController? _ctrl;           // historical mode
  LiveScanReplayController? _liveCtrl;     // live scan mode
  late final ReplayAudioController _audioCtrl;
  late final AnimationController _heritagePulseCtrl;
  bool _isMuted = false;
  double _speedMultiplier = 1.0;
  bool _scanCompleteCalled = false;

  bool get _isLiveMode => widget.dataSource != null;
```

`build()` delegates all state reads through a getter shim:
```dart
ReplayPhase get _phase =>
    _isLiveMode ? _liveCtrl!.phase : _ctrl!.phase;
GlobeProjection get _projection =>
    _isLiveMode ? _liveCtrl!.projection : _ctrl!.projection;
// ... etc for all observable fields
```

New UI elements shown only in live mode:

```dart
// "Scanning live…" chip — shown when liveState == waitingForEvents
if (_isLiveMode &&
    _liveCtrl!.liveState == LiveScanReplayState.waitingForEvents)
  Positioned(
    top: ...,
    child: _ScanningLiveChip(processedCount: _liveCtrl!.processedCount),
  ),

// Queue depth badge — shown when >= 2 legs queued
if (_isLiveMode && _liveCtrl!.queuedLegCount >= 2)
  Positioned(
    top: ...,
    child: _QueueDepthBadge(count: _liveCtrl!.queuedLegCount),
  ),

// Year banner overlay — shown during YearStartedEvent processing
if (_isLiveMode && _liveCtrl!.activeYearBanner != null)
  Positioned.fill(
    child: _YearBannerOverlay(year: _liveCtrl!.activeYearBanner!),
  ),
```

Speed selector **hidden** in live mode (pace is driven by scan speed).
`ReplaySummaryScreen` suppressed in live mode (replaced by `ScanSummaryScreen`).

New private widgets:
```dart
class _ScanningLiveChip extends StatelessWidget { ... }
// Pulsing "Scanning live… N photos" pill
class _QueueDepthBadge extends StatelessWidget { ... }
// "N countries queued" subtle badge
class _YearBannerOverlay extends StatelessWidget { ... }
// Full-screen dimmed year number — same style as the existing replay year
// indication; reuse visual from M131 _ScanYearBanner if extracted
```

---

### `lib/features/scan/scan_screen.dart`

**Scan start (before batch loop):**
```dart
// In _scan(), immediately after setState (scanning = true):
TravelReplayController.setCentroids(kCountryCentroids);
LiveScanReplayController.setCentroids(kCountryCentroids);
final _liveSource = LiveScanReplayDataSource();
final nav = Navigator.of(context);
unawaited(nav.push(MaterialPageRoute<void>(
  builder: (_) => GlobeReplayWidget(
    dataSource: _liveSource,
    onScanComplete: () {
      nav.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Push ScanSummaryScreen (built from already-computed vars captured below)
      });
    },
  ),
)));
```

**Per-batch event feeding:**

Track scan-level state across batches:
```dart
String? _lastEmittedCountryCode;  // most recently emitted leg's toCode
final Set<int> _emittedYears = {};  // years for which YearStartedEvent was emitted
final Set<String> _emittedCountryCodes = {};  // countries already emitted as legs
```

After each batch resolves new countries in `accum`:
```dart
// Sort newly found countries by firstSeen date (chronological emission order).
final newCodes = batchResult.accum.keys
    .where((c) => !_emittedCountryCodes.contains(c))
    .sorted((a, b) => (accum[a]!.firstSeen ?? DateTime.now())
        .compareTo(accum[b]!.firstSeen ?? DateTime.now()));

for (final code in newCodes) {
  final firstSeen = accum[code]!.firstSeen;
  // Year banner if year changes.
  if (firstSeen != null && _emittedYears.add(firstSeen.year)) {
    _liveSource.addEvent(YearStartedEvent(year: firstSeen.year));
  }
  // Leg event (from last emitted country → this country).
  final from = _lastEmittedCountryCode ?? code; // first country: from = to
  if (from != code) {
    _liveSource.addEvent(CountryDiscoveredEvent(
      fromCode: from,
      toCode: code,
      date: firstSeen ?? DateTime.now(),
      // GPS: from lastGps[from] and firstGps[code] from allPhotoGps
    ));
  }
  _lastEmittedCountryCode = code;
  _emittedCountryCodes.add(code);

  // Attach heritage sites already discovered in this country.
  for (final site in whsAccum.values.where((s) => s.countryCode == code)) {
    _liveSource.addEvent(HeritageSiteDiscoveredEvent(
      countryCode: code,
      siteName: site.name,
      siteType: site.category,
    ));
  }
}

// Attach any newly unlocked achievements (from _achievementsUnlockedInOrder delta).
for (final id in newAchievementIds) {
  final a = kAchievements.firstWhereOrNull((a) => a.id == id);
  if (a != null) {
    _liveSource.addEvent(AchievementUnlockedEvent(
      achievementId: id,
      title: a.title,
      subtitle: a.subtitle,
      countryCode: _lastEmittedCountryCode,
    ));
  }
}

// Progress update.
_liveSource.addEvent(ScanProgressUpdatedEvent(processedCount: totalProcessed));
```

**On scan complete:**
```dart
_liveSource.markScanComplete();
// LiveScanReplayController.onComplete fires onScanComplete → ScanSummaryScreen
```

**Remove** `_buildScanReplayScript()` (M131 approach).
**Remove** existing `await nav.push(GlobeReplayWidget(script: ...))` block in `_NewCountriesFound`.

---

## ReplayPacingRules additions

`ReplayPacingRules` currently has `buildPacingList(TravelReplayScript)` and `legArcDistance(TravelLeg)`. Two new static helpers needed by `LiveScanReplayController`:

```dart
/// Returns peak globe scale for a given arc distance.
static double peakScaleForArc(double arcDeg) { ... }

/// Returns scale dip amount for a given arc distance.
static double scaleDipForArc(double arcDeg) { ... }
```

These are extracted from the existing `buildPacingList` classification logic (short/medium/long arc).

---

## Scope In

| File | Change |
|------|--------|
| `lib/features/globe_replay/replay_data_source.dart` | **New** — `ReplayEvent` sealed hierarchy, `ReplayDataSource` interface, `HistoricalReplayDataSource` |
| `lib/features/scan/live_scan_replay_data_source.dart` | **New** — `LiveScanReplayDataSource` |
| `lib/features/globe_replay/live_scan_replay_controller.dart` | **New** — `LiveScanReplayController`, `LiveScanReplayState` |
| `lib/features/globe_replay/replay_audio_controller.dart` | Add `playHeritage()`, `playYearTransition()`, `playScanComplete()` |
| `lib/features/globe_replay/replay_tone_generator.dart` | Add `heritage()`, `yearTransition()` WAV generators |
| `lib/features/globe_replay/globe_replay_widget.dart` | `dataSource` param; live mode UI (`_ScanningLiveChip`, `_QueueDepthBadge`, `_YearBannerOverlay`); shim getters |
| `lib/features/globe_replay/travel_replay_engine.dart` | `ReplayPacingRules.peakScaleForArc()`, `scaleDipForArc()` |
| `lib/features/scan/scan_screen.dart` | Live source wiring; per-batch event feeding; remove M131 `_buildScanReplayScript` |

## Scope Out

| Item | Reason |
|------|--------|
| `TravelReplayController` | Untouched — historical replay unchanged |
| `TravelReplayScript` | Untouched |
| `GlobeReplayPainter` | Untouched |
| `ReplayTimelineBuilder` | Untouched (not used in live path) |
| Achievement definitions | Untouched |
| Purchase / profile flows | Untouched |
| Web platform | Live scan not available on web |
| `ScanSummaryScreen` | Untouched — only navigation to it changes |

---

## State Diagram

```
LiveScanReplayController state machine:

  idle
  ──┬─── start() ─────────────────────────────► presentingLeg
    │                                               │
    │                     ◄── next event in queue ──┤
    │                                               │
    │              ┌── leg + overlays done ──────────┘
    │              │
    │              ├── queue empty, !scanComplete ──► waitingForEvents
    │              │                                       │
    │              │                       new event ──────┘
    │              │
    │              └── queue empty, scanComplete ───► completed
    │                                                     │
    │                                              onComplete()
    │
    └── (scan never found new countries) ─────────────────►  completed directly
```

---

## Sequencing Rules

1. Only one `CountryDiscoveredEvent` animates at a time — the controller does not call `_processNextEvent` until the full leg animation sequence (departureSettle → flight → pulse → hold → overlays) completes.
2. `HeritageSiteDiscoveredEvent` and `AchievementUnlockedEvent` are consumed immediately after their matching `CountryDiscoveredEvent` in the queue; they are never displayed in isolation mid-flight.
3. Overlay events (heritage, achievements) run in list order, 1600 ms each, bell-curve fade — identical to `TravelReplayController._runOverlay`.
4. `YearStartedEvent` pauses for `_kYearBannerMs` (1500 ms) before the next event.
5. `ScanProgressUpdatedEvent` is consumed silently (updates `processedCount` and rebuilds the "Scanning live…" chip) without interrupting the current animation.
6. If scan completes while controller is mid-leg: `_scanComplete` flag is set; the controller drains the remaining queue naturally, then transitions to `completed`.
7. If scan completes with an empty queue (very fast scan, or no new countries): transitions directly to `completed`.
8. `speedMultiplier` applies to all phases in live mode.
9. `reducedMotion` halves all phase durations in live mode.

---

## Audio Map

| Trigger | Method | Sound |
|---------|--------|-------|
| Globe flight | `playTravelMovement(dist)` | Short/long whoosh (existing) |
| Country arrival | `playArrival()` | Bell chime (existing) |
| Achievement overlay | `playAchievement()` | Ascending arpeggio (existing) |
| Heritage overlay | `playHeritage()` | Gold chime variant **(new)** |
| Year transition banner | `playYearTransition()` | Rising two-note **(new)** |
| Replay complete / scan done | `playScanComplete()` | End fanfare (reuses existing `playReplayEnd`) |

---

## Acceptance Criteria

- [ ] Scan start immediately pushes `GlobeReplayWidget` — no waiting for scan to complete
- [ ] Each new country discovered causes a full globe flight animation (departureSettle → flight → pulse → hold)
- [ ] Heritage overlays show per-country in queue order (gold card, bell-curve 1600 ms fade)
- [ ] Achievement overlays show per-country after heritage, in order (no overlap)
- [ ] `YearStartedEvent` triggers a 1500 ms year banner before the next leg
- [ ] `ScanProgressUpdatedEvent` updates the "Scanning live…" chip without interrupting animation
- [ ] "Scanning live…" indicator visible when `liveState == waitingForEvents`
- [ ] Queue depth badge visible when `queuedLegCount >= 2`
- [ ] Scan engine is not slowed by replay — batch loop runs freely; events enqueue in background
- [ ] Scan completing while controller is mid-leg: controller finishes leg + drains queue, then fires `onScanComplete`
- [ ] Scan completing with empty queue: controller transitions directly to `completed`
- [ ] `onScanComplete` → pops `GlobeReplayWidget` → pushes `ScanSummaryScreen`
- [ ] Historical replay (from map) works unchanged — `GlobeReplayWidget(script: ...)` path unaffected
- [ ] `playHeritage()` and `playYearTransition()` produce audible synthesised tones
- [ ] `playScanComplete()` plays end fanfare on scan done
- [ ] Speed selector (1×/2×/3×) applies in live mode
- [ ] Mute toggle suppresses all audio in live mode
- [ ] `flutter analyze` — 0 new warnings
