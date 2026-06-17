import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../map/country_centroids.dart';
import '../map/globe_projection.dart';
import '../map/region_globe_painter.dart';
import '../shared/hero_image_view.dart';

/// Immersive trip summary showing a globe map and photo gallery.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.trip});

  final TripRecord trip;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  late final List<RegionPolygon> _allRegionPolygons;
  late final Future<Set<String>> _visitedCodesFuture;
  late final Future<List<String>> _tripPhotosFuture;

  GlobeProjection _projection = const GlobeProjection();
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();

    _allRegionPolygons = regionPolygonsForCountry(widget.trip.countryCode);

    // Initial projection: centred on country centroid.
    final centroid = kCountryCentroids[widget.trip.countryCode];
    final lat = centroid?.$1 ?? 0.0;
    final lng = centroid?.$2 ?? 0.0;

    final centered = GlobeProjection(
      rotLat: lat * math.pi / 180.0,
      rotLng: -lng * math.pi / 180.0,
      scale: 1.0,
    );

    // Auto-scale to fit the country, excluding remote outlier territories
    // (~ regions such as SC-X02~ Aldabra) so the globe frames the main body.
    final mainPolygons =
        _allRegionPolygons.where((p) => !p.regionCode.endsWith('~')).toList();
    _projection = centered.copyWith(
      scale: _autoScale(
        mainPolygons.isNotEmpty ? mainPolygons : _allRegionPolygons,
        centered,
      ),
    );

    // Load regions visited specifically during THIS trip.
    _visitedCodesFuture = ref
        .read(regionRepositoryProvider)
        .loadRegionCodesForTrip(widget.trip)
        .then((codes) => codes.toSet());

    // Load photo asset IDs for this trip's range.
    _tripPhotosFuture = ref
        .read(visitRepositoryProvider)
        .loadAssetIdsByDateRange(
          widget.trip.countryCode,
          widget.trip.startedOn,
          widget.trip.endedOn,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countryName =
        kCountryNames[widget.trip.countryCode] ?? widget.trip.countryCode;
    final flag = _flagEmoji(widget.trip.countryCode);
    final dateRange = _dateRange(widget.trip.startedOn, widget.trip.endedOn);
    final days = _tripDays(widget.trip.startedOn, widget.trip.endedOn);

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 350,
              pinned: true,
              stretch: true,
              backgroundColor: kOcean,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Globe Map
                    FutureBuilder<Set<String>>(
                      future: _visitedCodesFuture,
                      builder: (context, snapshot) {
                        final visitedCodes = snapshot.data ?? const {};
                        final countryPolygons = ref.watch(polygonsProvider);

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            _canvasSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return CustomPaint(
                              size: _canvasSize,
                              painter: RegionGlobePainter(
                                countryPolygons: countryPolygons,
                                regionPolygons: _allRegionPolygons,
                                visitedCodes: visitedCodes,
                                projection: _projection,
                                highlightColor: Colors.amber.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // 2. Metadata Overlays
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trip to $countryName',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$flag $countryName  ·  $dateRange',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatChip(
                                  icon: Icons.calendar_today,
                                  label: '$days ${days == 1 ? 'day' : 'days'}',
                                ),
                                const SizedBox(width: 12),
                                _StatChip(
                                  icon: Icons.photo_library_outlined,
                                  label: '${widget.trip.photoCount} photos',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: FutureBuilder<List<String>>(
          future: _tripPhotosFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final assetIds = snapshot.data!;
            if (assetIds.isEmpty) {
              return const Center(
                child: Text(
                  'No photos found for this trip.',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            // Compute the exact physical pixel size of each grid cell so
            // photo_manager requests at exactly the right resolution.
            final mq = MediaQuery.of(context);
            final cellPx =
                ((mq.size.width - 4) / 3 * mq.devicePixelRatio).ceil();

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(2),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return GestureDetector(
                        onTap: () => _showFullScreen(context, assetIds[index]),
                        child: HeroImageView(
                          assetId: assetIds[index],
                          fallbackColor: Colors.grey[900]!,
                          height: double.infinity,
                          thumbnailSize: ThumbnailSize.square(cellPx),
                        ),
                      );
                    }, childCount: assetIds.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String assetId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FullScreenPhotoView(assetId: assetId)),
    );
  }
}

class _FullScreenPhotoView extends StatelessWidget {
  const _FullScreenPhotoView({required this.assetId});
  final String assetId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        child: Center(
          child: HeroImageView(
            assetId: assetId,
            fallbackColor: Colors.black,
            height: double.infinity,
            useFullResolution: true,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amber, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _flagEmoji(String iso) {
  if (iso.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + iso.codeUnitAt(0) - 65) +
      String.fromCharCode(base + iso.codeUnitAt(1) - 65);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime dt, {bool showYear = true}) {
  final m = _months[dt.month - 1];
  return showYear ? '${dt.day} $m ${dt.year}' : '${dt.day} $m';
}

String _dateRange(DateTime start, DateTime end) {
  if (start.year == end.year) {
    return '${_fmtDate(start, showYear: false)} – ${_fmtDate(end)}';
  }
  return '${_fmtDate(start)} – ${_fmtDate(end)}';
}

int _tripDays(DateTime start, DateTime end) => end.difference(start).inDays + 1;

double _autoScale(List<RegionPolygon> polygons, GlobeProjection centered) {
  const kNorm = Size(1000, 1000);
  const kRadius = 500.0;
  const kTargetFraction = 0.65;

  final proj = centered.copyWith(scale: 1.0);
  var maxDist = 0.0;
  for (final p in polygons) {
    for (final v in p.vertices) {
      final pt = proj.project(v.$1, v.$2, kNorm);
      if (pt == null) continue;
      final dx = pt.dx - 500;
      final dy = pt.dy - 500;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > maxDist) maxDist = d;
    }
  }
  if (maxDist < 1.0) return 2.0;
  return ((kRadius * kTargetFraction) / maxDist).clamp(1.2, 14.0);
}
