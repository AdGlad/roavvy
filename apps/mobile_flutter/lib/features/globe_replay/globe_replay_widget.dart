import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../map/country_centroids.dart';
import '../map/country_visual_state.dart';
import '../map/globe_painter.dart';
import '../map/globe_projection.dart';
import 'globe_replay_painter.dart';
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

  @override
  void initState() {
    super.initState();
    // Inject centroids so the controller can resolve lat/lng from ISO codes.
    TravelReplayController.setCentroids(kCountryCentroids);
    _ctrl = TravelReplayController(script: widget.script, vsync: this);
    _ctrl.addListener(_onControllerUpdate);
    // Auto-play.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.play();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
    if (_ctrl.phase == ReplayPhase.done && mounted) {
      // Brief pause then pop.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    final visualStates = ref.watch(countryVisualStatesProvider);
    final tripCounts =
        ref.watch(countryTripCountsProvider).valueOrNull ?? const <String, int>{};

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Globe + replay arc overlay.
          Positioned.fill(
            child: CustomPaint(
              painter: _CombinedGlobePainter(
                polygons: polygons,
                visualStates: visualStates,
                tripCounts: tripCounts,
                projection: _ctrl.projection,
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

          // Top bar: script label + stop button.
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Stop replay',
                      onPressed: () {
                        _ctrl.stop();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom: current leg label.
          if (_ctrl.currentLegIndex < widget.script.legs.length)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _LegLabel(
                leg: widget.script.legs[_ctrl.currentLegIndex],
                phase: _ctrl.phase,
              ),
            ),
        ],
      ),
    );
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
  });

  final List<CountryPolygon> polygons;
  final Map<String, CountryVisualState> visualStates;
  final Map<String, int> tripCounts;
  final GlobeProjection projection;
  final GlobeReplayPainter replayPainter;

  @override
  void paint(canvas, size) {
    GlobePainter(
      polygons: polygons,
      visualStates: visualStates,
      tripCounts: tripCounts,
      projection: projection,
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
    final text = '${_name(leg.fromCode)} → ${_name(leg.toCode)}';
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

  static String _name(String code) => code; // future: use kCountryNames
}
