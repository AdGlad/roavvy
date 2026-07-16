import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../shared/thumbnail_channel.dart';
import 'globe_projection.dart';
import 'thumbnail_lru_cache.dart';

/// Overlay that renders photo thumbnails on the 3D globe based on GPS location.
///
/// Fades out while the user is dragging ([rotationNotifier] == true) and fades
/// back in (300 ms) when the globe settles. At rest, the top-25 photos closest
/// to the screen centre are positioned using [GlobeProjection.project] (M169).
class PhotoGlobeOverlay extends ConsumerStatefulWidget {
  const PhotoGlobeOverlay({
    super.key,
    required this.rotationNotifier,
    required this.projection,
    required this.canvasSize,
  });

  /// True while the user is actively dragging the globe — overlay fades to 0.
  final ValueNotifier<bool> rotationNotifier;

  /// Current orthographic projection; updated each frame by [GlobeMapWidget].
  final GlobeProjection projection;

  /// Canvas dimensions matching the globe widget; updated each frame.
  final Size canvasSize;

  @override
  ConsumerState<PhotoGlobeOverlay> createState() => _PhotoGlobeOverlayState();
}

class _PhotoGlobeOverlayState extends ConsumerState<PhotoGlobeOverlay> {
  @override
  void initState() {
    super.initState();
    widget.rotationNotifier.addListener(_onRotationChanged);
  }

  @override
  void didUpdateWidget(PhotoGlobeOverlay old) {
    super.didUpdateWidget(old);
    if (old.rotationNotifier != widget.rotationNotifier) {
      old.rotationNotifier.removeListener(_onRotationChanged);
      widget.rotationNotifier.addListener(_onRotationChanged);
    }
  }

  @override
  void dispose() {
    widget.rotationNotifier.removeListener(_onRotationChanged);
    super.dispose();
  }

  void _onRotationChanged() => setState(() {});

  List<Widget> _buildMarkers() {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const [];
    final locations =
        ref.watch(photoLocationsProvider).valueOrNull ?? const [];
    if (locations.isEmpty || widget.canvasSize == Size.zero) return const [];

    final centre = Offset(
      widget.canvasSize.width / 2,
      widget.canvasSize.height / 2,
    );

    // Project each photo location to screen space, skip back-facing points.
    final projected = <(Offset, String)>[];
    for (final loc in locations) {
      final offset =
          widget.projection.project(loc.lat, loc.lng, widget.canvasSize);
      if (offset == null) continue;
      projected.add((offset, loc.assetId));
    }

    // Select the 25 photos whose projected position is closest to screen centre
    // (i.e. roughly in the middle of the visible hemisphere).
    projected.sort(
      (a, b) =>
          (a.$1 - centre).distance.compareTo((b.$1 - centre).distance),
    );
    final top = projected.take(25);

    return [
      for (final entry in top)
        Positioned(
          left: entry.$1.dx - 22,
          top: entry.$1.dy - 22,
          child: _GlobeThumbnailMarker(assetId: entry.$2),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isRotating = widget.rotationNotifier.value;

    // Skip expensive projection computation while the overlay is invisible.
    final markers = isRotating ? const <Widget>[] : _buildMarkers();

    return AnimatedOpacity(
      opacity: isRotating ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        child: Stack(children: markers),
      ),
    );
  }
}

// ── Thumbnail marker ──────────────────────────────────────────────────────────

/// 44×44 dp rounded photo thumbnail rendered at a projected globe point (M169).
class _GlobeThumbnailMarker extends StatefulWidget {
  const _GlobeThumbnailMarker({required this.assetId});

  final String assetId;

  @override
  State<_GlobeThumbnailMarker> createState() => _GlobeThumbnailMarkerState();
}

class _GlobeThumbnailMarkerState extends State<_GlobeThumbnailMarker> {
  static const _channel = ThumbnailChannel();

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // Check LRU cache first — avoids a redundant channel call.
    final cached = ThumbnailLruCache.instance.get(widget.assetId);
    if (cached != null) {
      if (mounted) setState(() => _bytes = cached);
      return;
    }
    final bytes = await _channel.getThumbnail(widget.assetId, size: 88);
    if (bytes != null) ThumbnailLruCache.instance.put(widget.assetId, bytes);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;

    if (bytes == null) {
      // Grey placeholder while the thumbnail loads.
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    // White-bordered rounded thumbnail.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        image: DecorationImage(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
