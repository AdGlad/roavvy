import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';

// Colours match CountryPolygonLayer constants (ADR-077).
const _kUnvisitedFill = Color(0xFFE5E7EB); // grey-200
const _kUnvisitedBorder = Color(0xFF9CA3AF); // grey-400
const _kRevealedFill = Color(0xFFFFB300); // amber-700
const _kRevealedBorder = Color(0xFFFF8F00); // amber-900

/// A fixed-height mini-map that reveals newly discovered countries one-by-one
/// via a [Timer.periodic] queue pop-in animation. (ADR-077)
///
/// Shown at the top of [ScanSummaryScreen] State A when 2 or more new
/// countries were discovered. Each country polygon pops in at 400 ms intervals.
///
/// Respects [MediaQuery.disableAnimationsOf]: when true, all countries are
/// revealed immediately without a timer.
///
/// [onDoubleTap] is called when the user double-taps the map (M56-10).
class ScanRevealMiniMap extends ConsumerStatefulWidget {
  const ScanRevealMiniMap({
    super.key,
    required this.newCodes,
    this.onDoubleTap,
  });

  /// ISO codes of newly discovered countries to reveal one-by-one.
  final List<String> newCodes;

  /// Optional callback invoked on double-tap (e.g. navigate to main map).
  final VoidCallback? onDoubleTap;

  @override
  ConsumerState<ScanRevealMiniMap> createState() => _ScanRevealMiniMapState();
}

class _ScanRevealMiniMapState extends ConsumerState<ScanRevealMiniMap> {
  final Set<String> _revealed = {};
  Timer? _timer;
  late final List<String> _queue;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.newCodes);
    // Timer is started after the first frame so MediaQuery is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startReveal());
  }

  void _startReveal() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reveal all immediately.
      setState(() => _revealed.addAll(_queue));
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      if (_queue.isEmpty) {
        _timer?.cancel();
        return;
      }
      final next = _queue.removeAt(0);
      setState(() => _revealed.add(next));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);

    final unvisitedPolygons = <Polygon>[];
    final revealedPolygons = <Polygon>[];

    for (final cp in polygons) {
      final isRevealed = _revealed.contains(cp.isoCode);
      final points = cp.vertices
          .map((v) => LatLng(v.$1, v.$2))
          .toList();

      if (isRevealed) {
        revealedPolygons.add(Polygon(
          points: points,
          color: _kRevealedFill,
          borderColor: _kRevealedBorder,
          borderStrokeWidth: 0.5,
        ));
      } else {
        unvisitedPolygons.add(Polygon(
          points: points,
          color: _kUnvisitedFill,
          borderColor: _kUnvisitedBorder,
          borderStrokeWidth: 0.5,
        ));
      }
    }

    // Double-tap zoom is disabled so GestureDetector can handle double-tap
    // for navigation (M56-10). Pinch-zoom and drag remain enabled (M56-09).
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(20, 0),
            initialZoom: 1.2,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all &
                  ~InteractiveFlag.doubleTapZoom &
                  ~InteractiveFlag.doubleTapDragZoom,
            ),
          ),
          children: [
            PolygonLayer(polygons: unvisitedPolygons),
            PolygonLayer(polygons: revealedPolygons),
          ],
        ),
      ),
    );
  }
}
