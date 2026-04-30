import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_models/shared_models.dart';

import '../shared/thumbnail_channel.dart';

/// Bottom sheet for selecting a background photo for a card (M93, ADR-138).
///
/// Shows hero image candidates for the current trip selection, then a grid of
/// recent library photos. Returns the selected [assetId] (a local PHAsset
/// identifier) via [Navigator.pop], or null for "no background".
class CardBackgroundPicker extends StatefulWidget {
  const CardBackgroundPicker({
    super.key,
    required this.heroImages,
    this.currentAssetId,
  });

  /// Hero image candidates for the current card (from M89 analysis).
  final List<HeroImage> heroImages;

  /// Currently selected background asset ID, if any.
  final String? currentAssetId;

  /// Sentinel value returned when the user explicitly chooses "No background".
  /// Distinct from null (sheet dismissed without any selection).
  static const noBackground = '__none__';

  @override
  State<CardBackgroundPicker> createState() => _CardBackgroundPickerState();
}

class _CardBackgroundPickerState extends State<CardBackgroundPicker> {
  static const _thumb = ThumbnailChannel();

  final Map<String, Uint8List?> _heroThumbs = {};
  List<AssetEntity> _recentAssets = [];
  bool _loadingLibrary = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadHeroThumbnails();
    _loadRecentAssets();
  }

  Future<void> _loadHeroThumbnails() async {
    for (final hero in widget.heroImages) {
      if (hero.assetId.isEmpty) continue;
      final bytes = await _thumb.getThumbnail(hero.assetId, size: 200);
      if (mounted) setState(() => _heroThumbs[hero.assetId] = bytes);
    }
  }

  Future<void> _loadRecentAssets() async {
    setState(() => _loadingLibrary = true);
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _loadingLibrary = false;
        });
      }
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loadingLibrary = false);
      return;
    }
    final recent = await albums.first.getAssetListRange(start: 0, end: 30);
    if (mounted) {
      setState(() {
        _recentAssets = recent;
        _loadingLibrary = false;
      });
    }
  }

  void _select(String? assetId) =>
      Navigator.of(context).pop(assetId ?? CardBackgroundPicker.noBackground);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Photo Background',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _PickerTile(
                          label: 'No background',
                          icon: Icons.hide_image_outlined,
                          isSelected: widget.currentAssetId == null,
                          onTap: () => _select(null),
                        ),
                      ),
                    ),
                    if (widget.heroImages.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'HERO PHOTOS',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white38,
                                letterSpacing: 0.8),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: widget.heroImages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final hero = widget.heroImages[i];
                              final thumb = _heroThumbs[hero.assetId];
                              return GestureDetector(
                                onTap: () => _select(hero.assetId),
                                child: _ThumbnailCell(
                                  bytes: thumb,
                                  isSelected:
                                      widget.currentAssetId == hero.assetId,
                                  size: 96,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'RECENT PHOTOS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white38,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ),
                    if (_permissionDenied)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Photo library access denied.\nEnable in Settings to browse.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 13, color: Colors.white38),
                          ),
                        ),
                      )
                    else if (_loadingLibrary)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                              child:
                                  CircularProgressIndicator.adaptive()),
                        ),
                      )
                    else
                      SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final asset = _recentAssets[i];
                            return GestureDetector(
                              onTap: () => _select(asset.id),
                              child: _AssetCell(
                                asset: asset,
                                isSelected:
                                    widget.currentAssetId == asset.id,
                              ),
                            );
                          },
                          childCount: _recentAssets.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFD4A017);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? amber : Colors.white24,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
          color:
              isSelected ? amber.withValues(alpha: 0.10) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? amber : Colors.white54),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: amber),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({
    required this.bytes,
    required this.isSelected,
    required this.size,
  });

  final Uint8List? bytes;
  final bool isSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: const Color(0xFFD4A017), width: 2.5)
            : null,
        color: Colors.white10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSelected ? 6 : 8),
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
      ),
    );
  }
}

class _AssetCell extends StatefulWidget {
  const _AssetCell({required this.asset, required this.isSelected});

  final AssetEntity asset;
  final bool isSelected;

  @override
  State<_AssetCell> createState() => _AssetCellState();
}

class _AssetCellState extends State<_AssetCell> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: widget.isSelected
            ? Border.all(color: const Color(0xFFD4A017), width: 2.5)
            : null,
      ),
      child: _thumb != null
          ? Image.memory(_thumb!, fit: BoxFit.cover)
          : Container(color: Colors.white10),
    );
  }
}
