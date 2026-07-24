import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/photo_gps_repository.dart';
import '../shared/thumbnail_channel.dart';
import 'map_photo_viewer.dart';
import 'thumbnail_lru_cache.dart';

/// Google Photos-style photo panel under the flat map: rounded-top sheet with
/// a drag handle, a live "N photos" count for the visible map region, and a
/// 4-column newest-first grid.
///
/// Collapses to just its header (tap or drag the header to toggle) so the
/// map keeps its full height by default.
///
/// Bidirectional scrubbing (mirrors Google Photos "Your Map"):
/// - scrolling the grid moves the map's photo pin to the top-visible photo
///   (via [selectedMapPhotoProvider])
/// - an external selection (tapping a heat blob on the map) scrolls the grid
///   to that photo
class MapPhotoStrip extends ConsumerStatefulWidget {
  const MapPhotoStrip({super.key});

  /// Header block height (drag handle + count label) — the collapsed height.
  static const double _headerHeight = 36.0;

  /// Panel height for [screenWidth] — used by MapScreen to offset the UI
  /// stacked above the panel.
  static double panelHeight(double screenWidth, {required bool expanded}) =>
      expanded ? (screenWidth - 6) / 4 * 2 + 2 + _headerHeight : _headerHeight;

  @override
  ConsumerState<MapPhotoStrip> createState() => _MapPhotoStripState();
}

class _MapPhotoStripState extends ConsumerState<MapPhotoStrip> {
  final _scroll = ScrollController();
  List<PhotoLocation> _photos = const [];
  double _rowExtent = 1.0;
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Grid scrub → pin: select the first photo of the top visible row.
  void _onScroll() {
    if (_programmaticScroll || _photos.isEmpty) return;
    final row = (_scroll.offset / _rowExtent).round();
    final idx = (row * 4).clamp(0, _photos.length - 1);
    final photo = _photos[idx];
    if (ref.read(selectedMapPhotoProvider)?.assetId != photo.assetId) {
      ref.read(selectedMapPhotoProvider.notifier).state = photo;
    }
  }

  /// Pin (heat tap) → grid: scroll so the selected photo's row is on top.
  void _scrollToAsset(String assetId) {
    final idx = _photos.indexWhere((p) => p.assetId == assetId);
    if (idx < 0 || !_scroll.hasClients) return;
    final targetOffset = (idx ~/ 4) * _rowExtent;
    // Skip if that row is already within the visible band (avoid fighting
    // the user's own scroll, which is what set the selection).
    final visibleTop = _scroll.offset - _rowExtent * 0.5;
    final visibleBottom = _scroll.offset + _rowExtent * 1.5;
    if (targetOffset >= visibleTop && targetOffset <= visibleBottom) return;
    _programmaticScroll = true;
    _scroll
        .animateTo(
          targetOffset.clamp(0.0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _programmaticScroll = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(showPhotoThumbnailsProvider)) return const SizedBox.shrink();

    final locationsAsync = ref.watch(photoLocationsProvider);
    final locations = locationsAsync.valueOrNull;
    if (locations == null || locations.isEmpty) return const SizedBox.shrink();

    final sortAnchor = ref.watch(mapGallerySortAnchorProvider);
    // Only watch the viewport when it actually matters (no anchor set) — the
    // grid stays viewport-stable and doesn't rebuild from panning while
    // browsing a distance-sorted selection.
    final viewport = sortAnchor == null ? ref.watch(mapViewportProvider) : null;
    final gallery = computeMapGalleryPhotos(
      locations: locations,
      sortAnchor: sortAnchor,
      viewport: viewport,
    );
    if (gallery.photos.isEmpty) return const SizedBox.shrink();
    final photos = gallery.photos;
    final displayCount = gallery.totalCount;
    final assetIds = photos.map((p) => p.assetId).toList();
    _photos = photos;

    ref.listen<PhotoLocation?>(selectedMapPhotoProvider, (_, next) {
      if (next != null) _scrollToAsset(next.assetId);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final tileSize = (screenWidth - 6) / 4; // 2px gaps between 4 cols
    _rowExtent = tileSize + 2;

    final expanded = ref.watch(mapPhotoPanelExpandedProvider);
    void setExpanded(bool value) =>
        ref.read(mapPhotoPanelExpandedProvider.notifier).state = value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: MapPhotoStrip.panelHeight(screenWidth, expanded: expanded),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF2101014) : const Color(0xF7FFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setExpanded(!expanded),
            onVerticalDragEnd: (d) {
              final vy = d.velocity.pixelsPerSecond.dy;
              if (vy < -100) setExpanded(true);
              if (vy > 100) setExpanded(false);
            },
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$displayCount ${displayCount == 1 ? 'photo' : 'photos'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: _scroll,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: photos.length,
              itemBuilder: (context, i) => _GridTile(
                key: ValueKey(photos[i].assetId),
                assetId: photos[i].assetId,
                onTap: () {
                  ref.read(selectedMapPhotoProvider.notifier).state = photos[i];
                  Navigator.of(context).push(
                    MapPhotoViewer.route(
                      assetIds: assetIds,
                      initialIndex: i,
                      heroTag: 'map_photo_${photos[i].assetId}',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
