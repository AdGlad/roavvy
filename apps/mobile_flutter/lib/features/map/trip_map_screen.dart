import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';

// ── Colours (match CountryPolygonLayer, ADR-080) ──────────────────────────────

const _kOceanBackground = Color(0xFF0D2137);
const _kVisitedFill = Color(0xFFD4A017);     // amber tier-1 (depthFillColor(1))
const _kUnvisitedFill = Color(0xFF1E3A5F);   // dark navy land

// ── Helpers ───────────────────────────────────────────────────────────────────

String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + isoCode.codeUnitAt(0) - 65) +
      String.fromCharCode(base + isoCode.codeUnitAt(1) - 65);
}

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtMonth(DateTime dt) => '${_kMonths[dt.month - 1]} ${dt.year}';

String _tripDateRange(DateTime start, DateTime end) {
  final s = _fmtMonth(start);
  final e = _fmtMonth(end);
  return s == e ? s : '$s – $e';
}

// ── TripMapScreen ─────────────────────────────────────────────────────────────

/// Full-screen country map showing the regions visited on [trip].
///
/// All region polygons for [trip.countryCode] are fetched synchronously from
/// the already-initialised `region_lookup` package. Visited region codes are
/// resolved asynchronously via [RegionRepository.loadRegionCodesForTrip].
///
/// Visited regions are rendered in amber (depth tier-1); unvisited regions are
/// rendered in dark navy — matching the main map theme (ADR-090).
///
/// The camera auto-fits to the country bounding box on first load.
class TripMapScreen extends ConsumerStatefulWidget {
  const TripMapScreen({super.key, required this.trip});

  final TripRecord trip;

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  final _mapController = MapController();
  late final List<RegionPolygon> _allPolygons;
  late final Future<List<String>> _visitedCodesFuture;

  @override
  void initState() {
    super.initState();
    _allPolygons = regionPolygonsForCountry(widget.trip.countryCode);
    _visitedCodesFuture = ref
        .read(regionRepositoryProvider)
        .loadRegionCodesForTrip(widget.trip);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Fits the camera to the bounding box of all region polygons.
  void _fitBounds() {
    if (_allPolygons.isEmpty) return;
    final allPoints = [
      for (final p in _allPolygons)
        for (final v in p.vertices) LatLng(v.$1, v.$2),
    ];
    final bounds = LatLngBounds.fromPoints(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countryName =
        kCountryNames[widget.trip.countryCode] ?? widget.trip.countryCode;
    final flag = _flagEmoji(widget.trip.countryCode);
    final dateRange = _tripDateRange(widget.trip.startedOn, widget.trip.endedOn);

    return Scaffold(
      backgroundColor: _kOceanBackground,
      appBar: AppBar(
        backgroundColor: _kOceanBackground,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$flag  $countryName'),
            Text(
              dateRange,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<String>>(
        future: _visitedCodesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final visitedCodes = snapshot.data!.toSet();
          final visitedPolygons = <Polygon>[];
          final unvisitedPolygons = <Polygon>[];

          for (final p in _allPolygons) {
            final points =
                p.vertices.map((v) => LatLng(v.$1, v.$2)).toList();
            if (visitedCodes.contains(p.regionCode)) {
              visitedPolygons.add(Polygon(
                points: points,
                color: _kVisitedFill.withValues(alpha: 0.85),
                borderStrokeWidth: 0,
              ));
            } else {
              unvisitedPolygons.add(Polygon(
                points: points,
                color: _kUnvisitedFill.withValues(alpha: 0.9),
                borderStrokeWidth: 0,
              ));
            }
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              backgroundColor: _kOceanBackground,
              onMapReady: _fitBounds,
            ),
            children: [
              PolygonLayer(polygonCulling: true, polygons: unvisitedPolygons),
              PolygonLayer(polygonCulling: true, polygons: visitedPolygons),
            ],
          );
        },
      ),
    );
  }
}
