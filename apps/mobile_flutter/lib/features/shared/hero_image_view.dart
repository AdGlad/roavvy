import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'thumbnail_channel.dart';

/// Displays a hero image loaded on-demand from a local PHAsset [assetId].
///
/// States:
/// - [assetId] null → solid [fallbackColor] tile immediately.
/// - Loading → animated shimmer pulse.
/// - Loaded → displays decoded JPEG via [Image.memory].
/// - Failed (iCloud-only, deleted, permission) → solid [fallbackColor] tile.
///
/// The optional [onEditTap] callback, when provided, renders a pencil icon
/// in the top-right corner. Tapping it calls [onEditTap].
///
/// ADR-135: photo bytes are never persisted to Drift or Firestore.
class HeroImageView extends StatefulWidget {
  const HeroImageView({
    super.key,
    required this.assetId,
    required this.fallbackColor,
    this.height = 160.0,
    this.onEditTap,
    this.fit = BoxFit.cover,
    this.thumbnailSize = 600,
  });

  /// PHAsset local identifier. Null → show [fallbackColor] immediately.
  final String? assetId;

  /// Shown when no image is available (null assetId or failed load).
  final Color fallbackColor;

  /// Widget height. Width is always [double.infinity].
  final double height;

  /// When non-null, a pencil icon is shown in the top-right corner.
  final VoidCallback? onEditTap;

  final BoxFit fit;

  /// Pixel size of the requested thumbnail (square). Capped at 600 by default.
  final int thumbnailSize;

  @override
  State<HeroImageView> createState() => _HeroImageViewState();
}

class _HeroImageViewState extends State<HeroImageView>
    with SingleTickerProviderStateMixin {
  static const _channel = ThumbnailChannel();

  Uint8List? _bytes;
  bool _loading = false;

  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    if (widget.assetId != null) {
      _loadThumbnail(widget.assetId!);
    }
  }

  @override
  void didUpdateWidget(HeroImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      if (widget.assetId == null) {
        setState(() {
          _bytes = null;
          _loading = false;
        });
      } else if (widget.assetId != oldWidget.assetId) {
        setState(() {
          _bytes = null;
          _loading = false;
        });
        _loadThumbnail(widget.assetId!);
      }
    }
  }

  Future<void> _loadThumbnail(String assetId) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    final bytes = await _channel.getThumbnail(
      assetId,
      size: widget.thumbnailSize,
    );

    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_loading) {
      child = AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (_, __) => Container(
          color: widget.fallbackColor.withValues(alpha: _shimmerAnim.value),
        ),
      );
    } else if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: double.infinity,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    } else {
      // null assetId or failed load → solid colour fallback.
      child = Container(color: widget.fallbackColor);
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(child: child),
          if (widget.onEditTap != null)
            Positioned(
              top: 8,
              right: 8,
              child: _EditButton(onTap: widget.onEditTap!),
            ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.edit, color: Colors.white, size: 16),
      ),
    );
  }
}
