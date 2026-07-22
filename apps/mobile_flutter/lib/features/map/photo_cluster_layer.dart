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
import 'thumbnail_lru_cache.dart';

/// Renders photo clusters or individual thumbnails on the flat [FlutterMap]
/// based on the current zoom level. (M168)
///
/// Zoom < 5   → hidden (SizedBox.shrink)
/// Zoom 5–7   → [_StackedClusterMarker] stacked thumbnail badges (0.5° grid)
/// Zoom 8–9   → [_StackedClusterMarker] tighter clusters (0.1° grid)
/// Zoom ≥ 10  → [_PhotoThumbnailMarker] individual photos (max 40 in viewport)
///
/// Markers outside the viewport (expanded by 20%) are culled before building.
class PhotoClusterLayer extends ConsumerWidget {
  const PhotoClusterLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const SizedBox.shrink();

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
                  key: ValueKey(loc.assetId),
                  point: LatLng(loc.lat, loc.lng),
                  width: 56,
                  height: 56,
                  child: _PhotoThumbnailMarker(
                    key: ValueKey(loc.assetId),
                    assetId: loc.assetId,
                  ),
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
                key: ValueKey('cluster_${cluster.lat}_${cluster.lng}'),
                point: LatLng(cluster.lat, cluster.lng),
                width: 60,
                height: 60,
                child: _StackedClusterMarker(
                  count: cluster.count,
                  previewAssetIds: cluster.assetIds.take(2).toList(),
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

// ── Stacked cluster marker ─────────────────────────────────────────────────────

/// iPhone Photos-style stacked thumbnail cluster. Shows up to 2 photo previews
/// fanned at angles with a count badge. Tapping zooms in by 2 levels.
class _StackedClusterMarker extends StatefulWidget {
  const _StackedClusterMarker({
    required this.count,
    required this.previewAssetIds,
    required this.centroid,
    required this.currentZoom,
  });

  final int count;
  final List<String> previewAssetIds;
  final LatLng centroid;
  final double currentZoom;

  @override
  State<_StackedClusterMarker> createState() => _StackedClusterMarkerState();
}

class _StackedClusterMarkerState extends State<_StackedClusterMarker> {
  final _images = <String, Uint8List?>{};

  @override
  void initState() {
    super.initState();
    for (final id in widget.previewAssetIds) {
      _loadImage(id);
    }
  }

  Future<void> _loadImage(String assetId) async {
    final cached = ThumbnailLruCache.instance.get(assetId);
    if (cached != null) {
      if (mounted) setState(() => _images[assetId] = cached);
      return;
    }
    final bytes = await const ThumbnailChannel().getThumbnail(assetId, size: 64);
    if (bytes != null) ThumbnailLruCache.instance.put(assetId, bytes);
    if (mounted) setState(() => _images[assetId] = bytes);
  }

  Widget _thumbnail(String assetId, double rotation) {
    final bytes = _images[assetId];
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
          color: Colors.grey.shade400,
          image: bytes != null
              ? DecorationImage(
                  image: MemoryImage(bytes),
                  fit: BoxFit.cover,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.previewAssetIds;
    return GestureDetector(
      onTap: () =>
          MapController.of(context).move(widget.centroid, widget.currentZoom + 2),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Back card (rotated right) — only when ≥ 2 photos.
            if (ids.length >= 2)
              Positioned(
                top: 4,
                left: 6,
                child: _thumbnail(ids[1], 0.25),
              ),
            // Front card (slight left tilt).
            Positioned(
              top: 8,
              left: 12,
              child: _thumbnail(ids[0], -0.15),
            ),
            // Count badge — top-right corner.
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  widget.count > 99 ? '99+' : '${widget.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo thumbnail marker ─────────────────────────────────────────────────────

/// Async-loads a 96 px thumbnail via [ThumbnailChannel] and renders a rounded
/// square. Tapping opens [PhotoGalleryScreen] for this single photo.
class _PhotoThumbnailMarker extends StatefulWidget {
  const _PhotoThumbnailMarker({super.key, required this.assetId});

  final String assetId;

  @override
  State<_PhotoThumbnailMarker> createState() => _PhotoThumbnailMarkerState();
}

class _PhotoThumbnailMarkerState extends State<_PhotoThumbnailMarker> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Check LRU cache before hitting the channel.
    final cached = ThumbnailLruCache.instance.get(widget.assetId);
    if (cached != null) {
      _bytes = cached;
      _loading = false;
      _visible = true;
    } else {
      _fetchThumbnail();
    }
  }

  Future<void> _fetchThumbnail() async {
    final bytes = await const ThumbnailChannel().getThumbnail(
      widget.assetId,
      size: 96,
    );
    if (bytes != null) ThumbnailLruCache.instance.put(widget.assetId, bytes);
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
      // Trigger fade-in + scale-in on next frame so animations play.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _bytes == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _bytes!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          );

    final content = _loading || image == null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(width: 48, height: 48, color: Colors.grey.shade300),
          )
        : AnimatedScale(
            duration: const Duration(milliseconds: 250),
            scale: _visible ? 1.0 : 0.4,
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _visible ? 1.0 : 0.0,
              child: DecoratedBox(
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
                child: image,
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
