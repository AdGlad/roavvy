import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../shared/thumbnail_channel.dart';
import 'globe_projection.dart';
import 'map_photo_viewer.dart';
import 'thumbnail_lru_cache.dart';

/// Pin visual constants shared by [PhotoPinLayer] (flat map) and
/// [GlobeHeroPin] (3D globe) so the two render identically.
const _kPinSize = 64.0;
const _kPinRingWidth = 4.0;
const _kPinTailHeight = 8.0;
const _kPinAnchorSize = 12.0;

/// Opens the full-screen viewer on [selected], positioned within the current
/// [computeMapGalleryPhotos] sequence — shared by the flat map's
/// [PhotoPinLayer] and the globe's [GlobeHeroPin] so tapping the pin behaves
/// identically on both views.
void openMapPhotoViewer(BuildContext context, WidgetRef ref, PhotoLocation selected) {
  final locations = ref.read(photoLocationsProvider).valueOrNull ?? const [];
  final sortAnchor = ref.read(mapGallerySortAnchorProvider);
  final viewport = sortAnchor == null ? ref.read(mapViewportProvider) : null;
  final gallery = computeMapGalleryPhotos(
    locations: locations,
    sortAnchor: sortAnchor,
    viewport: viewport,
  );
  final assetIds = gallery.photos.map((p) => p.assetId).toList();
  final idx = assetIds.indexOf(selected.assetId);
  Navigator.of(context).push(
    MapPhotoViewer.route(
      assetIds: idx >= 0 ? assetIds : [selected.assetId],
      initialIndex: idx >= 0 ? idx : 0,
    ),
  );
}

/// Caches unit vectors for [findCenterMostPhoto] so repeated calls (the
/// globe's hero-photo rotation ticks every few seconds while turning) don't
/// redo lat/lng→unit-vector trig each time — only the projection step
/// (cheap multiply-adds via [GlobeProjection.projectUnit]) reruns per call.
/// Recomputed only when the [locations] list identity changes (a fresh
/// scan/reload), mirroring the caching pattern in globe_photo_heatmap.dart.
class _CenterMostPhotoCache {
  _CenterMostPhotoCache._(this._locations, this._units);

  final List<PhotoLocation> _locations;
  final List<(double, double, double)> _units;

  static _CenterMostPhotoCache? _cache;

  static _CenterMostPhotoCache _of(List<PhotoLocation> locations) {
    final cached = _cache;
    if (cached != null && identical(cached._locations, locations)) {
      return cached;
    }
    final units = [
      for (final loc in locations) GlobeProjection.unitVector(loc.lat, loc.lng),
    ];
    final fresh = _CenterMostPhotoCache._(locations, units);
    _cache = fresh;
    return fresh;
  }
}

/// Returns the photo location closest to the centre of the screen among
/// those on the visible (front-facing) hemisphere AND actually within
/// [canvasSize]'s bounds — at high zoom a front-facing point near the edge
/// of the globe disk can still project well outside the canvas, and picking
/// that as "the centre-most photo" would be misleading. Returns null when
/// [locations] is empty or nothing qualifies (e.g. zoomed into empty ocean).
///
/// Drives the globe's hero pin cycling as it rotates — see [GlobeHeroPin]
/// and its periodic caller in map_screen.dart's `_GlobeWithHeroPinState`.
PhotoLocation? findCenterMostPhoto({
  required List<PhotoLocation> locations,
  required GlobeProjection projection,
  required Size canvasSize,
}) {
  if (locations.isEmpty || canvasSize == Size.zero) return null;
  final cache = _CenterMostPhotoCache._of(locations);
  final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

  PhotoLocation? nearest;
  var nearestDist = double.infinity;
  for (var i = 0; i < locations.length; i++) {
    final pt = projection.projectUnit(cache._units[i], canvasSize);
    if (pt == null) continue; // back face of the globe
    if (pt.dx < 0 ||
        pt.dx > canvasSize.width ||
        pt.dy < 0 ||
        pt.dy > canvasSize.height) {
      continue; // front-facing but projected off-screen
    }
    final dist = (pt - center).distanceSquared;
    if (dist < nearestDist) {
      nearestDist = dist;
      nearest = locations[i];
    }
  }
  return nearest;
}

/// The pin's visual column — thumbnail, tail, anchor dot — shared by both
/// [PhotoPinLayer] and [GlobeHeroPin].
Widget _pinColumn(String assetId) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Cross-fades between hero photos (AnimatedSwitcher's default
      // transition is a pure FadeTransition) instead of the hard pop you'd
      // get from the assetId-keyed _PinThumbnail swapping instantly — the
      // ring/tail/anchor below stay stable so only the photo itself dissolves.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _PinThumbnail(
          key: ValueKey(assetId),
          assetId: assetId,
          size: _kPinSize,
          ringWidth: _kPinRingWidth,
        ),
      ),
      // Tail connecting the pin to the anchor dot.
      Container(width: 2.5, height: _kPinTailHeight, color: Colors.white),
      // Dark anchor dot with a white halo ring.
      Container(
        width: _kPinAnchorSize,
        height: _kPinAnchorSize,
        decoration: BoxDecoration(
          color: const Color(0xFF3E3F4A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    ],
  );
}

/// Google Photos-style current-photo pin: a circular thumbnail inside a thick
/// white ring with a short tail down to a small dark anchor dot at the exact
/// photo location. The thumbnail crossfades when the selection changes.
///
/// Tapping the pin opens the same full-screen viewer, on the same
/// [computeMapGalleryPhotos] sequence, as tapping the grid ([MapPhotoStrip]).
class PhotoPinLayer extends ConsumerWidget {
  const PhotoPinLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMapPhotoProvider);
    if (selected == null) return const SizedBox.shrink();

    const totalH = _kPinSize + _kPinTailHeight + _kPinAnchorSize;
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(selected.lat, selected.lng),
          width: _kPinSize + _kPinRingWidth * 2,
          height: totalH,
          // Anchor dot (bottom of the column) sits on the coordinate.
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => openMapPhotoViewer(context, ref, selected),
            child: _pinColumn(selected.assetId),
          ),
        ),
      ],
    );
  }
}

/// The globe equivalent of [PhotoPinLayer] — same look, same tap behaviour —
/// projected onto the globe's screen coordinates instead of a flutter_map
/// [Marker] (the globe is a custom canvas, not a flutter_map instance).
/// [projection]/[canvasSize] are refreshed every frame by [GlobeMapWidget]'s
/// `onProjectionUpdated` callback.
class GlobeHeroPin extends ConsumerWidget {
  const GlobeHeroPin({
    super.key,
    required this.projection,
    required this.canvasSize,
  });

  final GlobeProjection projection;
  final Size canvasSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMapPhotoProvider);
    if (selected == null || canvasSize == Size.zero) {
      return const SizedBox.shrink();
    }
    final pt = projection.project(selected.lat, selected.lng, canvasSize);
    if (pt == null) return const SizedBox.shrink(); // behind the globe

    const totalW = _kPinSize + _kPinRingWidth * 2;
    const totalH = _kPinSize + _kPinTailHeight + _kPinAnchorSize;
    return Positioned(
      left: pt.dx - totalW / 2,
      top: pt.dy - totalH, // anchor dot sits exactly on the projected point
      child: GestureDetector(
        onTap: () => openMapPhotoViewer(context, ref, selected),
        child: _pinColumn(selected.assetId),
      ),
    );
  }
}

class _PinThumbnail extends StatefulWidget {
  const _PinThumbnail({
    super.key,
    required this.assetId,
    required this.size,
    required this.ringWidth,
  });

  final String assetId;
  final double size;
  final double ringWidth;

  @override
  State<_PinThumbnail> createState() => _PinThumbnailState();
}

class _PinThumbnailState extends State<_PinThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = ThumbnailLruCache.instance.get(widget.assetId);
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    final bytes =
        await const ThumbnailChannel().getThumbnail(widget.assetId, size: 150);
    if (bytes != null) {
      ThumbnailLruCache.instance.put(widget.assetId, bytes);
      if (mounted) setState(() => _bytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(bytes == null),
        width: widget.size + widget.ringWidth * 2,
        height: widget.size + widget.ringWidth * 2,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.all(widget.ringWidth),
        child: ClipOval(
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
              : const ColoredBox(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}

/// Small dark anchor dots for every other photo in the viewport at street
/// zoom — Google Photos shows these alongside the main pin so nearby shots
/// are discoverable. Painted (not markers) so hundreds stay cheap.
class PhotoAnchorDotsLayer extends ConsumerWidget {
  const PhotoAnchorDotsLayer({super.key});

  static const double _minZoom = 8.0;
  static const int _maxDots = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const SizedBox.shrink();
    final locations = ref.watch(photoLocationsProvider).valueOrNull;
    if (locations == null || locations.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    if (camera.zoom < _minZoom) return const SizedBox.shrink();
    final selectedId = ref.watch(selectedMapPhotoProvider)?.assetId;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _AnchorDotsPainter(
          locations: locations,
          camera: camera,
          excludeAssetId: selectedId,
        ),
      ),
    );
  }
}

class _AnchorDotsPainter extends CustomPainter {
  _AnchorDotsPainter({
    required this.locations,
    required this.camera,
    this.excludeAssetId,
  });

  final List<PhotoLocation> locations;
  final MapCamera camera;
  final String? excludeAssetId;

  @override
  void paint(Canvas canvas, Size size) {
    final halo = Paint()..color = Colors.white;
    final dot = Paint()..color = const Color(0xFF3E3F4A);

    // Viewport-filter before capping so zoomed-in regions keep all their
    // dots (striding the whole library first would dilute them).
    final bounds = camera.visibleBounds;
    final inView = <PhotoLocation>[
      for (final loc in locations)
        if (loc.lat >= bounds.south &&
            loc.lat <= bounds.north &&
            loc.lng >= bounds.west &&
            loc.lng <= bounds.east)
          loc,
    ];
    final stride = inView.length <= PhotoAnchorDotsLayer._maxDots
        ? 1
        : (inView.length / PhotoAnchorDotsLayer._maxDots).ceil();
    for (int i = 0; i < inView.length; i += stride) {
      final loc = inView[i];
      if (loc.assetId == excludeAssetId) continue;
      final p = camera.latLngToScreenPoint(LatLng(loc.lat, loc.lng));
      if (p.x < -8 || p.x > size.width + 8 || p.y < -8 || p.y > size.height + 8) {
        continue;
      }
      final c = Offset(p.x, p.y);
      canvas.drawCircle(c, 4.5, halo);
      canvas.drawCircle(c, 3.2, dot);
    }
  }

  @override
  bool shouldRepaint(_AnchorDotsPainter old) =>
      old.camera.zoom != camera.zoom ||
      old.camera.center != camera.center ||
      old.excludeAssetId != excludeAssetId ||
      !identical(old.locations, locations);
}
