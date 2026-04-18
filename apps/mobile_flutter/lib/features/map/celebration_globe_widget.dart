import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'country_centroids.dart';
import 'country_visual_state.dart';
import 'globe_painter.dart';
import 'globe_projection.dart';

/// Non-interactive animated globe shown inside [DiscoveryOverlay] (ADR-123).
///
/// Plays a 3-phase animation when first mounted:
/// - Phase 1 (~0.8s): fast spin
/// - Phase 2 (~1.4s): smooth travel to the target country centroid
/// - Phase 3 (ongoing): pulsing halo on the highlighted country
///
/// Sources polygon/visual-state data from Riverpod.
/// Respects [MediaQuery.disableAnimationsOf]: if true, shows the final
/// static state immediately.
class CelebrationGlobeWidget extends ConsumerStatefulWidget {
  const CelebrationGlobeWidget({
    super.key,
    required this.isoCode,
    this.height = 260.0,
  });

  /// ISO 3166-1 alpha-2 code of the country to animate toward.
  final String isoCode;

  /// Height of the globe in logical pixels.
  final double height;

  @override
  ConsumerState<CelebrationGlobeWidget> createState() =>
      _CelebrationGlobeWidgetState();
}

class _CelebrationGlobeWidgetState extends ConsumerState<CelebrationGlobeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;

  /// Current globe orientation.
  GlobeProjection _projection = const GlobeProjection();

  /// Pulse value 0.0–1.0 for the halo.
  double _pulseValue = 0.0;

  /// Phase 1 ends after a brief 120° eastward flick (1/3 rotation).
  /// Kept small so the globe does not over-spin before settling (ADR-126).
  static const _kSpinEndLng = 2 * math.pi / 3; // 120° east
  static const _kSpinEndLat = 0.25;

  /// Target orientation derived from centroid.
  late final double _targetLng;
  late final double _targetLat;

  bool _animationStarted = false;

  static const _kSpinEnd = 0.15; // Phase 1 ends at 15% (~420ms)
  static const _kTravelEnd = 0.80; // Phase 2 ends at 80% (~2240ms)
  static const _kMainDuration = Duration(milliseconds: 2800);
  static const _kPulseDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();

    final centroid = kCountryCentroids[widget.isoCode];
    if (centroid != null) {
      // Convert degrees → radians for GlobeProjection.
      _targetLat = centroid.$1 * math.pi / 180.0;
      // Normalise target longitude so the globe always travels eastward from
      // the spin-end position. If the target is west of _kSpinEndLng, add 2π
      // so we complete the eastward lap rather than reversing (ADR-126).
      final rawLng = centroid.$2 * math.pi / 180.0;
      _targetLng = rawLng < _kSpinEndLng ? rawLng + 2 * math.pi : rawLng;
    } else {
      _targetLat = 0.25;
      _targetLng = _kSpinEndLng + math.pi; // halfway around east
    }

    _mainController = AnimationController(
      vsync: this,
      duration: _kMainDuration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: _kPulseDuration,
    );

    _mainController.addListener(_onMainTick);
    _pulseController.addListener(_onPulseTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _jumpToFinalState();
    } else {
      _mainController.forward();
    }
  }

  void _jumpToFinalState() {
    setState(() {
      _projection = GlobeProjection(
        rotLat: _targetLat,
        rotLng: _targetLng,
        scale: 1.0,
      );
      _pulseValue = 0.5;
    });
  }

  void _onMainTick() {
    final t = _mainController.value;

    if (t <= _kSpinEnd) {
      // Phase 1: brief eastward flick (120°) with easeOut for a light tap of
      // momentum before the smooth travel begins (ADR-126).
      final spinT = Curves.easeOut.transform(t / _kSpinEnd);
      setState(() {
        _projection = GlobeProjection(
          rotLat: _kSpinEndLat,
          rotLng: spinT * _kSpinEndLng,
          scale: 1.0,
        );
      });
    } else if (t <= _kTravelEnd) {
      // Phase 2: smooth eastward travel from spin-end to centroid.
      // easeInOutCubic gives a premium deceleration-forward feel (ADR-126).
      final travelFraction = (t - _kSpinEnd) / (_kTravelEnd - _kSpinEnd);
      final travelT = Curves.easeInOutCubic.transform(travelFraction);
      setState(() {
        _projection = GlobeProjection(
          rotLat: _lerpDouble(_kSpinEndLat, _targetLat, travelT),
          rotLng: _lerpDouble(_kSpinEndLng, _targetLng, travelT),
          scale: 1.0,
        );
      });
    } else {
      // Phase 3: locked on centroid; start pulse.
      setState(() {
        _projection = GlobeProjection(
          rotLat: _targetLat,
          rotLng: _targetLng,
          scale: 1.0,
        );
      });
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  void _onPulseTick() {
    setState(() {
      _pulseValue = _pulseController.value;
    });
  }

  static double _lerpDouble(double a, double b, double t) =>
      a + (b - a) * t;

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    final visualStates = ref.watch(countryVisualStatesProvider);
    final tripCountsAsync = ref.watch(countryTripCountsProvider);
    final tripCounts = tripCountsAsync.valueOrNull ?? const <String, int>{};

    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: GlobePainter(
          polygons: polygons,
          visualStates: visualStates,
          tripCounts: tripCounts,
          projection: _projection,
          highlightedCode: widget.isoCode,
          pulseValue: _pulseValue,
        ),
      ),
    );
  }
}
