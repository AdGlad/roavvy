// lib/features/world_leap/presentation/widgets/world_leap_map_widget.dart

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

// ── Extra colour constants ────────────────────────────────────────────────────

const _kFlightTrailColor = Color(0xCCFFFFFF); // semi-transparent white
const _kProjectileColor = Color(0xFFFFD700);  // gold

// ── Colour constants ─────────────────────────────────────────────────────────

const _kOceanColor = Color(0xFF0D1B2A);
const _kUnvisitedFill = Color(0xFF1E3A5F);
const _kUnvisitedBorder = Color(0xFF2A4F7A);
const _kVisitedFill = Color(0xFF3DBE6E);
const _kVisitedBorder = Color(0xFF5DE88A);
const _kCurrentFill = Color(0xFFFFD700);
const _kCurrentBorder = Color(0xFFFFFFFF);
const _kTargetFill = Color(0xFFE53935);
const _kTargetBorder = Color(0xFFFF8A80);
const _kTrajectoryColor = Color(0xFFFFFFFF);

// ── Package-private helper (importable in tests) ──────────────────────────────

/// Determines the fill colour for a country polygon given the current run state.
Color countryFillColor({
  required String isoCode,
  required String? currentCode,
  required Set<String> visitedCodes,
  String? targetCode,
  double targetPulse = 1.0, // 0.0–1.0 animation value for target pulse
}) {
  if (isoCode == currentCode) return _kCurrentFill;
  if (isoCode == targetCode) {
    // Pulse between bright red and a darker red.
    return Color.lerp(
      const Color(0xFF8B0000),
      _kTargetFill,
      targetPulse,
    )!;
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

  /// When true, the map's drag interaction is suppressed so the slingshot
  /// can own the pan gesture without the map also panning.
  final ValueNotifier<bool>? slingshotActive;

  /// Camera behaviour during the slingshot flight arc.
  final WorldLeapCameraMode cameraMode;

  @override
  State<WorldLeapMapWidget> createState() => WorldLeapMapWidgetState();
}

class WorldLeapMapWidgetState extends State<WorldLeapMapWidget>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  List<CountryPolygon> _allPolygons = [];
  List<LatLng> _trajectoryPoints = [];

  // ── Flight animation ────────────────────────────────────────────────────────
  late final AnimationController _flightController;
  double _flightProgress = 0.0;
  bool _isLaunching = false;

  // ── Target pulse animation ──────────────────────────────────────────────────
  late final AnimationController _pulseController;

  // ── Landing splash animation ─────────────────────────────────────────────
  late final AnimationController _splashController;
  LatLng? _splashPoint;

  // ── Miss line ────────────────────────────────────────────────────────────
  List<LatLng> _missLine = [];

  // ── Zoom ────────────────────────────────────────────────────────────────────

  void zoomIn() {
    final z = (_mapController.camera.zoom + 1.0).clamp(1.0, 8.0);
    _mapController.move(_mapController.camera.center, z);
  }

  void zoomOut() {
    final z = (_mapController.camera.zoom - 1.0).clamp(1.0, 8.0);
    _mapController.move(_mapController.camera.center, z);
  }

  @override
  void initState() {
    super.initState();
    _allPolygons = loadPolygons();

    _flightController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: WorldLeapConfig.launchAnimationMs),
    )..addListener(() {
        final t = _flightController.value;
        setState(() => _flightProgress = t);
        // Move camera to track the projectile during flight.
        if (widget.cameraMode.isTracking && _trajectoryPoints.isNotEmpty) {
          final count = _trajectoryPoints.length;
          final upTo = (t * count).clamp(0.0, count.toDouble()).round();
          if (upTo > 0) {
            _mapController.move(
              _trajectoryPoints[upTo - 1],
              widget.cameraMode.zoomAt(t),
            );
          }
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..repeat(reverse: true)
      ..addListener(() => setState(() {}));

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _splashPoint = null);
        }
      });

    widget.slingshotActive?.addListener(_onSlingshotActiveChanged);
    widget.controller.addListener(_onStateChanged);

    // The controller may already be in Aiming state (initialize() completed
    // before this widget was built). Schedule a state-sync so the map flies
    // to the start country on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStateChanged();
    });
  }

  void _onSlingshotActiveChanged() => setState(() {});

  /// Returns true if [screenPos] (in local widget coordinates) maps to the
  /// current source country — used by the slingshot as a hit test.
  bool isInCurrentCountry(Offset screenPos) {
    final latLng = _mapController.camera.pointToLatLng(
      math.Point<double>(screenPos.dx, screenPos.dy),
    );
    return widget.controller.isInCurrentCountry(latLng.latitude, latLng.longitude);
  }

  @override
  void dispose() {
    widget.slingshotActive?.removeListener(_onSlingshotActiveChanged);
    widget.controller.removeListener(_onStateChanged);
    _flightController.dispose();
    _pulseController.dispose();
    _splashController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool _hasFlownToOrigin = false;

  void _onStateChanged() {
    final state = widget.controller.state;

    if (state is WorldLeapStateAiming) {
      // Centre the map to show both the origin and the target country.
      if (!_hasFlownToOrigin) {
        _hasFlownToOrigin = true;
        _flyToShowBoth();
      }
      _stopFlight();
      _updateTrajectory(state);
      setState(() => _missLine = []);
    } else if (state is WorldLeapStateLaunching) {
      _updateTrajectoryFromLaunching(state);
      _startFlight();
      setState(() => _missLine = []);
    } else if (state is WorldLeapStateLanded) {
      _stopFlight();
      _clearTrajectory();
      // Reset flag so the next Aiming state re-centres on both countries.
      _hasFlownToOrigin = false;
      setState(() {
        _splashPoint = LatLng(state.lastLaunch.landingLat, state.lastLaunch.landingLon);
        _missLine = [];
      });
      _splashController.forward(from: 0);
      // Skip fly-to when tracking: camera already arrived at the landing spot.
      if (!widget.cameraMode.isTracking) {
        _flyTo(state.lastLaunch.landingLat, state.lastLaunch.landingLon, zoom: 3.0);
      }
    } else if (state is WorldLeapStateFailed) {
      _stopFlight();
      _clearTrajectory();
      if (state.reason == WorldLeapFailureReason.wrongCountry &&
          state.run.launches.isNotEmpty &&
          widget.controller.targetLocation != null) {
        setState(() {
          _missLine = [
            LatLng(state.run.launches.last.landingLat, state.run.launches.last.landingLon),
            LatLng(widget.controller.targetLocation!.lat, widget.controller.targetLocation!.lon),
          ];
        });
      } else {
        setState(() => _missLine = []);
      }
    } else {
      _stopFlight();
      _clearTrajectory();
      setState(() => _missLine = []);
    }
  }

  void _startFlight() {
    setState(() {
      _isLaunching = true;
      _flightProgress = 0.0;
    });
    _flightController.forward(from: 0);
  }

  void _stopFlight() {
    _flightController.stop();
    setState(() {
      _isLaunching = false;
      _flightProgress = 0.0;
    });
  }

  void _updateTrajectory(WorldLeapStateAiming state) {
    final run = state.run;
    if (state.bearingDeg == null || state.power == null) {
      setState(() => _trajectoryPoints = []);
      return;
    }

    final origin = _originFor(run);
    final distanceKm = (state.power! * WorldLeapConfig.maxLaunchDistanceKm)
        .clamp(WorldLeapConfig.minLaunchDistanceKm, WorldLeapConfig.maxLaunchDistanceKm);

    final pts = widget.geo.trajectoryPoints(
      fromLat: origin.latitude,
      fromLon: origin.longitude,
      bearingDeg: state.bearingDeg!,
      distanceKm: distanceKm,
      count: WorldLeapConfig.trajectoryDotCount,
    );

    setState(() {
      _trajectoryPoints = [for (final p in pts) LatLng(p.lat, p.lon)];
    });
  }

  void _updateTrajectoryFromLaunching(WorldLeapStateLaunching state) {
    final run = state.run;
    final origin = _originFor(run);
    final distanceKm = (state.power * WorldLeapConfig.maxLaunchDistanceKm)
        .clamp(WorldLeapConfig.minLaunchDistanceKm, WorldLeapConfig.maxLaunchDistanceKm);

    final pts = widget.geo.trajectoryPoints(
      fromLat: origin.latitude,
      fromLon: origin.longitude,
      bearingDeg: state.bearingDeg,
      distanceKm: distanceKm,
      count: WorldLeapConfig.trajectoryDotCount,
    );

    setState(() {
      _trajectoryPoints = [for (final p in pts) LatLng(p.lat, p.lon)];
    });
  }

  void _clearTrajectory() {
    if (_trajectoryPoints.isNotEmpty) {
      setState(() => _trajectoryPoints = []);
    }
  }

  LatLng _originFor(WorldLeapRun run) {
    if (run.launches.isNotEmpty) {
      final last = run.launches.last;
      return LatLng(last.landingLat, last.landingLon);
    }
    final o = widget.controller.currentOrigin;
    return LatLng(o.lat, o.lon);
  }

  void _flyTo(double lat, double lon, {double zoom = 3.5}) {
    _mapController.move(LatLng(lat, lon), zoom);
  }

  /// Flies the map to show both the current origin and the target country.
  /// Centres on the midpoint of the two locations and picks a zoom level
  /// that keeps both visible.
  void _flyToShowBoth() {
    final origin = widget.controller.currentOrigin;
    final target = widget.controller.targetLocation;

    if (target == null) {
      // No target yet — just centre on origin at a comfortable zoom.
      _flyTo(origin.lat, origin.lon, zoom: 3.5);
      return;
    }

    // ── Midpoint (handles antimeridian correctly) ────────────────────────────
    final midLat = (origin.lat + target.lat) / 2.0;

    double lonDiff = target.lon - origin.lon;
    if (lonDiff > 180) lonDiff -= 360;
    if (lonDiff < -180) lonDiff += 360;
    double midLon = origin.lon + lonDiff / 2.0;
    if (midLon > 180) midLon -= 360;
    if (midLon < -180) midLon += 360;

    // ── Zoom based on great-circle distance ──────────────────────────────────
    final distKm = widget.controller.targetDistanceKm ?? 0;
    final double zoom;
    if (distKm > 14000) {
      zoom = 1.3;
    } else if (distKm > 10000) {
      zoom = 1.5;
    } else if (distKm > 7000) {
      zoom = 1.8;
    } else if (distKm > 4000) {
      zoom = 2.2;
    } else if (distKm > 2000) {
      zoom = 2.8;
    } else if (distKm > 800) {
      zoom = 3.5;
    } else {
      zoom = 4.2;
    }

    _flyTo(midLat, midLon, zoom: zoom);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final run = state is WorldLeapStateAiming ? state.run
        : state is WorldLeapStateLaunching ? state.run
        : state is WorldLeapStateLanded ? state.run
        : state is WorldLeapStateFailed ? state.run
        : state is WorldLeapStateComplete ? state.run
        : state is WorldLeapStateLocked ? state.run
        : null;

    final currentCode = run?.currentCountryCode;
    final visitedCodes = run?.visitedCountryCodes ?? const <String>{};
    final targetCode = widget.controller.targetCountryCode;
    final pulse = _pulseController.value;

    final polygons = [
      for (final p in _allPolygons)
        if (p.isoCode != 'AQ') // suppress Antarctica
          Polygon(
            points: [for (final (lat, lng) in p.vertices) LatLng(lat, lng)],
            color: countryFillColor(
              isoCode: p.isoCode,
              currentCode: currentCode,
              visitedCodes: visitedCodes,
              targetCode: targetCode,
              targetPulse: pulse,
            ),
            borderColor: p.isoCode == currentCode
                ? _kCurrentBorder
                : p.isoCode == targetCode
                    ? _kTargetBorder
                    : visitedCodes.contains(p.isoCode)
                        ? _kVisitedBorder
                        : _kUnvisitedBorder,
            borderStrokeWidth: p.isoCode == currentCode ? 1.5
                : p.isoCode == targetCode ? 2.0
                : 0.4,
          ),
    ];

    // ── "Drag from here" pulse ring on origin (Aiming only) ──────────────────
    final originPulse = (!_isLaunching && state is WorldLeapStateAiming)
        ? () {
            final o = widget.controller.currentOrigin;
            final pulse = _pulseController.value; // 0→1→0
            return [
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
            ];
          }()
        : <CircleMarker>[];

    // ── Aim-preview dots (Aiming only) ─────────────────────────────────────
    final aimMarkers = _isLaunching
        ? <CircleMarker>[]
        : [
            for (final pt in _trajectoryPoints)
              CircleMarker(
                point: pt,
                radius: 3,
                color: _kTrajectoryColor.withValues(alpha: 0.8),
              ),
          ];

    // ── Animated flight arc (Launching only) ────────────────────────────────
    final count = _trajectoryPoints.length;
    final upTo = _isLaunching
        ? (_flightProgress * count).clamp(0.0, count.toDouble()).round()
        : 0;

    final flightTrail = upTo >= 2
        ? [
            Polyline(
              points: _trajectoryPoints.sublist(0, upTo),
              color: _kFlightTrailColor,
              strokeWidth: 2.0,
            ),
          ]
        : <Polyline>[];

    final projectile = upTo > 0
        ? [
            CircleMarker(
              point: _trajectoryPoints[upTo - 1],
              radius: 7,
              color: _kProjectileColor,
            ),
          ]
        : <CircleMarker>[];

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
          // Drag is suppressed while the slingshot is actively tracking a
          // gesture on the source country. Otherwise drag is enabled so the
          // user can pan by touching anywhere outside the source country.
          interactionOptions: InteractionOptions(
            flags: (widget.slingshotActive?.value ?? false)
                ? InteractiveFlag.pinchZoom
                : InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          PolygonLayer(polygonCulling: true, polygons: polygons),
          if (originPulse.isNotEmpty) CircleLayer(circles: originPulse),
          if (aimMarkers.isNotEmpty) CircleLayer(circles: aimMarkers),
          if (flightTrail.isNotEmpty) PolylineLayer(polylines: flightTrail),
          if (projectile.isNotEmpty) CircleLayer(circles: projectile),
          if (_splashPoint != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _splashPoint!,
                radius: _splashController.value * 40 + 8,
                useRadiusInMeter: false,
                color: Colors.white.withValues(alpha: (1.0 - _splashController.value) * 0.6),
                borderColor: Colors.white.withValues(alpha: (1.0 - _splashController.value) * 0.9),
                borderStrokeWidth: 2,
              ),
            ]),
          if (_missLine.length == 2) ...[
            PolylineLayer(polylines: [
              Polyline(
                points: _missLine,
                color: Colors.orange.withValues(alpha: 0.7),
                strokeWidth: 2.0,
                pattern: StrokePattern.dashed(segments: [8, 6]),
              ),
            ]),
            CircleLayer(circles: [
              CircleMarker(
                point: _missLine.last,
                radius: 8,
                color: Colors.orange.withValues(alpha: 0.3),
                borderColor: Colors.orange,
                borderStrokeWidth: 2,
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
