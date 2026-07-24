import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../shared/thumbnail_channel.dart';
import 'thumbnail_lru_cache.dart';

/// Hard cap on the number of photos considered for the map gallery/viewer —
/// a performance guard, not a meaningful UX limit (see [computeMapGalleryPhotos]).
const kMaxMapGalleryPhotos = 300;

/// Squared "flat-earth" distance between two points, scaled so longitude
/// degrees shrink toward the poles like they do on screen (cos of the mean
/// latitude). Only used for relative ordering, so this cheap approximation
/// is preferable to a full haversine — it never needs to be an absolute
/// distance, only sort correctly at the local scale of a heatmap tap.
double _distanceSquared(PhotoLocation a, PhotoLocation b) {
  final dLat = a.lat - b.lat;
  final meanLatRad = (a.lat + b.lat) / 2 * (math.pi / 180);
  final dLng = (a.lng - b.lng) * math.cos(meanLatRad);
  return dLat * dLat + dLng * dLng;
}

/// Computes the map's photo gallery — the exact sequence [MapPhotoStrip]'s
/// grid shows, and what the map's hero pin opens into when tapped, so both
/// entry points always browse the identical set/order.
///
/// Pure function of provider snapshots (no [WidgetRef] coupling) so it works
/// identically from a build method (after `ref.watch`) and from a one-off
/// callback like a tap handler (after `ref.read`).
///
/// Rules (mirrors Google Photos' "Your Map"):
/// - A sort anchor set (a heat blob/pin tap) → nearest-first across the
///   WHOLE library, not just the current viewport, so scrolling can carry
///   the user into a neighbouring region.
/// - No anchor yet → "photos in the visible map area", newest first.
({List<PhotoLocation> photos, int totalCount}) computeMapGalleryPhotos({
  required List<PhotoLocation> locations,
  required PhotoLocation? sortAnchor,
  required MapViewport? viewport,
}) {
  if (locations.isEmpty) return (photos: const [], totalCount: 0);

  if (sortAnchor != null) {
    final byDistance = [...locations]..sort(
      (a, b) => _distanceSquared(sortAnchor, a).compareTo(
        _distanceSquared(sortAnchor, b),
      ),
    );
    final photos = byDistance.length > kMaxMapGalleryPhotos
        ? byDistance.sublist(0, kMaxMapGalleryPhotos)
        : byDistance;
    return (photos: photos, totalCount: locations.length);
  }

  final List<PhotoLocation> pool;
  if (viewport != null) {
    pool = locations
        .where((loc) =>
            loc.lat >= viewport.south &&
            loc.lat <= viewport.north &&
            loc.lng >= viewport.west &&
            loc.lng <= viewport.east)
        .toList();
  } else {
    pool = locations;
  }
  if (pool.isEmpty) return (photos: const [], totalCount: 0);
  final capped = pool.length > kMaxMapGalleryPhotos
      ? pool.sublist(pool.length - kMaxMapGalleryPhotos)
      : pool;
  return (photos: capped.reversed.toList(), totalCount: pool.length);
}

// ── Full-screen viewer ────────────────────────────────────────────────────────

/// Full-screen photo viewer matching the Google Photos map viewer pattern:
/// - Swipe left/right to browse the map gallery sequence
/// - Swipe down to dismiss (velocity-based)
/// - Black background, edge-to-edge, full-resolution image filling the screen
/// - Top bar: close + photo count
/// - Bottom bar: share
///
/// Opened from either the grid ([MapPhotoStrip]) or the map's hero pin
/// ([PhotoPinLayer]) with the same [computeMapGalleryPhotos] sequence.
class MapPhotoViewer extends StatefulWidget {
  const MapPhotoViewer({
    super.key,
    required this.assetIds,
    required this.initialIndex,
    this.heroTag,
  });

  final List<String> assetIds;
  final int initialIndex;

  /// Hero tag for a shared-element transition from the tapped thumbnail.
  /// Null when opened from the map pin (no grid tile to expand from).
  final String? heroTag;

  static Route<void> route({
    required List<String> assetIds,
    required int initialIndex,
    String? heroTag,
  }) {
    return PageRouteBuilder<void>(
      opaque: true, // Hero shared-element animation requires an opaque route
      pageBuilder: (_, __, ___) => MapPhotoViewer(
        assetIds: assetIds,
        initialIndex: initialIndex,
        heroTag: heroTag,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<MapPhotoViewer> createState() => _MapPhotoViewerState();
}

class _MapPhotoViewerState extends State<MapPhotoViewer> {
  late final PageController _page;
  late int _current;

  // Swipe-down-to-dismiss tracking.
  double _dragOffset = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    Navigator.of(context).pop();
  }

  Future<void> _share() async {
    final assetId = widget.assetIds[_current];
    final bytes =
        ThumbnailLruCache.instance.get(assetId) ??
        await const ThumbnailChannel().getThumbnail(assetId, size: 600);
    if (bytes == null || !mounted) return;
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'photo.jpg')],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.assetIds.length;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 0) setState(() => _dragOffset += d.delta.dy);
      },
      onVerticalDragEnd: (d) {
        if (_dragOffset > 80 || (d.velocity.pixelsPerSecond.dy > 600)) {
          _dismiss();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(
          alpha: (_dragOffset / 200).clamp(0.0, 0.6) == 0.0
              ? 1.0
              : 1.0 - (_dragOffset / 200).clamp(0.0, 0.6),
        ),
        body: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Stack(
            children: [
              // Photo PageView
              PageView.builder(
                controller: _page,
                itemCount: total,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => _PhotoPage(
                  assetId: widget.assetIds[i],
                  heroTag: (widget.heroTag != null && i == widget.initialIndex)
                      ? widget.heroTag
                      : null,
                ),
              ),

              // Top bar: close + counter
              Positioned(
                top: topPad + 4,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _dismiss,
                    ),
                    const Spacer(),
                    Text(
                      '${_current + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // balance the close button
                  ],
                ),
              ),

              // Bottom bar: share
              Positioned(
                bottom: bottomPad + 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BottomAction(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: _share,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPage extends StatefulWidget {
  const _PhotoPage({required this.assetId, this.heroTag});

  final String assetId;
  // Non-null only for the photo the user tapped (enables zoom-expand Hero).
  final String? heroTag;

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    // Show cached thumbnail immediately (no flash/spinner for photos already
    // seen in the grid/pin) while the full-resolution image loads.
    _bytes = ThumbnailLruCache.instance.get(widget.assetId);
    _loadFullRes();
  }

  Future<void> _loadFullRes() async {
    final full =
        await const ThumbnailChannel().getFullResolutionImage(widget.assetId);
    if (full != null && mounted) setState(() => _bytes = full);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    // width/height: double.infinity + BoxFit.contain makes the image SCALE UP
    // to fill the screen (letterboxed to preserve aspect ratio) instead of
    // rendering at its native decoded pixel size — without this an Image
    // with no explicit size renders tiny in the middle of the black screen.
    Widget image = Image.memory(
      bytes,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: image,
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
