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
import 'replay_audio_controller.dart';
import 'replay_overlay_widgets.dart';
import 'replay_summary_screen.dart';
import 'travel_replay_controller.dart';
import 'travel_replay_engine.dart';

/// Full-screen cinematic travel replay overlay (M108).
///
/// Composites [GlobePainter] (the existing globe) with [GlobeReplayPainter]
/// (arc, marker, pulse) driven by [TravelReplayController].
///
/// Gestures are disabled during playback. The user can stop via the stop
/// button, which calls [Navigator.pop].
///
/// M110: renders [ReplayAchievementOverlay] / [ReplayStatOverlay] during
/// the [ReplayPhase.overlay] phase, and slides up [ReplaySummaryScreen]
/// when [ReplayPhase.done].
///
/// M111: owns [ReplayAudioController] (preloaded before play); exposes mute
/// toggle in the top bar; reads [MediaQuery.disableAnimations] to set
/// [TravelReplayController.reducedMotion]. Globe fades to 15% opacity on done.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => GlobeReplayWidget(script: script),
/// ));
/// ```
class GlobeReplayWidget extends ConsumerStatefulWidget {
  const GlobeReplayWidget({super.key, required this.script});

  final TravelReplayScript script;

  @override
  ConsumerState<GlobeReplayWidget> createState() => _GlobeReplayWidgetState();
}

class _GlobeReplayWidgetState extends ConsumerState<GlobeReplayWidget>
    with TickerProviderStateMixin {
  late final TravelReplayController _ctrl;
  late final ReplayAudioController _audioCtrl;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // M111: read reduced-motion preference before constructing controller.
    // ignore: use_build_context_synchronously — initState is safe here
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .reduceMotion;

    // Inject centroids so the controller can resolve lat/lng from ISO codes.
    TravelReplayController.setCentroids(kCountryCentroids);
    _ctrl = TravelReplayController(script: widget.script, vsync: this);
    _ctrl.reducedMotion = reduceMotion;
    _ctrl.addListener(_onControllerUpdate);

    // M111: create and wire audio controller.
    _audioCtrl = ReplayAudioController();
    _ctrl.audioController = _audioCtrl;

    // Preload audio then auto-play.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _audioCtrl.preload();
      if (mounted) _ctrl.play();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    _audioCtrl.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _replayAgain() {
    _ctrl.play();
  }

  void _share(BuildContext ctx) {
    // Placeholder: hook into existing share flow when wired end-to-end.
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Share coming soon')),
    );
  }

  void _createTShirt(BuildContext ctx) {
    Navigator.of(ctx).pop(); // dismiss replay; caller navigates to merch
  }

  /// Builds a visual-state map driven by replay progress.
  ///
  /// Starts blank so the globe appears unhighlighted at replay start.
  /// Countries are added as visited as legs complete.
  Map<String, CountryVisualState> _buildReplayVisualStates() {
    final result = <String, CountryVisualState>{};
    final total = widget.script.legs.length;
    final cur = _ctrl.currentLegIndex;

    void markVisited(String code) {
      result[code] = CountryVisualState.visited;
    }

    // Departure of the first leg is visible as soon as replay starts.
    if (total > 0) markVisited(widget.script.legs[0].fromCode);

    // All fully completed legs: both endpoints are highlighted.
    for (var i = 0; i < cur && i < total; i++) {
      markVisited(widget.script.legs[i].fromCode);
      markVisited(widget.script.legs[i].toCode);
    }

    // Current leg: fromCode always visible; toCode appears on arrival.
    if (cur < total) {
      markVisited(widget.script.legs[cur].fromCode);
      if (_ctrl.phase == ReplayPhase.pulse ||
          _ctrl.phase == ReplayPhase.hold ||
          _ctrl.phase == ReplayPhase.overlay) {
        markVisited(widget.script.legs[cur].toCode);
      }
    }

    // Done: all countries highlighted.
    if (_ctrl.phase == ReplayPhase.done) {
      for (final leg in widget.script.legs) {
        markVisited(leg.fromCode);
        markVisited(leg.toCode);
      }
    }

    return result;
  }

  /// ISO code of the arrival country during the pulse phase (for expand halo).
  String? _currentArrivalCode() {
    if (_ctrl.phase != ReplayPhase.pulse) return null;
    final cur = _ctrl.currentLegIndex;
    if (cur >= widget.script.legs.length) return null;
    return widget.script.legs[cur].toCode;
  }

  /// Returns visited country codes in the order they were first arrived at.
  List<String> _visitedCountriesInOrder() {
    final codes = <String>[];
    final seen = <String>{};

    void add(String code) {
      if (seen.add(code)) codes.add(code);
    }

    final total = widget.script.legs.length;
    final cur = _ctrl.currentLegIndex;

    if (total > 0) add(widget.script.legs[0].fromCode);

    for (var i = 0; i < cur && i < total; i++) {
      add(widget.script.legs[i].fromCode);
      add(widget.script.legs[i].toCode);
    }

    if (cur < total) {
      add(widget.script.legs[cur].fromCode);
      if (_ctrl.phase == ReplayPhase.pulse ||
          _ctrl.phase == ReplayPhase.hold ||
          _ctrl.phase == ReplayPhase.overlay) {
        add(widget.script.legs[cur].toCode);
      }
    }

    if (_ctrl.phase == ReplayPhase.done) {
      for (final leg in widget.script.legs) {
        add(leg.fromCode);
        add(leg.toCode);
      }
    }

    return codes;
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    // countryVisualStatesProvider not used during replay — we build states from
    // controller progress so the globe starts blank and reveals countries live.
    ref.watch(countryVisualStatesProvider); // keep dependency for hot-reload

    final isDone = _ctrl.phase == ReplayPhase.done;
    final isOverlay = _ctrl.phase == ReplayPhase.overlay &&
        _ctrl.currentOverlayEvents.isNotEmpty &&
        _ctrl.currentOverlayEventIndex < _ctrl.currentOverlayEvents.length;

    final replayVisualStates = _buildReplayVisualStates();
    final arrivalCode = _currentArrivalCode();
    final visitedCodes = _visitedCountriesInOrder();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Globe + replay arc overlay. M111: fades to 15% on done.
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
                  projection: _ctrl.projection,
                  highlightedCode: arrivalCode,
                  pulseValue: _ctrl.pulseValue,
                  replayPainter: GlobeReplayPainter(
                    projection: _ctrl.projection,
                    script: widget.script,
                    currentLegIndex: _ctrl.currentLegIndex,
                    arcProgress: _ctrl.arcProgress,
                    pulseValue: _ctrl.pulseValue,
                  ),
                ),
              ),
            ),
          ),

          // Top bar: script label + mute + stop.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.script.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _LegCounter(
                      current: _ctrl.currentLegIndex,
                      total: widget.script.legs.length,
                    ),
                    // M111: mute toggle.
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
                        _ctrl.stop();
                        _audioCtrl.stopAll();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom: growing flag list + leg label (hidden during overlay and done).
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
                      if (visitedCodes.isNotEmpty)
                        _ReplayFlagList(countryCodes: visitedCodes),
                      if (!isOverlay &&
                          _ctrl.currentLegIndex < widget.script.legs.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _LegLabel(
                            leg: widget.script.legs[_ctrl.currentLegIndex],
                            phase: _ctrl.phase,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // M110: Overlay widget (achievement / stat) — centred on screen.
          if (isOverlay)
            Positioned.fill(
              child: _buildOverlayWidget(),
            ),

          // M110: Summary screen — slides up when done.
          Positioned.fill(
            child: ReplaySummaryScreen(
              script: widget.script,
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
    final event = _ctrl.currentOverlayEvents[_ctrl.currentOverlayEventIndex];
    return switch (event) {
      ReplayAchievementEvent e => ReplayAchievementOverlay(
          event: e,
          overlayProgress: _ctrl.overlayProgress,
        ),
      ReplayStatEvent e => ReplayStatOverlay(
          event: e,
          overlayProgress: _ctrl.overlayProgress,
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
  });

  final List<CountryPolygon> polygons;
  final Map<String, CountryVisualState> visualStates;
  final Map<String, int> tripCounts;
  final GlobeProjection projection;
  final GlobeReplayPainter replayPainter;

  /// Arrival country during pulse phase — passed to [GlobePainter] for halo.
  final String? highlightedCode;

  /// Pulse progress 0.0–1.0 driving the arrival halo size/opacity.
  final double pulseValue;

  @override
  void paint(canvas, size) {
    GlobePainter(
      polygons: polygons,
      visualStates: visualStates,
      tripCounts: tripCounts,
      projection: projection,
      highlightedCode: highlightedCode,
      pulseValue: pulseValue,
    ).paint(canvas, size);
    replayPainter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_CombinedGlobePainter old) => true;
}

class _LegCounter extends StatelessWidget {
  const _LegCounter({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(current + 1).clamp(1, total)} / $total',
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

  /// Returns "🇦🇺 Australia" style label for a country code.
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

/// Horizontally scrollable row of emoji flags for all countries visited so far.
///
/// Grows by one flag each time a new country is arrived at during replay.
class _ReplayFlagList extends StatelessWidget {
  const _ReplayFlagList({required this.countryCodes});

  final List<String> countryCodes;

  static String _flag(String code) {
    if (code.length != 2) return '';
    final upper = code.toUpperCase();
    final a = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in countryCodes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                _flag(code),
                style: const TextStyle(fontSize: 22),
              ),
            ),
        ],
      ),
    );
  }
}

