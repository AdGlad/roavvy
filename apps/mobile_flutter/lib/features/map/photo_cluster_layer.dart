import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../shared/thumbnail_channel.dart';
import 'photo_gallery_screen.dart';

/// Renders photo clusters or individual thumbnails on the flat [FlutterMap]
/// based on the current zoom level. (M168)
///
/// Zoom < 5   → hidden (SizedBox.shrink)
/// Zoom 5–9   → [_ClusterMarker] circle badges grouped by 0.5°/0.1° grid
/// Zoom ≥ 10  → [_PhotoThumbnailMarker] individual photos (max 40 in viewport)
///
/// Markers outside the viewport (expanded by 20%) are culled before building.
class PhotoClusterLayer extends ConsumerWidget {
  const PhotoClusterLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(photoLocationsProvider);
    final locations = locationsAsync.valueOrNull;
    if (locations == null || locations.isEmpty) return const SizedBox.shrink();

    final camera = MapCamera.of(context);
    final zoom = camera.zoom;

    if (zoom < 5) return const SizedBox.shrink();

    final expanded = _expandBounds(camera.visibleBounds, 0.2);
    final visible =
        locations.where((loc) => _inBounds(loc, expanded)).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    if (zoom >= 10) {
      // Individual thumbnails — cap at 40, prefer most-recent (tail of list).
      final capped =
          visible.length > 40
              ? visible.sublist(visible.length - 40)
              : visible;
      final markers =
          capped
              .map(
                (loc) => Marker(
                  point: LatLng(loc.lat, loc.lng),
                  width: 56,
                  height: 56,
                  child: _PhotoThumbnailMarker(assetId: loc.assetId),
                ),
              )
              .toList();
      return MarkerLayer(markers: markers);
    }

    // Cluster mode (zoom 5–9).
    final clusters = _buildClusters(visible, zoom);
    final markers =
        clusters.values
            .map(
              (cluster) => Marker(
                point: LatLng(cluster.lat, cluster.lng),
                width: 44,
                height: 44,
                child: _ClusterMarker(
                  count: cluster.count,
                  centroid: LatLng(cluster.lat, cluster.lng),
                  currentZoom: zoom,
                ),
              ),
            )
            .toList();
    return MarkerLayer(markers: markers);
  }

  static LatLngBounds _expandBounds(LatLngBounds bounds, double fraction) {
    final latSpan = bounds.north - bounds.south;
    final lngSpan = bounds.east - bounds.west;
    return LatLngBounds.unsafe(
      north: math.min(90.0, bounds.north + latSpan * fraction),
      south: math.max(-90.0, bounds.south - latSpan * fraction),
      east: math.min(180.0, bounds.east + lngSpan * fraction),
      west: math.max(-180.0, bounds.west - lngSpan * fraction),
    );
  }

  static bool _inBounds(PhotoLocation loc, LatLngBounds bounds) {
    return loc.lat >= bounds.south &&
        loc.lat <= bounds.north &&
        loc.lng >= bounds.west &&
        loc.lng <= bounds.east;
  }

  static Map<String, _Cluster> _buildClusters(
    List<PhotoLocation> locs,
    double zoom,
  ) {
    final cellSize = zoom < 8 ? 0.5 : 0.1;
    final cells = <String, _Cluster>{};
    for (final loc in locs) {
      final cellLat = (loc.lat / cellSize).floor() * cellSize;
      final cellLng = (loc.lng / cellSize).floor() * cellSize;
      final key = '$cellLat,$cellLng';
      final cluster = cells.putIfAbsent(
        key,
        () => _Cluster(
          lat: cellLat + cellSize / 2,
          lng: cellLng + cellSize / 2,
        ),
      );
      cluster.count++;
      cluster.assetIds.add(loc.assetId);
    }
    return cells;
  }
}

// ── Internal data ──────────────────────────────────────────────────────────────

class _Cluster {
  _Cluster({required this.lat, required this.lng});

  final double lat;
  final double lng;
  int count = 0;
  final List<String> assetIds = [];
}

// ── Cluster badge marker ───────────────────────────────────────────────────────

/// Filled circle showing the photo count for a grid cell. Tapping zooms in by
/// 2 levels centred on this cluster's centroid (no animation).
class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.count,
    required this.centroid,
    required this.currentZoom,
  });

  final int count;
  final LatLng centroid;
  final double currentZoom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MapController.of(context).move(centroid, currentZoom + 2),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Photo thumbnail marker ─────────────────────────────────────────────────────

/// Async-loads a 96 px thumbnail via [ThumbnailChannel] and renders a rounded
/// square. Tapping opens [PhotoGalleryScreen] for this single photo.
class _PhotoThumbnailMarker extends StatefulWidget {
  const _PhotoThumbnailMarker({required this.assetId});

  final String assetId;

  @override
  State<_PhotoThumbnailMarker> createState() => _PhotoThumbnailMarkerState();
}

class _PhotoThumbnailMarkerState extends State<_PhotoThumbnailMarker> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchThumbnail();
  }

  Future<void> _fetchThumbnail() async {
    final bytes = await const ThumbnailChannel().getThumbnail(
      widget.assetId,
      size: 96,
    );
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading || _bytes == null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.grey.shade300,
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _bytes!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoGalleryScreen(assetIds: [widget.assetId]),
        ),
      ),
      child: content,
    );
  }
}
