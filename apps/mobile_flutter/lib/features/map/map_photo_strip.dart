import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../shared/thumbnail_channel.dart';
import 'thumbnail_lru_cache.dart';

/// 3-column photo grid shown below the flat map — mirrors the Google Photos
/// map experience where a grid of location-tagged photos sits in a panel
/// below the map, viewport-synced and newest-first.
class MapPhotoStrip extends ConsumerWidget {
  const MapPhotoStrip({super.key});

  static const _maxPhotos = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const SizedBox.shrink();

    final locationsAsync = ref.watch(photoLocationsProvider);
    final locations = locationsAsync.valueOrNull;
    if (locations == null || locations.isEmpty) return const SizedBox.shrink();

    final vp = ref.watch(mapViewportProvider);

    final List<PhotoLocation> pool;
    if (vp != null) {
      pool = locations
          .where((loc) =>
              loc.lat >= vp.south &&
              loc.lat <= vp.north &&
              loc.lng >= vp.west &&
              loc.lng <= vp.east)
          .toList();
    } else {
      pool = locations;
    }

    if (pool.isEmpty) return const SizedBox.shrink();

    final capped =
        pool.length > _maxPhotos ? pool.sublist(pool.length - _maxPhotos) : pool;
    final photos = capped.reversed.toList();
    final assetIds = photos.map((p) => p.assetId).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileSize =
        (MediaQuery.of(context).size.width - 4) / 3; // 2px gaps between 3 cols
    // Show 2 full rows + a sliver of the 3rd so it's obvious the grid scrolls.
    final panelHeight = tileSize * 2 + 2;

    return SizedBox(
      height: panelHeight,
      child: ColoredBox(
        color: isDark ? const Color(0xDD050510) : const Color(0xDDFFFFFF),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) => _GridTile(
            key: ValueKey(photos[i].assetId),
            assetId: photos[i].assetId,
            onTap: () => Navigator.of(context).push(
              _MapPhotoViewer.route(
                assetIds: assetIds,
                initialIndex: i,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Grid tile ─────────────────────────────────────────────────────────────────

class _GridTile extends StatefulWidget {
  const _GridTile({super.key, required this.assetId, required this.onTap});

  final String assetId;
  final VoidCallback onTap;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  Uint8List? _bytes;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final cached = ThumbnailLruCache.instance.get(widget.assetId);
    if (cached != null) {
      _bytes = cached;
      _visible = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final bytes =
        await const ThumbnailChannel().getThumbnail(widget.assetId, size: 150);
    if (bytes != null) ThumbnailLruCache.instance.put(widget.assetId, bytes);
    if (mounted) {
      setState(() => _bytes = bytes);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_bytes == null) {
      content = Container(color: Colors.grey.shade800);
    } else {
      content = AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _visible ? 1.0 : 0.0,
        child: Image.memory(_bytes!, fit: BoxFit.cover),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      // Hero tag enables the shared-element zoom from grid to full-screen viewer.
      // Only wrap when image is loaded so we don't animate a grey placeholder.
      child: _bytes != null
          ? Hero(tag: 'map_photo_${widget.assetId}', child: content)
          : content,
    );
  }
}

// ── Full-screen viewer ────────────────────────────────────────────────────────

/// Full-screen photo viewer matching the Google Photos map viewer pattern:
/// - Swipe left/right to browse all photos in the current viewport set
/// - Swipe down to dismiss (velocity-based)
/// - Black background, edge-to-edge
/// - Top bar: close + photo count
/// - Bottom bar: share
class _MapPhotoViewer extends StatefulWidget {
  const _MapPhotoViewer({
    required this.assetIds,
    required this.initialIndex,
  });

  final List<String> assetIds;
  final int initialIndex;

  static Route<void> route({
    required List<String> assetIds,
    required int initialIndex,
  }) {
    return PageRouteBuilder<void>(
      opaque: true, // Hero shared-element animation requires an opaque route
      pageBuilder: (_, __, ___) => _MapPhotoViewer(
        assetIds: assetIds,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<_MapPhotoViewer> createState() => _MapPhotoViewerState();
}

class _MapPhotoViewerState extends State<_MapPhotoViewer> {
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
                  heroTag: i == widget.initialIndex
                      ? 'map_photo_${widget.assetIds[i]}'
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
    // Show cached thumbnail immediately (no flash/spinner for photos in grid).
    _bytes = ThumbnailLruCache.instance.get(widget.assetId);
    _loadHiRes();
  }

  Future<void> _loadHiRes() async {
    final hi =
        await const ThumbnailChannel().getThumbnail(widget.assetId, size: 800);
    if (hi != null) {
      ThumbnailLruCache.instance.put(widget.assetId, hi);
      if (mounted) setState(() => _bytes = hi);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    Widget image = Image.memory(_bytes!, fit: BoxFit.contain);
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }
    return InteractiveViewer(child: Center(child: image));
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
