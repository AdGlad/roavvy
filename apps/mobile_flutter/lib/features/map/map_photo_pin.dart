import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../shared/thumbnail_channel.dart';
import 'thumbnail_lru_cache.dart';

/// The photo currently highlighted on the map — set by scrolling the photo
/// grid (scrubbing) or tapping a heatmap blob, mirroring Google Photos'
/// "Your Map" current-photo pin.
final selectedMapPhotoProvider = StateProvider<PhotoLocation?>((ref) => null);

/// Google Photos-style current-photo pin: a circular thumbnail inside a thick
/// white ring with a short tail down to a small dark anchor dot at the exact
/// photo location. The thumbnail crossfades when the selection changes.
class PhotoPinLayer extends ConsumerWidget {
  const PhotoPinLayer({super.key});

  static const double _pinSize = 64.0;
  static const double _ringWidth = 4.0;
  static const double _tailHeight = 8.0;
  static const double _anchorSize = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMapPhotoProvider);
    if (selected == null) return const SizedBox.shrink();

    const totalH = _pinSize + _tailHeight + _anchorSize;
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(selected.lat, selected.lng),
          width: _pinSize + _ringWidth * 2,
          height: totalH,
          // Anchor dot (bottom of the column) sits on the coordinate.
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PinThumbnail(
                key: ValueKey(selected.assetId),
                assetId: selected.assetId,
                size: _pinSize,
                ringWidth: _ringWidth,
              ),
              // Tail connecting the pin to the anchor dot.
              Container(
                width: 2.5,
                height: _tailHeight,
                color: Colors.white,
              ),
              // Dark anchor dot with a white halo ring.
              Container(
                width: _anchorSize,
                height: _anchorSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E3F4A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ),
      ],
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

  static const double _minZoom = 10.0;
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

    final stride = locations.length <= PhotoAnchorDotsLayer._maxDots
        ? 1
        : (locations.length / PhotoAnchorDotsLayer._maxDots).ceil();
    for (int i = 0; i < locations.length; i += stride) {
      final loc = locations[i];
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
