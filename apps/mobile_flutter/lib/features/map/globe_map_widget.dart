import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'country_visual_state.dart';
import 'globe_painter.dart';
import 'globe_projection.dart';

// Total zoom sequence duration: zoom-in 400 ms + hold 5 000 ms + zoom-out 1 500 ms.
const _kZoomInMs   = 400;
const _kHoldMs     = 5000;
const _kZoomOutMs  = 1500;
const _kZoomTotalMs = _kZoomInMs + _kHoldMs + _kZoomOutMs; // 6 900

/// Interactive 3D globe widget (ADR-116).
///
/// - Drag → rotate. Pinch → zoom.
/// - Auto-rotation: slow east→west (~5°/sec), pauses 2 s after interaction.
/// - Flag-strip tap: [globeTargetProvider] → 900 ms rotation snap, then
///   zoom-in to 2.0× (400 ms) → hold (5 s) → slow zoom-out to 1.0 (1 500 ms).
///   Auto-rotation resumes after the full zoom sequence. (M86)
class GlobeMapWidget extends ConsumerStatefulWidget {
  const GlobeMapWidget({super.key, required this.onCountryTap});

  final void Function(String isoCode) onCountryTap;

  @override
  ConsumerState<GlobeMapWidget> createState() => _GlobeMapWidgetState();
}

class _GlobeMapWidgetState extends ConsumerState<GlobeMapWidget>
    with TickerProviderStateMixin {
  GlobeProjection _projection = const GlobeProjection();

  double _baseScale = 1.0;
  Size _canvasSize = Size.zero;
  Offset _lastFocalPoint = Offset.zero;

  // ── Auto-rotation & Physics ────────────────────────────────────────────────

  static const _kRotationScale = 150.0; // pixels to radians divisor
  static const _kIdleVelocity = -0.0015; // ~5°/sec east→west

  late final Ticker _rotationTicker;
  bool _isInteracting = false;
  Offset _velocity = Offset.zero; // radians per tick
  Duration _lastTickTime = Duration.zero;

  // ── Rotation snap (900 ms — rotLng + rotLat only) ─────────────────────────

  late final AnimationController _snapController;
  (Animation<double>, Animation<double>)? _snapAnims; // (rotLng, rotLat)

  // ── Zoom sequence (6 900 ms — scale only) ─────────────────────────────────

  late final AnimationController _zoomController;
  Animation<double>? _zoomAnim;

  @override
  void initState() {
    super.initState();

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onSnapTick);

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kZoomTotalMs),
    )..addListener(_onZoomTick);

    _rotationTicker = createTicker(_onRotationTick)..start();
  }

  @override
  void dispose() {
    _rotationTicker.dispose();
    _snapController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  // ── Rotation ticker ────────────────────────────────────────────────────────

  void _onRotationTick(Duration elapsed) {
    final dt = elapsed - _lastTickTime;
    _lastTickTime = elapsed;

    if (_isInteracting ||
        _snapController.isAnimating ||
        _zoomController.isAnimating) {
      return;
    }

    if (dt.inMilliseconds > 120) return; // skip jump-frames on resume
    final dtSec = dt.inMicroseconds / 1000000.0;

    // 1. Apply Friction
    // Exponential decay: v = v * friction^dt
    // 0.05 means velocity drops to 5% after 1 second.
    const friction = 0.05;
    _velocity *= math.pow(friction, dtSec).toDouble();

    // 2. Blend with Idle Spin
    // We want to smoothly transition back to the constant -0.0015 radians/tick.
    // Convert idle velocity to radians/sec for consistency.
    // Current loop is ~60fps, so 0.0015 * 60 = ~0.09 rad/sec.
    const idleRadSec = _kIdleVelocity * 60.0;
    const blendThreshold = 0.2; // rad/sec

    double targetLngV = _velocity.dx;
    double targetLatV = _velocity.dy;

    if (_velocity.distance < blendThreshold) {
      // Smoothly interpolate towards idle spin (horizontal only).
      // vertical velocity should trend to zero.
      targetLngV = ui.lerpDouble(targetLngV, idleRadSec, 0.1)!;
      targetLatV = ui.lerpDouble(targetLatV, 0.0, 0.1)!;
      _velocity = Offset(targetLngV, targetLatV);
    }

    // 3. Integrate
    double newLng = _projection.rotLng + _velocity.dx * dtSec;
    double newLat = (_projection.rotLat + _velocity.dy * dtSec)
        .clamp(-math.pi / 2, math.pi / 2);

    // 4. Normalize Longitude to [-pi, pi]
    newLng = ((newLng + math.pi) % (2 * math.pi)) - math.pi;

    setState(() {
      _projection = _projection.copyWith(
        rotLng: newLng,
        rotLat: newLat,
      );
    });
  }

  // ── Snap tick (rotation only) ──────────────────────────────────────────────

  void _onSnapTick() {
    final anims = _snapAnims;
    if (anims == null) return;
    setState(() {
      _projection = _projection.copyWith(
        rotLng: anims.$1.value,
        rotLat: anims.$2.value,
      );
    });
  }

  // ── Zoom tick (scale only) ─────────────────────────────────────────────────

  void _onZoomTick() {
    final anim = _zoomAnim;
    if (anim == null) return;
    setState(() {
      _projection = _projection.copyWith(scale: anim.value);
    });
  }

  // ── Animate to country ─────────────────────────────────────────────────────

  void _animateTo(double lat, double lng) {
    _velocity = Offset.zero;
    final targetRotLng = -lng * math.pi / 180.0;
    final targetRotLat = lat * math.pi / 180.0;

    // Shortest angular path.
    final currentRotLng = _projection.rotLng;
    final rawDiff = targetRotLng - currentRotLng;
    final diff = ((rawDiff + math.pi) % (2 * math.pi)) - math.pi;

    _snapAnims = (
      Tween<double>(begin: currentRotLng, end: currentRotLng + diff)
          .animate(CurvedAnimation(parent: _snapController, curve: Curves.easeInOut)),
      Tween<double>(
        begin: _projection.rotLat,
        end: targetRotLat.clamp(-math.pi / 2, math.pi / 2),
      ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeInOut)),
    );

    // Scale: zoom-in → hold → slow zoom-out.
    // Weights (must sum to 100): proportional to ms durations.
    final wIn  = _kZoomInMs  / _kZoomTotalMs * 100; // ~5.8
    final wHold = _kHoldMs   / _kZoomTotalMs * 100; // ~72.5
    final wOut = _kZoomOutMs / _kZoomTotalMs * 100; // ~21.7
    final startScale = _projection.scale;

    _zoomAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: startScale, end: 2.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: wIn,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.0, end: 2.0), // hold
        weight: wHold,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: wOut,
      ),
    ]).animate(_zoomController);

    _snapController..reset()..forward();
    _zoomController..reset()..forward();
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _projection.scale;
    _lastFocalPoint = d.focalPoint;
    _isInteracting = true;
    _velocity = Offset.zero;
    _snapController.stop();
    _zoomController.stop();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _projection = _projection.copyWith(
          scale: (_baseScale * d.scale).clamp(0.8, 8.0),
        );
      } else {
        final delta = d.focalPoint - _lastFocalPoint;
        _projection = _projection.copyWith(
          rotLng: _projection.rotLng + delta.dx / _kRotationScale,
          rotLat: (_projection.rotLat + delta.dy / _kRotationScale)
              .clamp(-math.pi / 2, math.pi / 2),
        );
      }
    });
    _lastFocalPoint = d.focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _isInteracting = false;
    // Capture velocity in radians per SECOND, then convert to per TICK (approx).
    // Note: We integrate in _onRotationTick using dt.
    final pixelsPerSec = d.velocity.pixelsPerSecond;
    _velocity = Offset(
      pixelsPerSec.dx / _kRotationScale,
      pixelsPerSec.dy / _kRotationScale,
    );

    // Limit extreme velocity to prevent "nausea" spins.
    const maxV = 10.0;
    if (_velocity.distance > maxV) {
      _velocity = Offset.fromDirection(_velocity.direction, maxV);
    }
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
    final tripCounts =
        ref.watch(countryTripCountsProvider).valueOrNull ?? const <String, int>{};

    ref.listen<(double, double)?>(globeTargetProvider, (_, target) {
      if (target != null) {
        _animateTo(target.$1, target.$2);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(globeTargetProvider.notifier).state = null;
        });
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
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
