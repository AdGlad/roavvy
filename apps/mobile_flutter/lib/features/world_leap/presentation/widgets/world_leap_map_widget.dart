// lib/features/world_leap/presentation/widgets/world_leap_map_widget.dart
//
// M171: Performance overhaul — polygon layer is only rebuilt on game-state
// transitions, not on every 60 fps animation tick.
//
// Architecture:
//   • _staticPolygons, _currentPolygon, _targetPolygonPoints are pre-built
//     in _rebuildPolygonCaches(), called from _onStateChanged (not build()).
//   • AnimatedBuilder wraps only the animated sub-layers (target pulse,
//     origin ring, flight arc, splash ring), so each rebuilds at 60 fps
//     independently without touching the parent or the static layer.
//   • RepaintBoundary around the static PolygonLayer tells Flutter to skip
//     re-rasterizing it on animation frames.
//   • _trajectoryNotifier (ValueNotifier) replaces setState on aim drag,
//     so trajectory dots update without a full widget rebuild.

import 'dart:math' as math;

import 'package:country_lookup/country_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../application/world_leap_controller.dart';
import '../../application/world_leap_state.dart';
import '../../domain/models/world_leap_camera_mode.dart';
import '../../domain/models/world_leap_failure_reason.dart';
import '../../domain/models/world_leap_run.dart';
import '../../domain/services/world_leap_geo_service.dart';
import '../../world_leap_config.dart';

// ── Colour constants ─────────────────────────────────────────────────────────

const _kOceanColor        = Color(0xFF0D1B2A);
const _kUnvisitedFill     = Color(0xFF1E3A5F);
const _kUnvisitedBorder   = Color(0xFF2A4F7A);
const _kVisitedFill       = Color(0xFF3DBE6E);
const _kVisitedBorder     = Color(0xFF5DE88A);
const _kCurrentFill       = Color(0xFFFFD700);
const _kCurrentBorder     = Color(0xFFFFFFFF);
const _kTargetFill        = Color(0xFFE53935);
const _kTargetBorder      = Color(0xFFFF8A80);
// Vivid glow ring drawn at the target's centroid, independent of its polygon
// size/colour — guarantees the target is visible even when its fill colour
// is hard to distinguish from the ocean, or the country is too small to read
// at the current zoom (usability rework).
const _kTargetGlowColor   = Color(0xFFFF1744);
const _kTrajectoryColor   = Color(0xFFFFFFFF);
const _kFlightTrailColor  = Color(0xCCFFFFFF);
const _kProjectileColor   = Color(0xFFFFD700);

// ── Package-private helper (importable in tests) ──────────────────────────────

Color countryFillColor({
  required String isoCode,
  required String? currentCode,
  required Set<String> visitedCodes,
  String? targetCode,
  double targetPulse = 1.0,
}) {
  if (isoCode == currentCode) return _kCurrentFill;
  if (isoCode == targetCode) {
    // Pulse between two vivid reds — never dips into a dark tone that could
    // blend with the dark-navy ocean/unvisited fill (usability rework).
    return Color.lerp(const Color(0xFFC62828), _kTargetFill, targetPulse)!;
  }
  if (visitedCodes.contains(isoCode)) return _kVisitedFill;
  return _kUnvisitedFill;
}

// ── Widget ────────────────────────────────────────────────────────────────────

class WorldLeapMapWidget extends StatefulWidget {
  const WorldLeapMapWidget({
    super.key,
    required this.controller,
    required this.geo,
    this.slingshotActive,
    this.cameraMode = WorldLeapCameraMode.stationary,
  });

  final WorldLeapController controller;
  final WorldLeapGeoService geo;
  final ValueNotifier<bool>? slingshotActive;
  final WorldLeapCameraMode cameraMode;

  @override
  State<WorldLeapMapWidget> createState() => WorldLeapMapWidgetState();
}

class WorldLeapMapWidgetState extends State<WorldLeapMapWidget>
    with TickerProviderStateMixin {
  final _mapController = MapController();

  // ── Raw polygon data (loaded once) ──────────────────────────────────────────
  late final List<CountryPolygon> _allPolygons;
  late final List<List<LatLng>> _cachedPoints; // pre-converted, never changes

  // ── Pre-built polygon caches (rebuilt only on game-state changes) ──────────
  List<Polygon> _staticPolygons = [];  // ~248 countries: unvisited + visited
  Polygon? _currentPolygon;           // current (gold) — no animation
  List<LatLng>? _targetPolygonPoints; // target points — used in AnimatedBuilder
  String? _cachedCurrentCode;
  String? _cachedTargetCode;
  Set<String> _cachedVisitedCodes = {};

  // ── Trajectory (aim preview) — drives only the trajectory dot layer ─────────
  // Using ValueNotifier instead of setState so only the dot layer rebuilds.
  final _trajectoryNotifier = ValueNotifier<List<LatLng>>([]);

  // ── Animation controllers ────────────────────────────────────────────────────
  late final AnimationController _flightController;
  late final AnimationController _pulseController;
  late final AnimationController _splashController;

  // ── State flags (updated via setState, which is now rare) ──────────────────
  bool _isLaunching = false;
  LatLng? _splashPoint;
  List<LatLng> _missLine = [];
  bool _hasFlownToOrigin = false;

  // ── Public API (called from screen) ─────────────────────────────────────────

  void zoomIn() {
    final z = (_mapController.camera.zoom + 1.0).clamp(1.0, 8.0);
    _mapController.move(_mapController.camera.center, z);
  }

  void zoomOut() {
    final z = (_mapController.camera.zoom - 1.0).clamp(1.0, 8.0);
    _mapController.move(_mapController.camera.center, z);
  }

  bool isInCurrentCountry(Offset screenPos) {
    final latLng = _mapController.camera.pointToLatLng(
      math.Point<double>(screenPos.dx, screenPos.dy),
    );
    return widget.controller.isInCurrentCountry(
      latLng.latitude,
      latLng.longitude,
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _allPolygons = loadPolygons();
    _cachedPoints = [
      for (final p in _allPolygons)
        [for (final (lat, lng) in p.vertices) LatLng(lat, lng)],
    ];

    // Flight controller — no setState. AnimatedBuilder handles visual update.
    // Camera tracking (mapController.move) does not require setState.
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: WorldLeapConfig.launchAnimationMs),
    )..addListener(_onFlightTick);

    // Pulse controller — no addListener. AnimatedBuilder uses it directly.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Splash controller — no setState in tick. Status listener clears point.
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _splashPoint = null);
        }
      });

    widget.slingshotActive?.addListener(_onSlingshotActiveChanged);
    widget.controller.addListener(_onStateChanged);
    widget.controller.aimNotifier.addListener(_onAimChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStateChanged();
    });
  }

  @override
  void dispose() {
    widget.slingshotActive?.removeListener(_onSlingshotActiveChanged);
    widget.controller.removeListener(_onStateChanged);
    widget.controller.aimNotifier.removeListener(_onAimChanged);
    _trajectoryNotifier.dispose();
    _flightController.dispose();
    _pulseController.dispose();
    _splashController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Flight tick — camera tracking only, no setState ───────────────────────

  void _onFlightTick() {
    if (!widget.cameraMode.isTracking) return;
    final pts = _trajectoryNotifier.value;
    if (pts.isEmpty) return;
    final t = _flightController.value;
    final count = pts.length;
    final upTo = (t * count).clamp(0.0, count.toDouble()).round();
    if (upTo > 0) {
      _mapController.move(pts[upTo - 1], widget.cameraMode.zoomAt(t));
    }
  }

  void _onSlingshotActiveChanged() => setState(() {});

  // ── Aim drag — trajectory dots only, no full rebuild ──────────────────────

  void _onAimChanged() {
    final aim = widget.controller.aimNotifier.value;
    if (aim == null) {
      _trajectoryNotifier.value = [];
      return;
    }
    final state = widget.controller.state;
    if (state is! WorldLeapStateAiming) return;
    _computeTrajectory(state.run, aim.bearingDeg, aim.power);
  }

  void _computeTrajectory(
    WorldLeapRun run,
    double bearingDeg,
    double power,
  ) {
    final origin = _originFor(run);
    final distanceKm = (power * WorldLeapConfig.maxLaunchDistanceKm).clamp(
      WorldLeapConfig.minLaunchDistanceKm,
      WorldLeapConfig.maxLaunchDistanceKm,
    );
    final pts = widget.geo.trajectoryPoints(
      fromLat: origin.latitude,
      fromLon: origin.longitude,
      bearingDeg: bearingDeg,
      distanceKm: distanceKm,
      count: WorldLeapConfig.trajectoryDotCount,
    );
    // ValueNotifier update → only the ListenableBuilder rebuilds (not the map).
    _trajectoryNotifier.value = [for (final p in pts) LatLng(p.lat, p.lon)];
  }

  // ── Polygon cache — rebuilt only on game-state transitions ────────────────

  void _rebuildPolygonCaches(
    String? currentCode,
    String? targetCode,
    Set<String> visitedCodes,
  ) {
    if (_cachedCurrentCode == currentCode &&
        _cachedTargetCode == targetCode &&
        _cachedVisitedCodes.length == visitedCodes.length &&
        _cachedVisitedCodes.containsAll(visitedCodes)) {
      return; // Nothing changed — skip the O(n) loop.
    }
    _cachedCurrentCode = currentCode;
    _cachedTargetCode = targetCode;
    _cachedVisitedCodes = visitedCodes;

    final staticList = <Polygon>[];
    Polygon? currentPoly;
    List<LatLng>? targetPts;

    for (int i = 0; i < _allPolygons.length; i++) {
      final iso = _allPolygons[i].isoCode;
      if (iso == 'AQ') continue;
      final pts = _cachedPoints[i];

      if (iso == currentCode) {
        currentPoly = Polygon(
          points: pts,
          color: _kCurrentFill,
          borderColor: _kCurrentBorder,
          borderStrokeWidth: 1.5,
        );
      } else if (iso == targetCode) {
        targetPts = pts; // rendered animated in AnimatedBuilder
      } else {
        final visited = visitedCodes.contains(iso);
        staticList.add(
          Polygon(
            points: pts,
            color: visited ? _kVisitedFill : _kUnvisitedFill,
            borderColor: visited ? _kVisitedBorder : _kUnvisitedBorder,
            borderStrokeWidth: visited ? 1.0 : 0.4,
          ),
        );
      }
    }

    _staticPolygons = staticList;
    _currentPolygon = currentPoly;
    _targetPolygonPoints = targetPts;
  }

  // ── State change handler ──────────────────────────────────────────────────

  void _onStateChanged() {
    if (!mounted) return;
    final state = widget.controller.state;

    // Rebuild polygon caches whenever state (and thus run) changes.
    final run = _runFromState(state);
    _rebuildPolygonCaches(
      run?.currentCountryCode,
      widget.controller.targetCountryCode,
      run?.visitedCountryCodes ?? const {},
    );

    if (state is WorldLeapStateAiming) {
      if (!_hasFlownToOrigin) {
        _hasFlownToOrigin = true;
        _flyToShowBoth();
      }
      _flightController.stop();
      setState(() {
        _isLaunching = false;
        _missLine = [];
      });
      _trajectoryNotifier.value = [];
    } else if (state is WorldLeapStateLaunching) {
      _updateTrajectoryFromLaunching(state);
      setState(() {
        _isLaunching = true;
        _missLine = [];
      });
      _flightController.forward(from: 0);
    } else if (state is WorldLeapStateLanded) {
      _flightController.stop();
      _hasFlownToOrigin = false;
      setState(() {
        _isLaunching = false;
        _splashPoint = LatLng(
          state.lastLaunch.landingLat,
          state.lastLaunch.landingLon,
        );
        _missLine = [];
      });
      _trajectoryNotifier.value = [];
      _splashController.forward(from: 0);
      if (!widget.cameraMode.isTracking) {
        _mapController.move(
          LatLng(state.lastLaunch.landingLat, state.lastLaunch.landingLon),
          3.0,
        );
      }
    } else if (state is WorldLeapStateFailed) {
      _flightController.stop();
      _trajectoryNotifier.value = [];
      List<LatLng> missLine = [];
      if (state.reason == WorldLeapFailureReason.wrongCountry &&
          state.run.launches.isNotEmpty &&
          widget.controller.targetLocation != null) {
        missLine = [
          LatLng(
            state.run.launches.last.landingLat,
            state.run.launches.last.landingLon,
          ),
          LatLng(
            widget.controller.targetLocation!.lat,
            widget.controller.targetLocation!.lon,
          ),
        ];
      }
      setState(() {
        _isLaunching = false;
        _missLine = missLine;
      });
    } else {
      _flightController.stop();
      _trajectoryNotifier.value = [];
      setState(() {
        _isLaunching = false;
        _missLine = [];
      });
    }
  }

  void _updateTrajectoryFromLaunching(WorldLeapStateLaunching state) {
    final run = state.run;
    final origin = _originFor(run);
    final distanceKm = (state.power * WorldLeapConfig.maxLaunchDistanceKm)
        .clamp(
          WorldLeapConfig.minLaunchDistanceKm,
          WorldLeapConfig.maxLaunchDistanceKm,
        );
    final pts = widget.geo.trajectoryPoints(
      fromLat: origin.latitude,
      fromLon: origin.longitude,
      bearingDeg: state.bearingDeg,
      distanceKm: distanceKm,
      count: WorldLeapConfig.trajectoryDotCount,
    );
    _trajectoryNotifier.value = [for (final p in pts) LatLng(p.lat, p.lon)];
  }

  LatLng _originFor(WorldLeapRun run) {
    if (run.launches.isNotEmpty) {
      final last = run.launches.last;
      return LatLng(last.landingLat, last.landingLon);
    }
    final o = widget.controller.currentOrigin;
    return LatLng(o.lat, o.lon);
  }

  WorldLeapRun? _runFromState(WorldLeapState state) => switch (state) {
    WorldLeapStateAiming(:final run) => run,
    WorldLeapStateLaunching(:final run) => run,
    WorldLeapStateLanded(:final run) => run,
    WorldLeapStateFailed(:final run) => run,
    WorldLeapStateComplete(:final run) => run,
    WorldLeapStateLocked(:final run) => run,
    _ => null,
  };

  // ── Camera helpers ────────────────────────────────────────────────────────

  /// Minimum zoom so a small target country's polygon doesn't render too
  /// small to read, even when far from the launch origin. Combined with the
  /// distance-based zoom in [_flyToShowBoth] via [math.max] — whichever
  /// requires more zoom wins. Thresholds are rough country-diameter bands
  /// (degrees of lat/lon span), tuned against flutter_map's zoom scale.
  double _minZoomForTargetSize() {
    final pts = _targetPolygonPoints;
    if (pts == null || pts.isEmpty) return 1.0;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLon = pts.first.longitude, maxLon = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final span = math.max(maxLat - minLat, maxLon - minLon);
    if (span < 1.0) return 5.5;  // tiny — e.g. Luxembourg, Singapore
    if (span < 2.5) return 4.5;  // small — e.g. Belgium, Rwanda
    if (span < 5.0) return 3.5;  // medium-small
    return 1.0;                  // large countries — no extra minimum
  }

  void _flyToShowBoth() {
    final origin = widget.controller.currentOrigin;
    final target = widget.controller.targetLocation;

    if (target == null) {
      _mapController.move(LatLng(origin.lat, origin.lon), 3.5);
      return;
    }

    final midLat = (origin.lat + target.lat) / 2.0;
    double lonDiff = target.lon - origin.lon;
    if (lonDiff > 180) lonDiff -= 360;
    if (lonDiff < -180) lonDiff += 360;
    double midLon = origin.lon + lonDiff / 2.0;
    if (midLon > 180) midLon -= 360;
    if (midLon < -180) midLon += 360;

    final distKm = widget.controller.targetDistanceKm ?? 0;
    final distZoom = distKm > 14000 ? 1.3
        : distKm > 10000 ? 1.5
        : distKm > 7000  ? 1.8
        : distKm > 4000  ? 2.2
        : distKm > 2000  ? 2.8
        : distKm > 800   ? 3.5
        : 4.2;
    final zoom = math.max(distZoom, _minZoomForTargetSize());

    _mapController.move(LatLng(midLat, midLon), zoom);
  }

  // ── Animated layer builders (called inside AnimatedBuilder) ───────────────

  Widget _buildPulseLayers() {
    final pulse = _pulseController.value;
    final state = widget.controller.state;

    final layers = <Widget>[];

    // Animated target polygon (1 polygon, not ~250). Pulses between two
    // vivid reds — never a dark tone that could blend with the ocean.
    final targetPts = _targetPolygonPoints;
    if (targetPts != null) {
      layers.add(
        PolygonLayer(
          polygonCulling: true,
          polygons: [
            Polygon(
              points: targetPts,
              color: Color.lerp(
                const Color(0xFFC62828),
                _kTargetFill,
                pulse,
              )!,
              borderColor: _kTargetBorder,
              borderStrokeWidth: 3.0,
            ),
          ],
        ),
      );
    }

    // Glow ring + core dot at the target's centroid — visible regardless of
    // the target polygon's size or fill colour, so a tiny or hard-to-see
    // target country is still unmistakable (usability rework).
    final targetLoc = widget.controller.targetLocation;
    if (targetLoc != null) {
      layers.add(
        CircleLayer(
          circles: [
            CircleMarker(
              point: LatLng(targetLoc.lat, targetLoc.lon),
              radius: 26 + pulse * 16,
              useRadiusInMeter: false,
              color: Colors.transparent,
              borderColor:
                  _kTargetGlowColor.withValues(alpha: 0.85 - pulse * 0.35),
              borderStrokeWidth: 3.5,
            ),
            CircleMarker(
              point: LatLng(targetLoc.lat, targetLoc.lon),
              radius: 9,
              useRadiusInMeter: false,
              color: _kTargetGlowColor.withValues(alpha: 0.95),
            ),
          ],
        ),
      );
    }

    // Origin pulse ring (Aiming, not launching).
    if (!_isLaunching && state is WorldLeapStateAiming) {
      final o = widget.controller.currentOrigin;
      layers.add(
        CircleLayer(
          circles: [
            CircleMarker(
              point: LatLng(o.lat, o.lon),
              radius: 18 + pulse * 12,
              useRadiusInMeter: false,
              color: Colors.transparent,
              borderColor: _kCurrentFill.withValues(alpha: 0.6 - pulse * 0.4),
              borderStrokeWidth: 2.5,
            ),
            CircleMarker(
              point: LatLng(o.lat, o.lon),
              radius: 6,
              useRadiusInMeter: false,
              color: _kCurrentFill.withValues(alpha: 0.85),
            ),
          ],
        ),
      );
    }

    return Stack(children: layers);
  }

  Widget _buildFlightLayer() {
    final pts = _trajectoryNotifier.value;
    final count = pts.length;
    if (!_isLaunching || count == 0) return const SizedBox.shrink();

    final t = _flightController.value;
    final upTo = (t * count).clamp(0.0, count.toDouble()).round();

    // Comet tail: up to 8 fading dots behind the projectile.
    const tailLength = 8;
    final tailCircles = <CircleMarker>[];
    for (var i = 1; i <= tailLength && upTo - i - 1 >= 0; i++) {
      final fade = 1.0 - (i / tailLength);
      tailCircles.add(CircleMarker(
        point: pts[upTo - i - 1],
        radius: 7.0 * fade,
        color: _kProjectileColor.withValues(alpha: fade * 0.8),
      ));
    }

    return Stack(
      children: [
        if (upTo >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: pts.sublist(0, upTo),
                color: _kFlightTrailColor,
                strokeWidth: 2.0,
              ),
            ],
          ),
        if (tailCircles.isNotEmpty) CircleLayer(circles: tailCircles),
        if (upTo > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: pts[upTo - 1],
                radius: 7,
                color: _kProjectileColor,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSplashLayer() {
    final sp = _splashPoint;
    if (sp == null) return const SizedBox.shrink();
    final t = _splashController.value;
    return CircleLayer(
      circles: [
        CircleMarker(
          point: sp,
          radius: t * 40 + 8,
          useRadiusInMeter: false,
          color: Colors.white.withValues(alpha: (1.0 - t) * 0.6),
          borderColor: Colors.white.withValues(alpha: (1.0 - t) * 0.9),
          borderStrokeWidth: 2,
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // build() is now only called on game-state transitions (setState), not on
    // every animation frame. Polygon lists are pre-built in _rebuildPolygonCaches.
    return ColoredBox(
      color: _kOceanColor,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(20, 0),
          initialZoom: 1.5,
          minZoom: 1.0,
          maxZoom: 8.0,
          backgroundColor: _kOceanColor,
          interactionOptions: InteractionOptions(
            flags: (widget.slingshotActive?.value ?? false)
                ? InteractiveFlag.pinchZoom
                : InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          // ① Static polygons — RepaintBoundary skips re-rasterisation on
          //   animation frames. Only invalidated by game-state setState calls.
          RepaintBoundary(
            child: PolygonLayer(
              polygonCulling: true,
              polygons: _staticPolygons,
            ),
          ),

          // ② Current country (gold) — static color, no animation.
          if (_currentPolygon != null)
            PolygonLayer(polygons: [_currentPolygon!]),

          // ③ Target polygon + origin ring — both use _pulseController.
          //   Only ~1–2 objects rebuilt at 60 fps instead of ~250.
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => _buildPulseLayers(),
          ),

          // ④ Trajectory dots — ValueNotifier; only this layer rebuilds on drag.
          ListenableBuilder(
            listenable: _trajectoryNotifier,
            builder: (_, __) {
              final pts = _trajectoryNotifier.value;
              if (pts.isEmpty || _isLaunching) return const SizedBox.shrink();
              return CircleLayer(
                circles: [
                  for (final pt in pts)
                    CircleMarker(
                      point: pt,
                      radius: 3,
                      color: _kTrajectoryColor.withValues(alpha: 0.8),
                    ),
                ],
              );
            },
          ),

          // ⑤ Flight arc + projectile — scoped to _flightController.
          AnimatedBuilder(
            animation: _flightController,
            builder: (_, __) => _buildFlightLayer(),
          ),

          // ⑥ Splash ring — scoped to _splashController.
          AnimatedBuilder(
            animation: _splashController,
            builder: (_, __) => _buildSplashLayer(),
          ),

          // ⑦ Miss line — static between state changes, no animation.
          if (_missLine.length == 2) ...[
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _missLine,
                  color: Colors.orange.withValues(alpha: 0.7),
                  strokeWidth: 2.0,
                  pattern: StrokePattern.dashed(segments: [8, 6]),
                ),
              ],
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _missLine.last,
                  radius: 8,
                  color: Colors.orange.withValues(alpha: 0.3),
                  borderColor: Colors.orange,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
