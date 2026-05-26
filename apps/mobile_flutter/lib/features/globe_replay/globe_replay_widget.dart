import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../map/country_centroids.dart';
import '../map/country_visual_state.dart';
import '../map/globe_painter.dart';
import '../map/globe_projection.dart';
import 'globe_replay_painter.dart';
import 'live_scan_replay_controller.dart';
import 'replay_audio_controller.dart';
import 'replay_data_source.dart';
import 'package:confetti/confetti.dart';

import '../../core/flag_colours.dart';
import 'country_discovery_overlay.dart';
import 'replay_overlay_widgets.dart';
import 'replay_summary_screen.dart';
import 'travel_replay_controller.dart';
import 'travel_replay_engine.dart';

/// Full-screen cinematic travel replay overlay (M108).
///
/// Supports two modes:
/// - **Historical** (`script` param): drives [TravelReplayController] from a
///   pre-built [TravelReplayScript]. Used from the map entry sheet.
/// - **Live scan** (`dataSource` param): drives [LiveScanReplayController]
///   from a [ReplayDataSource] fed in real time by [_ScanScreenState].
///
/// Exactly one of [script] or [dataSource] must be provided.
///
/// [onScanComplete]: called when replay finishes (either mode). The caller is
/// responsible for navigating to the next screen.
class GlobeReplayWidget extends ConsumerStatefulWidget {
  const GlobeReplayWidget({
    super.key,
    this.script,
    this.dataSource,
    this.onScanComplete,
  }) : assert(
          script != null || dataSource != null,
          'Either script or dataSource must be provided',
        );

  /// Historical replay script. Provide either this or [dataSource].
  final TravelReplayScript? script;

  /// Live scan data source. Provide either this or [script].
  final ReplayDataSource? dataSource;

  /// When non-null, replay completion calls this instead of showing
  /// [ReplaySummaryScreen].
  final VoidCallback? onScanComplete;

  @override
  ConsumerState<GlobeReplayWidget> createState() => _GlobeReplayWidgetState();
}

class _GlobeReplayWidgetState extends ConsumerState<GlobeReplayWidget>
    with TickerProviderStateMixin {
  TravelReplayController? _ctrl;
  LiveScanReplayController? _liveCtrl;
  late final ReplayAudioController _audioCtrl;
  late final AnimationController _heritagePulseCtrl;
  bool _isMuted = false;
  double _speedMultiplier = 1.0;
  bool _scanCompleteCalled = false;

  // ── First-visit discovery (M133) ───────────────────────────────────────────
  late final ConfettiController _confettiCtrl;
  String? _confettiCountry;
  List<Color> _confettiColors = const [Colors.amber, Colors.white70];
  int _slotPulseTrigger = 0;

  bool get _isLiveMode => widget.dataSource != null;

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .reduceMotion;

    TravelReplayController.setCentroids(kCountryCentroids);
    LiveScanReplayController.setCentroids(kCountryCentroids);

    _audioCtrl = ReplayAudioController();

    _heritagePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _confettiCtrl = ConfettiController(
      duration: const Duration(milliseconds: 600),
    );

    if (_isLiveMode) {
      _liveCtrl = LiveScanReplayController(
        dataSource: widget.dataSource!,
        vsync: this,
      );
      _liveCtrl!.reducedMotion = reduceMotion;
      _liveCtrl!.speedMultiplier = 3.0; // scan replay runs at 3× to keep pace with detection
      _liveCtrl!.audioController = _audioCtrl;
      _liveCtrl!.addListener(_onControllerUpdate);
    } else {
      _ctrl = TravelReplayController(script: widget.script!, vsync: this);
      _ctrl!.reducedMotion = reduceMotion;
      _ctrl!.audioController = _audioCtrl;
      _ctrl!.addListener(_onControllerUpdate);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _audioCtrl.preload();
      if (!mounted) return;
      if (_isLiveMode) {
        _liveCtrl!.start();
      } else {
        _ctrl!.play();
      }
    });
  }

  @override
  void dispose() {
    if (_isLiveMode) {
      _liveCtrl!.removeListener(_onControllerUpdate);
      _liveCtrl!.dispose();
    } else {
      _ctrl!.removeListener(_onControllerUpdate);
      _ctrl!.dispose();
    }
    _audioCtrl.dispose();
    _heritagePulseCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!_scanCompleteCalled &&
        _phase == ReplayPhase.done &&
        widget.onScanComplete != null) {
      _scanCompleteCalled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScanComplete!.call();
      });
    }
    // M133: trigger confetti when first entering flagReveal for a new country.
    if (_phase == ReplayPhase.flagReveal) {
      final code = _currentLeg?.toCode;
      if (code != null && code != _confettiCountry) {
        _confettiCountry = code;
        _triggerConfetti(code);
      }
    }
    // M133: pulse the newly inserted slot when flagFlight completes.
    if (_phase == ReplayPhase.overlay || _phase == ReplayPhase.hold ||
        (_phase != ReplayPhase.flagFlight && _lastPhaseWasFlagFlight)) {
      if (_lastPhaseWasFlagFlight) {
        _slotPulseTrigger++;
      }
    }
    _lastPhaseWasFlagFlight = _phase == ReplayPhase.flagFlight;
    if (mounted) setState(() {});
  }

  bool _lastPhaseWasFlagFlight = false;

  Future<void> _triggerConfetti(String countryCode) async {
    final colors = await flagColours(countryCode);
    if (!mounted || _confettiCountry != countryCode) return;
    setState(() {
      _confettiColors = colors != null && colors.isNotEmpty
          ? colors
          : const [Colors.amber, Colors.white70];
    });
    _confettiCtrl.play();
  }

  void _replayAgain() => _ctrl?.play();

  void _share(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Share coming soon')),
    );
  }

  void _createTShirt(BuildContext ctx) {
    Navigator.of(ctx).pop();
  }

  // ── Getter shims ────────────────────────────────────────────────────────────

  ReplayPhase get _phase =>
      _isLiveMode ? _liveCtrl!.phase : _ctrl!.phase;

  GlobeProjection get _projection =>
      _isLiveMode ? _liveCtrl!.projection : _ctrl!.projection;

  double get _arcProgress =>
      _isLiveMode ? _liveCtrl!.arcProgress : _ctrl!.arcProgress;

  double get _pulseValue =>
      _isLiveMode ? _liveCtrl!.pulseValue : _ctrl!.pulseValue;

  int get _currentLegIndex =>
      _isLiveMode ? _liveCtrl!.completedLegs.length : _ctrl!.currentLegIndex;

  List<ReplayOverlayEvent> get _currentOverlayEvents =>
      _isLiveMode ? _liveCtrl!.currentOverlayEvents : _ctrl!.currentOverlayEvents;

  int get _currentOverlayEventIndex =>
      _isLiveMode ? _liveCtrl!.currentOverlayEventIndex : _ctrl!.currentOverlayEventIndex;

  double get _overlayProgress =>
      _isLiveMode ? _liveCtrl!.overlayProgress : _ctrl!.overlayProgress;

  double get _flagRevealProgress =>
      _isLiveMode ? _liveCtrl!.flagRevealProgress : _ctrl!.flagRevealProgress;

  double get _flagFlightProgress =>
      _isLiveMode ? _liveCtrl!.flagFlightProgress : _ctrl!.flagFlightProgress;

  List<String> get _collectedCodes =>
      _isLiveMode ? _liveCtrl!.collectedCodes : (_ctrl!.collectedCodes);

  List<(double, double)> get _heritageSiteCoords => _isLiveMode
      ? _liveCtrl!.visitedHeritageSiteCoords
      : widget.script!.visitedHeritageSiteCoords;

  /// All legs known so far (historical: all legs; live: completed + active).
  List<TravelLeg> get _currentLegs {
    if (_isLiveMode) {
      final active = _liveCtrl!.activeLeg;
      return [
        ..._liveCtrl!.completedLegs,
        if (active != null) active,
      ];
    }
    return widget.script!.legs;
  }

  /// Current active leg (null if none).
  TravelLeg? get _currentLeg {
    if (_isLiveMode) return _liveCtrl!.activeLeg;
    final idx = _ctrl!.currentLegIndex;
    final legs = widget.script!.legs;
    if (idx >= legs.length) return null;
    return legs[idx];
  }

  // ── Visual state helpers ────────────────────────────────────────────────────

  Map<String, CountryVisualState> _buildReplayVisualStates() {
    final result = <String, CountryVisualState>{};
    final legs = _currentLegs;
    final cur = _currentLegIndex;

    void markVisited(String code) {
      result[code] = CountryVisualState.visited;
    }

    if (legs.isNotEmpty) markVisited(legs[0].fromCode);

    for (var i = 0; i < cur && i < legs.length; i++) {
      markVisited(legs[i].fromCode);
      markVisited(legs[i].toCode);
    }

    if (cur < legs.length) {
      markVisited(legs[cur].fromCode);
      if (_phase == ReplayPhase.pulse ||
          _phase == ReplayPhase.hold ||
          _phase == ReplayPhase.overlay) {
        markVisited(legs[cur].toCode);
      }
    }

    if (_phase == ReplayPhase.done) {
      for (final leg in legs) {
        markVisited(leg.fromCode);
        markVisited(leg.toCode);
      }
    }

    return result;
  }

  String? _currentArrivalCode() {
    if (_phase != ReplayPhase.pulse) return null;
    final legs = _currentLegs;
    final cur = _currentLegIndex;
    if (cur >= legs.length) return null;
    return legs[cur].toCode;
  }

  /// Builds a virtual [TravelReplayScript] from current legs for
  /// [GlobeReplayPainter] in live mode.
  TravelReplayScript get _liveScript {
    return TravelReplayScript(
      legs: _currentLegs,
      mode: TravelReplayMode.allTime,
      label: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    ref.watch(countryVisualStatesProvider);

    final isDone = _phase == ReplayPhase.done;
    final isOverlay = _phase == ReplayPhase.overlay &&
        _currentOverlayEvents.isNotEmpty &&
        _currentOverlayEventIndex < _currentOverlayEvents.length;
    final isFlagReveal = _phase == ReplayPhase.flagReveal;
    final isFlagFlight = _phase == ReplayPhase.flagFlight;

    final replayVisualStates = _buildReplayVisualStates();
    final arrivalCode = _currentArrivalCode();
    final collectedCodes = _collectedCodes;
    final currentLegs = _currentLegs;

    // Script for painter: historical uses widget.script; live builds a virtual one.
    final painterScript = _isLiveMode ? _liveScript : widget.script!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Globe + replay arc overlay.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isDone ? 0.15 : 1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInQuad,
              child: CustomPaint(
                painter: _CombinedGlobePainter(
                  polygons: polygons,
                  visualStates: replayVisualStates,
                  tripCounts: const {},
                  projection: _projection,
                  highlightedCode: arrivalCode,
                  pulseValue: _pulseValue,
                  heritageSiteCoords: _heritageSiteCoords,
                  heritagePulseValue: _heritagePulseCtrl.value,
                  replayPainter: GlobeReplayPainter(
                    projection: _projection,
                    script: painterScript,
                    currentLegIndex: _currentLegIndex,
                    arcProgress: _arcProgress,
                    pulseValue: _pulseValue,
                  ),
                ),
              ),
            ),
          ),

          // Top bar: label + mute + stop.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isLiveMode
                            ? 'Scanning your travels…'
                            : widget.script!.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _LegCounter(
                      current: _currentLegIndex,
                      total: _isLiveMode ? null : currentLegs.length,
                    ),
                    IconButton(
                      icon: Icon(
                        _isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          _audioCtrl.isMuted = _isMuted;
                          if (_isMuted) _audioCtrl.stopAll();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Stop replay',
                      onPressed: () {
                        if (_isLiveMode) {
                          _liveCtrl!.stop();
                        } else {
                          _ctrl!.stop();
                        }
                        _audioCtrl.stopAll();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom: flag list + leg label + speed selector (hidden in live mode).
          if (!isDone)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Speed selector — historical mode only.
                      if (!_isLiveMode)
                        _SpeedSelector(
                          value: _speedMultiplier,
                          onChanged: (v) {
                            setState(() {
                              _speedMultiplier = v;
                              _ctrl!.speedMultiplier = v;
                            });
                          },
                        ),
                      if (!_isLiveMode) const SizedBox(height: 6),
                      if (collectedCodes.isNotEmpty)
                        _CollectedFlagRow(
                          countryCodes: collectedCodes,
                          slotPulseTrigger: _slotPulseTrigger,
                        ),
                      if (!isOverlay && _currentLeg != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _LegLabel(
                            leg: _currentLeg!,
                            phase: _phase,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Overlay widget (achievement / stat / heritage) — centred on screen.
          if (isOverlay)
            Positioned.fill(
              child: _buildOverlayWidget(),
            ),

          // M133: first-visit flag reveal — large emoji + confetti.
          if (isFlagReveal && _currentLeg != null)
            Positioned.fill(
              child: CountryDiscoveryOverlay(
                countryCode: _currentLeg!.toCode,
                revealProgress: _flagRevealProgress,
                confettiCtrl: _confettiCtrl,
                confettiColors: _confettiColors,
              ),
            ),

          // M133: flag flight — animates from centre to bottom row.
          if (isFlagFlight && _currentLeg != null)
            Positioned.fill(
              child: FlagFlightOverlay(
                countryCode: _currentLeg!.toCode,
                flightProgress: _flagFlightProgress,
              ),
            ),

          // Live-mode: "Scanning live…" chip when waiting for events.
          if (_isLiveMode &&
              _liveCtrl!.liveState == LiveScanReplayState.waitingForEvents)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: _ScanningLiveChip(
                    processedCount: _liveCtrl!.processedCount),
              ),
            ),

          // Live-mode: queue depth badge.
          if (_isLiveMode && _liveCtrl!.queuedLegCount >= 2)
            Positioned(
              top: 80,
              right: 16,
              child: _QueueDepthBadge(count: _liveCtrl!.queuedLegCount),
            ),

          // Live-mode: year banner overlay.
          if (_isLiveMode && _liveCtrl!.activeYearBanner != null)
            Positioned.fill(
              child: _YearBannerOverlay(year: _liveCtrl!.activeYearBanner!),
            ),

          // Summary screen — slides up when done (suppressed in scan mode).
          if (widget.onScanComplete == null)
            Positioned.fill(
              child: ReplaySummaryScreen(
                script: widget.script!,
                isVisible: isDone,
                onReplayAgain: _replayAgain,
                onShare: () => _share(context),
                onCreateTShirt: () => _createTShirt(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayWidget() {
    final event = _currentOverlayEvents[_currentOverlayEventIndex];
    return switch (event) {
      ReplayAchievementEvent e => ReplayAchievementOverlay(
          event: e,
          overlayProgress: _overlayProgress,
        ),
      ReplayStatEvent e => ReplayStatOverlay(
          event: e,
          overlayProgress: _overlayProgress,
        ),
      ReplayHeritageEvent e => ReplayHeritageOverlay(
          event: e,
          overlayProgress: _overlayProgress,
        ),
    };
  }
}

/// Combines [GlobePainter] and [GlobeReplayPainter] into a single paint pass.
class _CombinedGlobePainter extends CustomPainter {
  const _CombinedGlobePainter({
    required this.polygons,
    required this.visualStates,
    required this.tripCounts,
    required this.projection,
    required this.replayPainter,
    this.highlightedCode,
    this.pulseValue = 0.0,
    this.heritageSiteCoords = const [],
    this.heritagePulseValue = 0.0,
  });

  final List<CountryPolygon> polygons;
  final Map<String, CountryVisualState> visualStates;
  final Map<String, int> tripCounts;
  final GlobeProjection projection;
  final GlobeReplayPainter replayPainter;
  final String? highlightedCode;
  final double pulseValue;
  final List<(double lat, double lng)> heritageSiteCoords;
  final double heritagePulseValue;

  @override
  void paint(canvas, size) {
    GlobePainter(
      polygons: polygons,
      visualStates: visualStates,
      tripCounts: tripCounts,
      projection: projection,
      highlightedCode: highlightedCode,
      pulseValue: pulseValue,
      culturalSiteCoords: heritageSiteCoords,
      heritagePulseValue: heritagePulseValue,
    ).paint(canvas, size);
    replayPainter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_CombinedGlobePainter old) => true;
}

class _LegCounter extends StatelessWidget {
  const _LegCounter({required this.current, required this.total});
  final int current;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final label = total != null
        ? '${(current + 1).clamp(1, total!)} / $total'
        : '${current + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

class _LegLabel extends StatelessWidget {
  const _LegLabel({required this.leg, required this.phase});
  final TravelLeg leg;
  final ReplayPhase phase;

  @override
  Widget build(BuildContext context) {
    final text = '${_label(leg.fromCode)} → ${_label(leg.toCode)}';
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static String _label(String code) {
    final flag = _flag(code);
    final name = kCountryNames[code.toUpperCase()] ?? code;
    return '$flag $name';
  }

  static String _flag(String code) {
    if (code.length != 2) return '';
    final upper = code.toUpperCase();
    final a = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }
}

/// Row of 1× / 2× / 3× speed buttons for the replay bottom bar.
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  static const _speeds = [1.0, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in _speeds) ...[
          if (s != _speeds.first) const SizedBox(width: 6),
          _SpeedChip(speed: s, selected: value == s, onTap: () => onChanged(s)),
        ],
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final double speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.amber : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${speed.toInt()}×',
          style: TextStyle(
            color: selected ? Colors.black87 : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Bottom collection row — shows only countries that have completed their
/// fly-in animation (committed to [collectedCodes]).
///
/// The last slot pulses when [slotPulseTrigger] increments.
class _CollectedFlagRow extends StatelessWidget {
  const _CollectedFlagRow({
    required this.countryCodes,
    required this.slotPulseTrigger,
  });

  final List<String> countryCodes;
  final int slotPulseTrigger;

  @override
  Widget build(BuildContext context) {
    if (countryCodes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: countryCodes.length,
        itemBuilder: (context, index) {
          final code = countryCodes[index];
          final isLast = index == countryCodes.length - 1;
          final flag = Text(
            _emojiFlagFromCode(code),
            style: const TextStyle(fontSize: 24),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: isLast
                ? SlotPulse(trigger: slotPulseTrigger, child: flag)
                : flag,
          );
        },
      ),
    );
  }

  static String _emojiFlagFromCode(String code) {
    final upper = code.toUpperCase();
    final a = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([a, b]);
  }
}



// ── Live-mode-only widgets ─────────────────────────────────────────────────────

/// Pulsing "Scanning live… N photos" pill shown when waiting for events.
class _ScanningLiveChip extends StatelessWidget {
  const _ScanningLiveChip({required this.processedCount});
  final int processedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Scanning… $processedCount photos',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Subtle badge showing how many country legs are queued.
class _QueueDepthBadge extends StatelessWidget {
  const _QueueDepthBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+$count queued',
        style: const TextStyle(color: Colors.amber, fontSize: 12),
      ),
    );
  }
}

/// Full-screen dimmed year-number overlay shown during a [YearStartedEvent].
class _YearBannerOverlay extends StatelessWidget {
  const _YearBannerOverlay({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Text(
          '$year',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}
