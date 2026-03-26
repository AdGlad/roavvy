import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../../core/region_names.dart';

// ── Colours (match TripMapScreen / CountryPolygonLayer — ADR-080, ADR-090) ───

const _kOceanBackground = Color(0xFF0D2137);
const _kVisitedFill = Color(0xFFD4A017);   // amber tier-1
const _kUnvisitedFill = Color(0xFF1E3A5F); // dark navy land

// ── Helpers ───────────────────────────────────────────────────────────────────

String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + isoCode.codeUnitAt(0) - 65) +
      String.fromCharCode(base + isoCode.codeUnitAt(1) - 65);
}

// ── CountryRegionMapScreen ────────────────────────────────────────────────────

/// Full-screen map showing all visited regions for [countryCode].
///
/// All region polygons are fetched synchronously from the already-initialised
/// `region_lookup` package. Visited region codes are resolved asynchronously
/// via [RegionRepository.loadByCountry].
///
/// Visited regions are rendered in amber; unvisited in dark navy — matching
/// the main map theme (ADR-080, ADR-091).
///
/// Tapping a visited region shows a floating name label anchored at the tap
/// point. Tapping the background or an unvisited region dismisses the label
/// (ADR-091).
class CountryRegionMapScreen extends ConsumerStatefulWidget {
  const CountryRegionMapScreen({super.key, required this.countryCode});

  final String countryCode;

  @override
  ConsumerState<CountryRegionMapScreen> createState() =>
      _CountryRegionMapScreenState();
}

class _CountryRegionMapScreenState
    extends ConsumerState<CountryRegionMapScreen> {
  final _mapController = MapController();
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);

  late final List<RegionPolygon> _allPolygons;
  late final Future<List<RegionVisit>> _visitsFuture;

  int _visitedCount = 0;
  String? _selectedCode;
  LatLng? _selectedLatLng;

  @override
  void initState() {
    super.initState();
    _allPolygons = regionPolygonsForCountry(widget.countryCode);
    final future =
        ref.read(regionRepositoryProvider).loadByCountry(widget.countryCode);
    _visitsFuture = future;
    future.then((visits) {
      if (!mounted) return;
      setState(() {
        _visitedCount = visits.map((v) => v.regionCode).toSet().length;
      });
    });
  }

  @override
  void dispose() {
    _hitNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Fits the camera to the bounding box of all region polygons.
  ///
  /// Falls back to the country polygon from [polygonsProvider] when no region
  /// data is available (e.g. small island nations like Seychelles whose
  /// districts are absent from the region binary). Without this fallback the
  /// map stays at world zoom and the island appears as a tiny unclickable dot.
  void _fitBounds() {
    if (_allPolygons.isNotEmpty) {
      final allPoints = [
        for (final p in _allPolygons)
          for (final v in p.vertices) LatLng(v.$1, v.$2),
      ];
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
      );
      return;
    }

    // No region polygons — fit to the country outline instead.
    final countryPolygons = ref.read(polygonsProvider);
    final countryPoints = [
      for (final p in countryPolygons.where((p) => p.isoCode == widget.countryCode))
        for (final v in p.vertices) LatLng(v.$1, v.$2),
    ];
    if (countryPoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(countryPoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  Marker _buildLabel(String code, LatLng position) {
    final name = kRegionNames[code] ?? code;
    return Marker(
      point: position,
      width: 200,
      height: 48,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flag = _flagEmoji(widget.countryCode);
    final countryName =
        kCountryNames[widget.countryCode] ?? widget.countryCode;
    final regionWord = _visitedCount == 1 ? 'region' : 'regions';

    return Scaffold(
      backgroundColor: _kOceanBackground,
      appBar: AppBar(
        backgroundColor: _kOceanBackground,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$flag  $countryName'),
            if (_visitedCount > 0)
              Text(
                '$_visitedCount $regionWord visited',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
          ],
        ),
      ),
      body: FutureBuilder<List<RegionVisit>>(
        future: _visitsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final visitedCodes =
              snapshot.data!.map((v) => v.regionCode).toSet();
          final visitedPolygons = <Polygon<String>>[];
          final unvisitedPolygons = <Polygon>[];

          for (final p in _allPolygons) {
            final points =
                p.vertices.map((v) => LatLng(v.$1, v.$2)).toList();
            if (visitedCodes.contains(p.regionCode)) {
              visitedPolygons.add(Polygon<String>(
                points: points,
                color: _kVisitedFill.withValues(alpha: 0.85),
                borderStrokeWidth: 0,
                hitValue: p.regionCode,
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
              // GestureDetector wraps the visited PolygonLayer for hit
              // detection. When _hitNotifier.value is null on tap, the tap
              // landed on background/unvisited area → dismiss label (ADR-091).
              GestureDetector(
                onTap: () {
                  final hit = _hitNotifier.value;
                  setState(() {
                    _selectedCode = hit?.hitValues.first;
                    _selectedLatLng = hit?.coordinate;
                  });
                },
                child: PolygonLayer<String>(
                  hitNotifier: _hitNotifier,
                  polygonCulling: true,
                  polygons: visitedPolygons,
                ),
              ),
              if (_selectedCode != null && _selectedLatLng != null)
                MarkerLayer(
                  markers: [_buildLabel(_selectedCode!, _selectedLatLng!)],
                ),
            ],
          );
        },
      ),
    );
  }
}
