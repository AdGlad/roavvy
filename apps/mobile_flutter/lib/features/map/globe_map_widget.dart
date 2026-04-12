import 'dart:math' as math;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'country_visual_state.dart';
import 'globe_painter.dart';
import 'globe_projection.dart';

/// Interactive 3D globe widget that renders country polygons using orthographic
/// projection (ADR-116).
///
/// - Single-finger drag → rotate the globe (longitude + latitude).
/// - Two-finger pinch → zoom in/out (scale 0.8–8.0).
/// - Tap → resolves lat/lng via [resolveCountry] and calls [onCountryTap].
///
/// All polygon and visual-state data is sourced from Riverpod providers;
/// no data is passed via constructor (keeps the widget self-contained).
class GlobeMapWidget extends ConsumerStatefulWidget {
  const GlobeMapWidget({
    super.key,
    required this.onCountryTap,
  });

  /// Called when the user taps a visible country polygon.
  final void Function(String isoCode) onCountryTap;

  @override
  ConsumerState<GlobeMapWidget> createState() => _GlobeMapWidgetState();
}

class _GlobeMapWidgetState extends ConsumerState<GlobeMapWidget> {
  GlobeProjection _projection = const GlobeProjection();

  // Scale tracking for pinch gesture.
  double _baseScale = 1.0;

  // Canvas size captured from the LayoutBuilder for tap resolution.
  Size _canvasSize = Size.zero;

  // Track last focal point for single-finger pan within onScaleUpdate.
  Offset _lastFocalPoint = Offset.zero;

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _projection.scale;
    _lastFocalPoint = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        // Multi-finger: update zoom scale only.
        _projection = _projection.copyWith(
          scale: (_baseScale * d.scale).clamp(0.8, 8.0),
        );
      } else {
        // Single-finger drag: update rotation from focal point delta.
        final delta = d.focalPoint - _lastFocalPoint;
        _projection = _projection.copyWith(
          rotLng: _projection.rotLng + delta.dx / 150.0,
          rotLat: (_projection.rotLat + delta.dy / 150.0)
              .clamp(-math.pi / 2, math.pi / 2),
        );
      }
    });
    _lastFocalPoint = d.focalPoint;
  }

  void _onTapUp(TapUpDetails d) {
    if (_canvasSize == Size.zero) return;
    final hit = _projection.inverseProject(d.localPosition, _canvasSize);
    if (hit == null) return;
    final isoCode = resolveCountry(hit.$1, hit.$2);
    if (isoCode != null) widget.onCountryTap(isoCode);
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    final visualStates = ref.watch(countryVisualStatesProvider);
    final tripCountsAsync = ref.watch(countryTripCountsProvider);
    final tripCounts = tripCountsAsync.valueOrNull ?? const <String, int>{};

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapUp: _onTapUp,
          child: CustomPaint(
            size: _canvasSize,
            painter: GlobePainter(
              polygons: polygons,
              visualStates: visualStates,
              tripCounts: tripCounts,
              projection: _projection,
            ),
          ),
        );
      },
    );
  }
}
