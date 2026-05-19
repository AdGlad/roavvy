import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'card_branding_footer.dart';
import 'card_text_renderer.dart';
import 'flag_grid_layout_engine.dart';
import 'flag_tile_renderer.dart';
import 'grid_math_engine.dart';
import 'heart_layout_engine.dart';
import 'paper_texture_painter.dart';
import 'passport_layout_engine.dart';
import 'passport_stamp_model.dart';
import 'stamp_asset_loader.dart';
import 'stamp_painter.dart';

import '../../core/landmark_icons.dart';

// ── LandmarkFlagsCard ─────────────────────────────────────────────────────────

/// Travel card template: stylized landmark icons arranged in a grid.
class LandmarkFlagsCard extends StatefulWidget {
  const LandmarkFlagsCard({
    super.key,
    required this.countryCodes,
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
    this.titleOverride,
    this.subtitleOverride,
    this.transparentBackground = false,
    this.textColor,
    this.onAssetsLoaded,
    this.layoutMode = FlagGridLayoutMode.packedRow,
  });

  final List<String> countryCodes;
  final double aspectRatio;
  final String? titleOverride;
  final String? subtitleOverride;
  final String dateLabel;
  final bool transparentBackground;
  final Color? textColor;
  final VoidCallback? onAssetsLoaded;
  final FlagGridLayoutMode layoutMode;

  @override
  State<LandmarkFlagsCard> createState() => _LandmarkFlagsCardState();
}

class _LandmarkFlagsCardState extends State<LandmarkFlagsCard> {
  final _repaintNotifier = ValueNotifier<int>(0);
  bool _preloadStarted = false;
  bool _onAssetsLoadedFired = false;

  @override
  void didUpdateWidget(LandmarkFlagsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCodes != widget.countryCodes) {
      _preloadStarted = false;
      _onAssetsLoadedFired = false;
    }
  }

  @override
  void dispose() {
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _preloadLandmarks(double reprWidth) {
    if (reprWidth <= 0 || _preloadStarted) return;
    _preloadStarted = true;

    final List<(String, String)> toLoad = [];
    for (final code in widget.countryCodes) {
      final path = getLandmarkPath(code);
      if (path != null && _LandmarkPainter._sharedCache.get('landmark_$code', reprWidth) == null) {
        toLoad.add((code, path));
      }
    }

    if (toLoad.isEmpty) {
      _fireOnAssetsLoaded();
      return;
    }

    var remaining = toLoad.length;
    for (final entry in toLoad) {
      LandmarkTileRenderer.loadLandmarkToCache(entry.$1, entry.$2, reprWidth, _LandmarkPainter._sharedCache)
          .then((img) {
        if (mounted && img != null) _repaintNotifier.value++;
        remaining--;
        if (remaining == 0) _fireOnAssetsLoaded();
      });
    }
  }

  void _fireOnAssetsLoaded() {
    if (_onAssetsLoadedFired) return;
    _onAssetsLoadedFired = true;
    widget.onAssetsLoaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = widget.titleOverride ??
        '${widget.countryCodes.length} ${widget.countryCodes.length == 1 ? 'Country' : 'Countries'}'
            '${widget.dateLabel.isNotEmpty ? ' \u00B7 ${widget.dateLabel}' : ''}';

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          const topH = CardTextRenderer.titleZoneH;
          const botH = CardTextRenderer.brandingZoneH;
          final gridH = (size.height - topH - botH).clamp(1.0, double.infinity);
          final gridSize = Size(size.width, gridH);
          final reprWidth = FlagGridLayoutEngine.representativeTileWidth(
              gridSize, widget.countryCodes.length);
          _preloadLandmarks(reprWidth);

          return CustomPaint(
            size: size,
            painter: _LandmarkPainter(
              countryCodes: widget.countryCodes,
              canvasSize: size,
              repaintNotifier: _repaintNotifier,
              title: effectiveTitle,
              dateLabel: widget.dateLabel,
              subtitleOverride: widget.subtitleOverride,
              layoutMode: widget.layoutMode,
              reprWidth: reprWidth,
              transparentBackground: widget.transparentBackground,
              textColor: widget.textColor,
            ),
          );
        },
      ),
    );
  }
}

class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter({
    required this.countryCodes,
    required this.canvasSize,
    required ValueNotifier<int> repaintNotifier,
    required this.title,
    required this.dateLabel,
    this.subtitleOverride,
    this.layoutMode = FlagGridLayoutMode.packedRow,
    required this.reprWidth,
    this.transparentBackground = false,
    this.textColor,
  }) : super(repaint: repaintNotifier);

  final List<String> countryCodes;
  final Size canvasSize;
  final String title;
  final String dateLabel;
  final String? subtitleOverride;
  final FlagGridLayoutMode layoutMode;
  final double reprWidth;
  final bool transparentBackground;
  final Color? textColor;

  static final _sharedCache = FlagImageCache();
  static const _topH = CardTextRenderer.titleZoneH;
  static const _botH = CardTextRenderer.brandingZoneH;

  @override
  void paint(Canvas canvas, Size size) {
    if (!transparentBackground) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0D2137));
    }

    final effectiveTextColor = textColor ?? CardTextRenderer.defaultTextColor;
    final effectiveStripColor = transparentBackground ? Colors.transparent : CardTextRenderer.defaultStripColor;

    CardTextRenderer.drawTitle(canvas, size, title, textColor: effectiveTextColor, stripColor: effectiveStripColor);
    CardTextRenderer.drawBranding(canvas, size, countryCount: countryCodes.length, dateLabel: dateLabel, subtitleLine: subtitleOverride, textColor: effectiveTextColor, stripColor: effectiveStripColor);

    if (countryCodes.isEmpty) return;
    
    final tiles = FlagGridLayoutEngine.compute(
      codes: countryCodes,
      canvasSize: size,
      topOffset: _topH,
      bottomOffset: _botH,
      mode: layoutMode,
    );

    for (final tile in tiles) {
      final path = getLandmarkPath(tile.code);
      if (path != null) {
        LandmarkTileRenderer.renderFromCache(
          canvas, 
          tile.code, 
          tile.rect, 
          _sharedCache,
          color: effectiveTextColor, // Draw landmarks in title/text color for consistency
        );
      } else {
        // Fallback to emoji flag if no landmark icon available
        _drawEmoji(canvas, tile.code, tile.rect);
      }
    }
  }

  void _drawEmoji(Canvas canvas, String code, Rect dst) {
    final emoji = _flagEmoji(code);
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: dst.width * 0.7)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(dst.left + (dst.width - tp.width) / 2, dst.top + (dst.height - tp.height) / 2));
  }

  String _flagEmoji(String code) {
    if (code.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCode(base + code.codeUnitAt(0) - 65) + String.fromCharCode(base + code.codeUnitAt(1) - 65);
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) => true;
}

String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

// ── Grid tile-size helper (ADR-102 / ADR-118) ─────────────────────────────────

/// Backward-compatible delegate to [gridLayout] (ADR-118).
///
/// Retained for any callers that use the old `(canvasArea, n)` signature.
/// New code should call [gridLayout] directly.
@visibleForTesting
double gridTileSize(double canvasArea, int n) {
  assert(n > 0, 'n must be > 0');
  // Approximate a square canvas from the area so the delegate is meaningful.
  final side = math.sqrt(canvasArea);
  return gridLayout(Size(side, side), n).tileSize;
}

// ── GridFlagsCard ─────────────────────────────────────────────────────────────

/// Travel card template: real SVG flags arranged in a geometric grid.
///
/// Dark navy background. The grid calculates optimal dimensions using
/// [GridMathEngine] to pack flags into the available space. SVG flag images
/// are loaded asynchronously; emoji fallbacks are shown on first render
/// (ADR-123).
class GridFlagsCard extends StatefulWidget {
  const GridFlagsCard({
    super.key,
    required this.countryCodes,
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
    this.titleOverride,
    this.subtitleOverride,
    this.transparentBackground = false,
    this.textColor,
    this.onAssetsLoaded,
    this.backgroundImageBytes,
    this.layoutMode = FlagGridLayoutMode.packedRow,
  });

  final List<String> countryCodes;
  final double aspectRatio;
  final String? titleOverride;

  /// Structured branding line forwarded to [CardTextRenderer.drawBranding]
  /// (ADR-157). When non-null replaces the legacy ROAVVY + count content.
  final String? subtitleOverride;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  /// When `true`, renders with a transparent background instead of the default
  /// dark navy. Used by [CardImageRenderer] for t-shirt compositing (ADR-123).
  final bool transparentBackground;

  /// Text colour for title and branding zones. When null and
  /// [transparentBackground] is false, the default gold colour is used.
  /// When [transparentBackground] is true, this should be set explicitly
  /// (e.g. [Colors.black] on white shirts).
  final Color? textColor;

  /// Called once when all SVG flag assets have finished loading into the shared
  /// cache. Used by [CardImageRenderer] to delay PNG capture until SVGs are
  /// ready (ADR-123).
  final VoidCallback? onAssetsLoaded;

  /// Optional background photo bytes (JPEG). When non-null, drawn beneath flag
  /// tiles at 55% opacity with a dark vignette (M93, ADR-138).
  final Uint8List? backgroundImageBytes;

  /// Layout algorithm for positioning flags (M106, ADR-156).
  /// Defaults to [FlagGridLayoutMode.packedRow].
  final FlagGridLayoutMode layoutMode;

  @override
  State<GridFlagsCard> createState() => _GridFlagsCardState();
}

class _GridFlagsCardState extends State<GridFlagsCard> {
  // ValueNotifier is a ChangeNotifier subclass that can be incremented from any
  // class without needing to call the protected notifyListeners() (ADR-123).
  final _repaintNotifier = ValueNotifier<int>(0);
  bool _preloadStarted = false;
  bool _onAssetsLoadedFired = false;

  // Background image decoded from backgroundImageBytes (M93, ADR-138).
  ui.Image? _backgroundImage;

  @override
  void initState() {
    super.initState();
    if (widget.backgroundImageBytes != null) {
      _decodeBackgroundImage(widget.backgroundImageBytes!);
    }
  }

  @override
  void didUpdateWidget(GridFlagsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the country list changes (e.g. user deselects a country), the grid
    // layout recalculates — different cols → different tileWidth → different
    // cache key. Reset the preload guard so _preloadSvgs re-runs at the new
    // tileWidth and fills the cache for the updated layout.
    if (oldWidget.countryCodes != widget.countryCodes) {
      _preloadStarted = false;
      _onAssetsLoadedFired = false;
    }
    if (oldWidget.backgroundImageBytes != widget.backgroundImageBytes) {
      if (widget.backgroundImageBytes == null) {
        setState(() => _backgroundImage = null);
      } else {
        _decodeBackgroundImage(widget.backgroundImageBytes!);
      }
    }
  }

  Future<void> _decodeBackgroundImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _backgroundImage = frame.image);
  }

  @override
  void dispose() {
    _repaintNotifier.dispose();
    _backgroundImage?.dispose();
    super.dispose();
  }

  /// Schedules async SVG loading for all country codes at [reprWidth].
  ///
  /// [reprWidth] is a representative tile width derived from grid area / n —
  /// consistent across all layout modes so the cache is always hit at render
  /// time. Fires [widget.onAssetsLoaded] exactly once when all pending loads
  /// complete (or immediately if nothing needs loading).
  /// Guards against being called multiple times from [LayoutBuilder].
  void _preloadSvgs(double reprWidth) {
    if (reprWidth <= 0 || _preloadStarted) return;
    _preloadStarted = true;

    final toLoad = widget.countryCodes
        .where((code) =>
            FlagTileRenderer.hasSvg(code) &&
            _GridPainter._sharedCache.get(code, reprWidth) == null)
        .toList();

    if (toLoad.isEmpty) {
      _fireOnAssetsLoaded();
      return;
    }

    var remaining = toLoad.length;
    for (final code in toLoad) {
      FlagTileRenderer.loadSvgToCache(code, reprWidth, _GridPainter._sharedCache)
          .then((img) {
        if (mounted && img != null) _repaintNotifier.value++;
        remaining--;
        if (remaining == 0) _fireOnAssetsLoaded();
      });
    }
  }

  void _fireOnAssetsLoaded() {
    if (_onAssetsLoadedFired) return;
    _onAssetsLoadedFired = true;
    widget.onAssetsLoaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.countryCodes.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: const Color(0xFF0D2137),
          child: const Center(
            child: Text(
              'Scan your photos\nto fill your card',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final effectiveTitle = widget.titleOverride ??
        '${widget.countryCodes.length} ${widget.countryCodes.length == 1 ? 'Country' : 'Countries'}'
            '${widget.dateLabel.isNotEmpty ? ' \u00B7 ${widget.dateLabel}' : ''}';

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      // All rendering (flags + text zones) is done in _GridPainter so the
      // captured PNG contains title and branding without any widget overlays.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          // Use a representative tile width that is consistent across all
          // layout modes: sqrt(gridArea / n). The cache key is the same at
          // pre-load and render time (ADR-156).
          const topH = CardTextRenderer.titleZoneH;
          const botH = CardTextRenderer.brandingZoneH;
          final gridH = (size.height - topH - botH).clamp(1.0, double.infinity);
          final gridSize = Size(size.width, gridH);
          final reprWidth = FlagGridLayoutEngine.representativeTileWidth(
              gridSize, widget.countryCodes.length);
          _preloadSvgs(reprWidth);

          return CustomPaint(
            size: size,
            painter: _GridPainter(
              countryCodes: widget.countryCodes,
              canvasSize: size,
              repaintNotifier: _repaintNotifier,
              title: effectiveTitle,
              dateLabel: widget.dateLabel,
              subtitleOverride: widget.subtitleOverride,
              backgroundImage: _backgroundImage,
              layoutMode: widget.layoutMode,
              reprWidth: reprWidth,
              transparentBackground: widget.transparentBackground,
              textColor: widget.textColor,
            ),
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.countryCodes,
    required this.canvasSize,
    required ValueNotifier<int> repaintNotifier,
    required this.title,
    required this.dateLabel,
    this.subtitleOverride,
    this.backgroundImage,
    this.layoutMode = FlagGridLayoutMode.packedRow,
    required this.reprWidth,
    this.transparentBackground = false,
    this.textColor,
  }) : super(repaint: repaintNotifier);

  final List<String> countryCodes;
  final Size canvasSize;

  /// Full title string drawn in the top zone (e.g. "12 Countries · 2024").
  final String title;

  /// Date label forwarded to [CardTextRenderer.drawBranding].
  final String dateLabel;

  /// Structured branding line (ADR-157). When non-null, replaces legacy branding.
  final String? subtitleOverride;

  /// Optional decoded background photo (M93, ADR-138).
  final ui.Image? backgroundImage;

  /// Layout algorithm (M106, ADR-156).
  final FlagGridLayoutMode layoutMode;

  /// Representative tile width used as the SVG cache key (ADR-156).
  final double reprWidth;

  /// When true, text strips are fully transparent (for t-shirt compositing).
  final bool transparentBackground;

  /// Text colour for title and branding zones.
  final Color? textColor;

  // Shared across all _GridPainter instances and accessible from
  // _GridFlagsCardState for SVG preloading (ADR-123).
  static final _sharedCache = FlagImageCache();

  // Transparent placeholder shown while an SVG loads asynchronously.
  static final _placeholderPaint = Paint()..color = Colors.transparent;

  // Text zone constants (mirrors CardTextRenderer).
  static const _topH = CardTextRenderer.titleZoneH;
  static const _botH = CardTextRenderer.brandingZoneH;

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Background photo layer (M93, ADR-138).
    if (backgroundImage != null) {
      _drawBackgroundPhoto(canvas, size, backgroundImage!, opacity: 0.55);
      // Dark vignette for flag readability.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: const [Colors.transparent, Color(0x55000000)],
          ).createShader(Offset.zero & size),
      );
    }

    // 1. Text zones (drawn first so flags sit on top if text is transparent).
    final effectiveStripColor = transparentBackground
        ? Colors.transparent
        : CardTextRenderer.defaultStripColor;
    final effectiveTextColor =
        textColor ?? CardTextRenderer.defaultTextColor;
    CardTextRenderer.drawTitle(canvas, size, title,
        textColor: effectiveTextColor, stripColor: effectiveStripColor);
    CardTextRenderer.drawBranding(
      canvas,
      size,
      countryCount: countryCodes.length,
      dateLabel: dateLabel,
      subtitleLine: subtitleOverride,
      textColor: effectiveTextColor,
      stripColor: effectiveStripColor,
    );

    // 2. Flag grid in the zone between title and branding strips (ADR-156).
    if (countryCodes.isEmpty) return;
    if (size.width <= 0 || size.height <= 0) return;

    final tiles = FlagGridLayoutEngine.compute(
      codes: countryCodes,
      canvasSize: size,
      topOffset: _topH,
      bottomOffset: _botH,
      mode: layoutMode,
    );
    if (tiles.isEmpty) return;

    for (final tile in tiles) {
      final cached = _sharedCache.get(tile.code, reprWidth);
      if (cached != null) {
        FlagTileRenderer.drawContained(canvas, cached, tile.rect,
            cornerRadius: 0.0);
      } else {
        // Placeholder while SVG loads — transparent rect.
        canvas.drawRect(tile.rect, _placeholderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.countryCodes != countryCodes ||
      old.canvasSize != canvasSize ||
      old.title != title ||
      old.dateLabel != dateLabel ||
      old.subtitleOverride != subtitleOverride ||
      old.backgroundImage != backgroundImage ||
      old.layoutMode != layoutMode ||
      old.reprWidth != reprWidth ||
      old.transparentBackground != transparentBackground ||
      old.textColor != textColor;
}

/// Draws [image] cover-fitted to [size] at [opacity] (0.0–1.0). Shared by
/// _GridPainter and _MultiStampPainter (M93, ADR-138).
void _drawBackgroundPhoto(
  Canvas canvas,
  Size size,
  ui.Image image, {
  double opacity = 0.70,
}) {
  final imgW = image.width.toDouble();
  final imgH = image.height.toDouble();
  final canvasAR = size.width / size.height;
  final imgAR = imgW / imgH;

  final Rect src;
  if (imgAR > canvasAR) {
    final srcW = imgH * canvasAR;
    src = Rect.fromLTWH((imgW - srcW) / 2, 0, srcW, imgH);
  } else {
    final srcH = imgW / canvasAR;
    src = Rect.fromLTWH(0, (imgH - srcH) / 2, imgW, srcH);
  }

  canvas.drawImageRect(
    image,
    src,
    Offset.zero & size,
    Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
  );
}

// ── HeartRenderConfig ─────────────────────────────────────────────────────────

/// Visual configuration for [HeartFlagsCard].
class HeartRenderConfig {
  const HeartRenderConfig({
    this.gapWidth = 1.0,
    this.tileCornerRadius = 2.0,
    this.tileShadowOpacity = 0.0,
    this.edgeFeatherPx = 1.5,
  });

  /// White gap between tiles (pixels). Default 1.0.
  final double gapWidth;

  /// Rounded corner radius for each tile (pixels). Default 2.0.
  final double tileCornerRadius;

  /// Subtle drop shadow opacity per tile (0.0–0.3). Default 0.0.
  final double tileShadowOpacity;

  /// Heart edge feather softness in pixels. Default 1.5.
  final double edgeFeatherPx;
}

// ── HeartFlagsCard ────────────────────────────────────────────────────────────

/// Travel card template: a geometric heart composed of real SVG flag tiles.
///
/// The heart shape is formed by the flag tiles themselves, clipped at the heart
/// boundary with at least 66% of each tile visible. Uses the parametric heart
/// equation `(x²+y²−1)³−x²y³≤0` (ADR-098).
///
/// SVG flag images are loaded asynchronously; emoji fallbacks are shown on
/// first render (ADR-123).
class HeartFlagsCard extends StatefulWidget {
  const HeartFlagsCard({
    super.key,
    required this.countryCodes,
    this.trips = const [],
    this.flagOrder = HeartFlagOrder.randomized,
    this.config = const HeartRenderConfig(),
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
    this.titleOverride,
    this.onAssetsLoaded,
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final HeartFlagOrder flagOrder;
  final HeartRenderConfig config;
  final double aspectRatio;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  /// Optional user-supplied title; replaces the auto `"{N} countries"` label
  /// in [CardBrandingFooter] when non-null (ADR-120).
  final String? titleOverride;

  /// Called exactly once when all SVG flag assets have finished loading into
  /// the shared cache. Used by [CardImageRenderer] to delay PNG capture until
  /// SVGs are ready (ADR-151). If all assets were already cached, fires on the
  /// next post-frame callback.
  final VoidCallback? onAssetsLoaded;

  @override
  State<HeartFlagsCard> createState() => _HeartFlagsCardState();
}

class _HeartFlagsCardState extends State<HeartFlagsCard> {
  // ValueNotifier is a ChangeNotifier subclass that can be incremented from any
  // class without needing to call the protected notifyListeners() (ADR-123).
  final _repaintNotifier = ValueNotifier<int>(0);
  bool _preloadStarted = false;
  bool _onAssetsLoadedFired = false;

  @override
  void didUpdateWidget(HeartFlagsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCodes != widget.countryCodes) {
      _preloadStarted = false;
      _onAssetsLoadedFired = false;
    }
  }

  @override
  void dispose() {
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _fireOnAssetsLoaded() {
    if (_onAssetsLoadedFired) return;
    _onAssetsLoadedFired = true;
    widget.onAssetsLoaded?.call();
  }

  /// Schedules async SVG loading for all tiles produced by [HeartLayoutEngine]
  /// at [canvasSize]. Skips codes already in cache and codes without SVG assets.
  /// Fires [widget.onAssetsLoaded] exactly once when all pending loads complete,
  /// or on the next frame if nothing needed loading (ADR-151).
  void _preloadSvgsForSize(Size canvasSize) {
    if (_preloadStarted) return;
    _preloadStarted = true;

    final tiles = HeartLayoutEngine.layout(
      widget.countryCodes,
      canvasSize,
      order: widget.flagOrder,
      trips: widget.trips,
    );

    final futures = <Future<void>>[];
    for (final tile in tiles) {
      final code = tile.countryCode;
      final tileSize = tile.rect.width;
      if (tileSize <= 0) continue;
      if (!FlagTileRenderer.hasSvg(code)) continue;
      if (_HeartPainter._sharedCache.get(code, tileSize) != null) continue;
      futures.add(
        FlagTileRenderer.loadSvgToCache(code, tileSize, _HeartPainter._sharedCache)
            .then((img) {
          if (mounted && img != null) _repaintNotifier.value++;
        }),
      );
    }

    if (futures.isEmpty) {
      // All assets already cached — fire on the next frame so the caller's
      // OverlayEntry has been inserted before the capture callback runs.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fireOnAssetsLoaded();
      });
    } else {
      Future.wait(futures).then((_) {
        if (mounted) _fireOnAssetsLoaded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.countryCodes.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: const Color(0xFF0D2137),
          child: const Center(
            child: Text(
              'Scan your photos\nto fill your card',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _preloadSvgsForSize(size);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeartPainter(
                    countryCodes: widget.countryCodes,
                    trips: widget.trips,
                    flagOrder: widget.flagOrder,
                    config: widget.config,
                    canvasSize: size,
                    repaintNotifier: _repaintNotifier,
                    titleOverride: widget.titleOverride,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CardBrandingFooter(
                  countryCount: widget.countryCodes.length,
                  dateLabel: widget.dateLabel,
                  backgroundColor: const Color(0xCC0D2137),
                  customLabel: widget.titleOverride,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// CustomPainter that renders the heart composed of flag tiles.
class _HeartPainter extends CustomPainter {
  _HeartPainter({
    required this.countryCodes,
    required this.trips,
    required this.flagOrder,
    required this.config,
    required this.canvasSize,
    required ValueNotifier<int> repaintNotifier,
    this.titleOverride,
  }) : super(repaint: repaintNotifier);

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final HeartFlagOrder flagOrder;
  final HeartRenderConfig config;
  final Size canvasSize;
  final String? titleOverride;

  // Shared across all _HeartPainter instances and accessible from
  // _HeartFlagsCardState for SVG preloading (ADR-123).
  static final _sharedCache = FlagImageCache();

  @override
  void paint(Canvas canvas, Size size) {
    // Dark navy background behind the heart.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D2137),
    );

    // Draw title text BEFORE heart clip so it is not masked (ADR-123).
    if (titleOverride != null && titleOverride!.isNotEmpty) {
      _drawTitle(canvas, size, titleOverride!);
    }

    final tiles = HeartLayoutEngine.layout(
      countryCodes,
      size,
      order: flagOrder,
      trips: trips,
    );

    if (tiles.isEmpty) return;

    final heartPath = MaskCalculator.heartPath(size);

    // 1. Clip to heart and draw flag tiles.
    canvas.save();
    canvas.clipPath(heartPath, doAntiAlias: true);

    for (final tile in tiles) {
      FlagTileRenderer.renderFromCache(
        canvas,
        tile,
        _sharedCache,
        cornerRadius: config.tileCornerRadius,
        gapWidth: config.gapWidth,
      );
    }

    canvas.restore();

    // 2. dstIn feathered edge pass for smooth heart boundary.
    if (config.edgeFeatherPx > 0) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..blendMode = BlendMode.dstIn,
      );
      canvas.drawPath(
        heartPath,
        Paint()
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, config.edgeFeatherPx)
          ..color = const Color(0xFFFFFFFF),
      );
      canvas.restore();
    }
  }

  void _drawTitle(Canvas canvas, Size size, String title) {
    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 32);

    final x = (size.width - tp.width) / 2;
    tp.paint(canvas, const Offset(0, 8) + Offset(x, 0));
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.countryCodes != countryCodes ||
      old.flagOrder != flagOrder ||
      old.canvasSize != canvasSize ||
      old.titleOverride != titleOverride;
}

// ── PassportStampsCard ────────────────────────────────────────────────────────

/// Travel card template: authentic ink-style passport stamps on parchment.
///
/// Paper texture and stamps are drawn in a single [CustomPainter] so that
/// [BlendMode.multiply] correctly composites ink over paper texture (ADR-097).
///
/// When [trips] is non-empty, stamps show real trip dates and ENTRY/EXIT labels.
/// When empty (fallback), stamps show codes only with no date label.
class PassportStampsCard extends StatelessWidget {
  const PassportStampsCard({
    super.key,
    required this.countryCodes,
    this.trips = const [],
    this.entryOnly = false,
    this.forPrint = false,
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
    this.onWasForced,
    this.onAssetsLoaded,
    this.titleOverride,
    this.stampColor,
    this.dateColor,
    this.textColor,
    this.transparentBackground = false,
    this.seed,
    this.sizeMultiplier = 1.0,
    this.jitterFactor = 0.4,
    this.backgroundImageBytes,
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final bool entryOnly;

  /// When `true`, the layout engine uses a 3% safe-zone margin, disables edge
  /// clipping, and applies an adaptive stamp radius (ADR-102 / M50-C2).
  final bool forPrint;

  final double aspectRatio;

  /// Called once after the first layout when [forPrint] is `true`, with the
  /// value of [PassportLayoutResult.wasForced] (ADR-103).
  final ValueChanged<bool>? onWasForced;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  /// Optional user-override for the main title (ADR-117).
  final String? titleOverride;

  /// Optional user-override for all stamp ink (ADR-117).
  final Color? stampColor;

  /// Optional user-override for all stamp date labels (ADR-117).
  final Color? dateColor;

  /// Optional text colour for the title and branding zones.
  /// When null, defaults to the passport amber `Color(0xFF8B6914)`.
  final Color? textColor;

  /// When `true`, the parchment background tint is removed (ADR-117).
  final bool transparentBackground;

  /// Called once the async SVG stamp asset load is complete (or determined to
  /// be empty). Used by [CardImageRenderer] to know when it is safe to capture
  /// the painted widget — capturing before this fires renders the fallback
  /// procedural [StampPainter] instead of the SVG country stamps.
  final VoidCallback? onAssetsLoaded;

  /// Optional layout seed. When non-null, overrides the deterministic hash
  /// default so that each Shuffle button press produces a visually different
  /// arrangement (ADR-125).
  final int? seed;

  /// Multiplier applied to the non-print base stamp radius (default 1.0).
  /// Values > 1 produce larger stamps; < 1 produce smaller ones.
  final double sizeMultiplier;

  /// Fraction of cell width/height used for random jitter (default 0.4).
  /// 0.0 = stamps sit exactly at cell centres; 0.8 = heavy scatter/overlap.
  final double jitterFactor;

  /// Optional background photo bytes (JPEG). When non-null, drawn beneath
  /// the parchment and stamps at 70% opacity (M93, ADR-138).
  final Uint8List? backgroundImageBytes;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: countryCodes.isEmpty
          ? const _PassportEmptyState()
          : LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return _PassportPagePainter(
                  countryCodes: countryCodes,
                  trips: trips,
                  canvasSize: size,
                  entryOnly: entryOnly,
                  forPrint: forPrint,
                  onWasForced: onWasForced,
                  onAssetsLoaded: onAssetsLoaded,
                  dateLabel: dateLabel,
                  titleOverride: titleOverride,
                  stampColor: stampColor,
                  dateColor: dateColor,
                  textColor: textColor,
                  transparentBackground: transparentBackground,
                  seed: seed,
                  sizeMultiplier: sizeMultiplier,
                  jitterFactor: jitterFactor,
                  backgroundImageBytes: backgroundImageBytes,
                );
              },
            ),
    );
  }
}

class _PassportEmptyState extends StatelessWidget {
  const _PassportEmptyState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: PaperTexturePainter()),
        ),
        const Center(
          child: Text(
            'Scan your photos\nto fill your passport',
            style: TextStyle(color: Color(0xFF8B6914), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PassportPagePainter extends StatefulWidget {
  const _PassportPagePainter({
    required this.countryCodes,
    required this.trips,
    required this.canvasSize,
    this.entryOnly = false,
    this.forPrint = false,
    this.onWasForced,
    this.onAssetsLoaded,
    this.dateLabel = '',
    this.titleOverride,
    this.stampColor,
    this.dateColor,
    this.textColor,
    this.transparentBackground = false,
    this.seed,
    this.sizeMultiplier = 1.0,
    this.jitterFactor = 0.4,
    this.backgroundImageBytes,
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final Size canvasSize;
  final bool entryOnly;
  final bool forPrint;
  final ValueChanged<bool>? onWasForced;
  final String dateLabel;
  final String? titleOverride;
  final Color? stampColor;
  final Color? dateColor;
  final Color? textColor;
  final bool transparentBackground;
  final int? seed;
  final double sizeMultiplier;
  final double jitterFactor;

  /// Optional background photo bytes (M93, ADR-138).
  final Uint8List? backgroundImageBytes;

  /// See [PassportStampsCard.onAssetsLoaded].
  final VoidCallback? onAssetsLoaded;

  @override
  State<_PassportPagePainter> createState() => _PassportPagePainterState();
}

class _PassportPagePainterState extends State<_PassportPagePainter> {
  late List<StampData> _stamps;
  bool _wasForced = false;
  Map<String, StampAsset> _assets = const {};

  // Decoded background photo (M93, ADR-138).
  ui.Image? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _applyLayoutResult(_computeLayoutResult());
    _loadAssets();
    if (widget.backgroundImageBytes != null) {
      _decodeBackgroundImage(widget.backgroundImageBytes!);
    }
  }

  @override
  void didUpdateWidget(_PassportPagePainter old) {
    super.didUpdateWidget(old);
    if (old.backgroundImageBytes != widget.backgroundImageBytes) {
      if (widget.backgroundImageBytes == null) {
        setState(() => _backgroundImage = null);
      } else {
        _decodeBackgroundImage(widget.backgroundImageBytes!);
      }
    }
    final layoutChanged = !listEquals(old.countryCodes, widget.countryCodes) ||
        !listEquals(old.trips, widget.trips) ||
        old.canvasSize != widget.canvasSize ||
        old.entryOnly != widget.entryOnly ||
        old.forPrint != widget.forPrint ||
        old.stampColor != widget.stampColor ||
        old.dateColor != widget.dateColor ||
        old.seed != widget.seed ||
        old.sizeMultiplier != widget.sizeMultiplier ||
        old.jitterFactor != widget.jitterFactor;
    if (layoutChanged) {
      // Only clear + reload SVG assets when the stamp set itself changes
      // (new countries/trips/seed). Size and scatter changes only affect
      // geometry, so keeping existing assets avoids a blank-frame flicker.
      final stampSetChanged =
          !listEquals(old.countryCodes, widget.countryCodes) ||
          !listEquals(old.trips, widget.trips) ||
          old.entryOnly != widget.entryOnly ||
          old.seed != widget.seed;
      setState(() {
        _applyLayoutResult(_computeLayoutResult());
        if (stampSetChanged) _assets = const {};
      });
      if (stampSetChanged) _loadAssets();
    }
  }

  @override
  void dispose() {
    _backgroundImage?.dispose();
    super.dispose();
  }

  Future<void> _decodeBackgroundImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _backgroundImage = frame.image);
  }

  void _applyLayoutResult(PassportLayoutResult result) {
    _stamps = result.stamps;
    _wasForced = result.wasForced;
    // Notify caller of wasForced on first layout (ADR-103).
    widget.onWasForced?.call(_wasForced);
  }

  PassportLayoutResult _computeLayoutResult() => PassportLayoutEngine.layout(
        trips: widget.trips,
        countryCodes: widget.countryCodes,
        canvasSize: widget.canvasSize,
        entryOnly: widget.entryOnly,
        forPrint: widget.forPrint,
        seed: widget.seed,
        sizeMultiplier: widget.sizeMultiplier,
        jitterFactor: widget.jitterFactor,
      );

  Future<void> _loadAssets() async {
    // Capture the stamp list in case it changes while we await.
    final stampsSnapshot = _stamps;
    await StampAssetLoader.instance.ensureManifestLoaded();

    final loaded = <String, StampAsset>{};
    for (final stamp in stampsSnapshot) {
      final key = StampAssetLoader.assetKey(stamp.countryCode, stamp.isEntry);
      if (!loaded.containsKey(key)) {
        final asset = await StampAssetLoader.instance.load(
          stamp.countryCode,
          stamp.isEntry,
        );
        if (asset != null) loaded[key] = asset;
      }
    }

    if (mounted) {
      if (loaded.isNotEmpty) {
        setState(() => _assets = loaded);
      }
      // Notify renderer that async loading is done (loaded or empty).
      // Must fire after setState so the rebuild is scheduled before capture.
      widget.onAssetsLoaded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Map override colors into stamps if provided (ADR-117)
    final effectiveStamps = (widget.stampColor != null || widget.dateColor != null)
        ? _stamps.map((s) => StampData(
            countryCode: s.countryCode,
            countryName: s.countryName,
            style: s.style,
            inkFamilyIndex: s.inkFamilyIndex,
            ageEffect: s.ageEffect,
            rotation: s.rotation,
            center: s.center,
            scale: s.scale,
            isEntry: s.isEntry,
            dateLabel: s.dateLabel,
            entryLabel: s.entryLabel,
            edgeClip: s.edgeClip,
            renderConfig: s.renderConfig,
            overrideInkColor: widget.stampColor,
            overrideDateColor: widget.dateColor,
          )).toList()
        : _stamps;

    return CustomPaint(
      painter: _MultiStampPainter(
        effectiveStamps,
        _assets,
        dateLabel: widget.dateLabel,
        titleOverride: widget.titleOverride,
        transparentBackground: widget.transparentBackground,
        countryCount: widget.countryCodes.length,
        backgroundImage: _backgroundImage,
        textColor: widget.textColor,
      ),
    );
  }
}

/// Unified painter: draws parchment background then stamps with
/// [BlendMode.multiply] so ink darkens the paper texture (ADR-097 Decision 9).
///
/// Stamps with a registered asset (PNG + JSON metadata) are rendered from the
/// image file with a date text overlay. All others fall back to the procedural
/// [StampPainter]. Both paths sit inside the same multiply saveLayer so the
/// ink-on-parchment compositing is consistent.
class _MultiStampPainter extends CustomPainter {
  _MultiStampPainter(
    this.stamps,
    this.assets, {
    this.dateLabel = '',
    this.titleOverride,
    this.transparentBackground = false,
    required this.countryCount,
    this.backgroundImage,
    this.textColor,
  });

  final List<StampData> stamps;

  /// Preloaded assets keyed by [StampAssetLoader.assetKey].
  final Map<String, StampAsset> assets;

  final String dateLabel;
  final String? titleOverride;
  final bool transparentBackground;
  final int countryCount;

  /// Optional decoded background photo (M93, ADR-138).
  final ui.Image? backgroundImage;

  /// Optional text colour for title and branding zones. Defaults to passport amber.
  final Color? textColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Background photo layer (M93, ADR-138).
    // Drawn before parchment so the paper texture sits on top, maintaining
    // the ink-on-paper look while the photo shows through.
    if (backgroundImage != null && !transparentBackground) {
      _drawBackgroundPhoto(canvas, size, backgroundImage!, opacity: 0.70);
      // Bottom-30% gradient darkens to aid stamp readability.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x88000000)],
            stops: [0.70, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    // 1. Paper texture background (drawn directly — not in saveLayer so it
    //    acts as the "destination" for the multiply blend)
    // Tint is removed if transparentBackground is true (ADR-117).
    // When a background photo is active, draw parchment at 25% opacity so the
    // photo shows through while the ink-on-paper multiply blend still works.
    if (!transparentBackground) {
      if (backgroundImage != null) {
        canvas.saveLayer(Offset.zero & size,
            Paint()..color = const Color(0x40FFFFFF));
        const PaperTexturePainter().paint(canvas, size);
        canvas.restore();
      } else {
        const PaperTexturePainter().paint(canvas, size);
      }
    }

    // 2. Stamp compositing layer.
    // BlendMode.multiply darkens the paper texture for a realistic ink effect,
    // but requires a drawn background to work — multiplying over transparent
    // pixels (RGB=0) produces 0 (invisible). When transparentBackground is true
    // (white stamp mode) there is no paper, so use a plain save() instead to
    // let stamps render normally (srcOver) onto the transparent canvas.
    if (transparentBackground) {
      canvas.save();
    } else {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..blendMode = BlendMode.multiply,
      );
    }

    for (final stamp in stamps) {
      // Apply edge clipping if set (partial stamp at page boundary)
      final hasClip = stamp.edgeClip != null;
      if (hasClip) {
        canvas.save();
        canvas.clipRect(stamp.edgeClip!);
      }
      final key = StampAssetLoader.assetKey(stamp.countryCode, stamp.isEntry);
      final asset = assets[key];
      if (asset != null) {
        _drawAssetStamp(canvas, stamp, asset);
      } else {
        StampPainter(stamp).paint(canvas, size);
      }
      if (hasClip) {
        canvas.restore();
      }
    }

    canvas.restore(); // end BlendMode.multiply layer

    // 3. Integrated Text Rendering: Title and Branding (ADR-117)
    // Drawn AFTER saveLayer so they are not affected by multiply blend,
    // ensuring pure white/black text if needed and no artifacts.
    final effectiveTextColor = textColor ?? const Color(0xFF8B6914);
    _drawBranding(canvas, size, countryCount, dateLabel, effectiveTextColor);

    final defaultTitle = '$countryCount Countries \u00B7 $dateLabel';
    _drawTitle(canvas, size, titleOverride ?? defaultTitle, effectiveTextColor);

    // 4. Vignette: paper-only effect.
    // Skip when transparentBackground=true (POD / white-ink mode).
    if (!transparentBackground) {
      _drawVignette(canvas, size);
    }
  }

  void _drawBranding(Canvas canvas, Size size, int count, String date, Color color) {
    const double fontSize = 9.0;
    final tpRoavvy = TextPainter(
      text: TextSpan(
        text: 'ROAVVY',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tpCount = TextPainter(
      text: TextSpan(
        text: '$count ${count == 1 ? 'country' : 'countries'}',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final y = size.height - tpRoavvy.height - 8;
    tpRoavvy.paint(canvas, Offset(12, y));
    tpCount.paint(canvas, Offset(12 + tpRoavvy.width + 8, y));

    if (date.isNotEmpty) {
      final tpDate = TextPainter(
        text: TextSpan(
          text: date,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpDate.paint(canvas, Offset(12 + tpRoavvy.width + 8 + tpCount.width + 6, y));
    }
  }

  void _drawTitle(Canvas canvas, Size size, String title, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 40);

    final x = (size.width - tp.width) / 2;
    // Pinned near the very top with a small fixed margin.
    const y = 10.0;
    tp.paint(canvas, Offset(x, y));
  }

  /// Renders a stamp from its PNG asset, scaled to the stamp's bounding box,
  /// with the date string overlaid at the position specified in the metadata.
  void _drawAssetStamp(Canvas canvas, StampData stamp, StampAsset asset) {
    final meta = asset.metadata;
    final baseRadius = 38.0 * stamp.scale;
    // meta.visualScale lets the JSON override apparent size to compensate for
    // stamps whose PNG assets have more whitespace than others (default 1.0).
    final targetW = baseRadius * 2.1 * meta.visualScale;
    final targetH = targetW * (meta.imageHeight / meta.imageWidth);

    canvas.save();
    canvas.translate(stamp.center.dx, stamp.center.dy);
    canvas.rotate(stamp.rotation);

    // Draw the PNG.
    // When an ink color override is set (black/white/palette modes), apply it
    // via ColorFilter.srcIn which replaces all non-transparent pixels with the
    // target color while preserving the alpha channel (shape, edges, anti-aliasing).
    // Without an override (multicolor mode), draw with natural PNG colors.
    final Paint imgPaint;
    final inkOverride = stamp.overrideInkColor;
    if (inkOverride != null) {
      imgPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          inkOverride.withValues(alpha: stamp.ageEffect.opacity),
          BlendMode.srcIn,
        );
    } else {
      imgPaint = Paint()
        ..color = Colors.white.withValues(alpha: stamp.ageEffect.opacity);
    }
    canvas.drawImageRect(
      asset.image,
      Rect.fromLTWH(0, 0, meta.imageWidth, meta.imageHeight),
      Rect.fromCenter(center: Offset.zero, width: targetW, height: targetH),
      imgPaint,
    );

    // Overlay the date string if present.
    if (stamp.dateLabel != null && stamp.dateLabel!.isNotEmpty) {
      _drawDateOverlay(canvas, stamp, meta, targetW, targetH);
    }

    canvas.restore();
  }

  /// Draws the date text at the position specified by [meta.dateSpec], scaled
  /// from native image coordinates to the target stamp rect.
  void _drawDateOverlay(
    Canvas canvas,
    StampData stamp,
    StampMetadata meta,
    double targetW,
    double targetH,
  ) {
    final spec = meta.dateSpec;
    final scaleX = targetW / meta.imageWidth;
    final scaleY = targetH / meta.imageHeight;

    final tp = TextPainter(
      text: TextSpan(
        text: stamp.dateLabel,
        style: TextStyle(
          color: stamp.dateColor.withValues(alpha: stamp.ageEffect.opacity),
          fontSize: spec.fontSize * scaleY,
          fontWeight: FontWeight.w700,
          letterSpacing: spec.letterSpacing * scaleX,
          fontFamily: 'Courier New',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // spec.x/y are native-image-space centre coords; translate to the
    // rotated canvas where the stamp centre is at Offset.zero.
    final textLeft = spec.x * scaleX - targetW / 2 - tp.width / 2;
    final textTop = spec.y * scaleY - targetH / 2 - tp.height / 2;
    tp.paint(canvas, Offset(textLeft, textTop));
  }

  void _drawWavyCancelLines(Canvas canvas, Size size, int seed) {
    final rng = math.Random(seed ^ 0xCAB0);
    final lineCount = 2 + rng.nextInt(2); // 2–3 lines

    for (var i = 0; i < lineCount; i++) {
      final baseY = size.height * (0.22 + i * 0.28 + rng.nextDouble() * 0.06);
      final path = Path();
      path.moveTo(0, baseY);

      const segments = 8;
      final segW = size.width / segments;
      var prevY = baseY;
      for (var s = 0; s < segments; s++) {
        final x1 = s * segW + segW * 0.33;
        final x2 = s * segW + segW * 0.67;
        final x3 = (s + 1) * segW;
        final amp = size.height * 0.018 * (rng.nextDouble() * 2 - 1);
        path.cubicTo(x1, prevY + amp, x2, prevY - amp, x3, prevY + amp * 0.4);
        prevY = prevY + amp * 0.4;
      }

      final opacity = 0.06 + rng.nextDouble() * 0.06;
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3B2A1A).withValues(alpha: opacity)
          ..strokeWidth = 0.7 + rng.nextDouble() * 0.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final cornerRadius = math.min(size.width, size.height) * 0.28;
    for (final alignment in const [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ]) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: alignment,
            radius: cornerRadius / math.min(size.width, size.height),
            colors: const [
              Color(0x14000000), // 8% black
              Color(0x00000000), // transparent
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(_MultiStampPainter old) =>
      old.stamps != stamps ||
      old.assets != assets ||
      old.backgroundImage != backgroundImage ||
      old.textColor != textColor;
}

// ── TypographyCard ────────────────────────────────────────────────────────────

/// Travel card template: a stacked country-name text composition (M103).
///
/// Lists up to 24 country names in a two-column layout with alternating font
/// size and opacity for visual rhythm. Single-country mode renders the name as
/// a centred headline. Dark navy background unless [transparentBackground].
class TypographyCard extends StatelessWidget {
  const TypographyCard({
    super.key,
    required this.codes,
    this.titleOverride,
    this.transparentBackground = false,
  });

  final List<String> codes;
  final String? titleOverride;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TypographyPainter(
            codes: codes,
            titleOverride: titleOverride,
            transparentBackground: transparentBackground,
          ),
        ),
      ),
    );
  }
}

class _TypographyPainter extends CustomPainter {
  _TypographyPainter({
    required this.codes,
    this.titleOverride,
    required this.transparentBackground,
  });

  final List<String> codes;
  final String? titleOverride;
  final bool transparentBackground;

  static const _bgColor = Color(0xFF0D1B2A);
  static const _accentColor = Color(0xFFE8C84A); // gold
  static const _maxNames = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (!transparentBackground) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _bgColor,
      );
      // Subtle gradient overlay for depth.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x33000000)],
          ).createShader(Offset.zero & size),
      );
    }

    if (codes.isEmpty) {
      _drawCentredText(canvas, size, 'No countries yet', 16,
          Colors.white54, FontWeight.normal);
      return;
    }

    if (codes.length == 1) {
      _drawSingleCountry(canvas, size);
    } else {
      _drawMultiCountry(canvas, size);
    }
  }

  void _drawSingleCountry(Canvas canvas, Size size) {
    final name = kCountryNames[codes.first] ?? codes.first;
    final flag = _flag(codes.first);

    // Flag emoji centred at 30% height.
    _drawCentredText(canvas, size, flag, size.width * 0.15,
        Colors.white, FontWeight.normal,
        offsetY: -size.height * 0.12);

    // Country name headline.
    _drawCentredText(canvas, size, name, size.width * 0.08,
        Colors.white, FontWeight.w700);

    // Gold accent rule.
    final ruleY = size.height * 0.58;
    canvas.drawLine(
      Offset(size.width * 0.3, ruleY),
      Offset(size.width * 0.7, ruleY),
      Paint()
        ..color = _accentColor
        ..strokeWidth = 1.5,
    );

    // Subtitle.
    _drawCentredText(canvas, size, titleOverride ?? 'My First Country',
        size.width * 0.045, _accentColor, FontWeight.w500,
        offsetY: size.height * 0.1);
  }

  void _drawMultiCountry(Canvas canvas, Size size) {
    final displayCodes = codes.take(_maxNames).toList();
    final overflow = codes.length - displayCodes.length;
    final names = displayCodes
        .map((c) => kCountryNames[c] ?? c)
        .toList();

    final pad = size.width * 0.06;
    final colWidth = (size.width - pad * 3) / 2;
    final startY = size.height * 0.10;
    final bottomPad = size.height * 0.14;
    final availH = size.height - startY - bottomPad;

    // Determine row count per column.
    final totalNames = names.length + (overflow > 0 ? 1 : 0);
    final rows = (totalNames / 2).ceil();
    final rowH = availH / rows.clamp(1, 999);

    for (int i = 0; i < totalNames; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final isLarge = (i % 3 == 0);
      final opacity = isLarge ? 1.0 : 0.62;
      final fontSize = isLarge ? size.width * 0.038 : size.width * 0.032;

      final x = pad + col * (colWidth + pad);
      final y = startY + row * rowH;

      final String label;
      if (i == totalNames - 1 && overflow > 0) {
        label = '+ $overflow more';
      } else {
        label = names[i];
      }

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: opacity),
            fontSize: fontSize,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colWidth);

      tp.paint(canvas, Offset(x, y + (rowH - tp.height) / 2));
    }

    // Bottom count label.
    final countLabel = titleOverride ?? '${codes.length} countries';
    _drawCentredText(canvas, size, countLabel, size.width * 0.038,
        _accentColor, FontWeight.w500,
        offsetY: size.height * 0.43);
  }

  void _drawCentredText(
    Canvas canvas,
    Size size,
    String text,
    double fontSize,
    Color color,
    FontWeight weight, {
    double offsetY = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.85);
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2 + offsetY,
      ),
    );
  }

  @override
  bool shouldRepaint(_TypographyPainter old) =>
      old.codes != codes ||
      old.titleOverride != titleOverride ||
      old.transparentBackground != transparentBackground;
}

// ── BadgeCard ─────────────────────────────────────────────────────────────────

/// Travel card template: a circular explorer badge with flag arc, tick ring,
/// and scope label (M103, ADR-153).
///
/// Renders up to 12 flag emoji tiles arranged in an arc. The [onAssetsLoaded]
/// callback follows the [HeartFlagsCard] pattern so [CardImageRenderer] can
/// await rendering before PNG capture. Because this template uses emoji flags
/// (no async SVG), the callback fires on the next frame — matching the
/// `futures.isEmpty` branch in HeartFlagsCard.
class BadgeCard extends StatefulWidget {
  const BadgeCard({
    super.key,
    required this.codes,
    this.scopeLabel,
    this.transparentBackground = false,
    this.onAssetsLoaded,
  });

  final List<String> codes;

  /// Optional label shown in the badge centre (e.g. "Europe Explorer").
  /// Defaults to `"${codes.length} Countries"` when null.
  final String? scopeLabel;

  final bool transparentBackground;

  /// Called exactly once on the next frame after build, following the
  /// [HeartFlagsCard.onAssetsLoaded] protocol used by [CardImageRenderer].
  final VoidCallback? onAssetsLoaded;

  @override
  State<BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<BadgeCard> {
  bool _firedOnAssetsLoaded = false;

  @override
  void didUpdateWidget(BadgeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.codes != widget.codes) {
      _firedOnAssetsLoaded = false;
    }
  }

  void _maybeFireOnAssetsLoaded() {
    if (_firedOnAssetsLoaded) return;
    _firedOnAssetsLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAssetsLoaded?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeFireOnAssetsLoaded();
    return AspectRatio(
      aspectRatio: 1.0,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BadgePainter(
            codes: widget.codes,
            scopeLabel: widget.scopeLabel,
            transparentBackground: widget.transparentBackground,
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.codes,
    this.scopeLabel,
    required this.transparentBackground,
  });

  final List<String> codes;
  final String? scopeLabel;
  final bool transparentBackground;

  static const _bgColor = Color(0xFF0D1B2A);
  static const _ringColor = Color(0xFFE8C84A);
  static const _maxFlags = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (!transparentBackground) {
      canvas.drawRect(Offset.zero & size, Paint()..color = _bgColor);
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    _drawOuterRing(canvas, cx, cy, r);
    _drawTickMarks(canvas, cx, cy, r);
    _drawFlagArc(canvas, cx, cy, r * 0.72, size);
    _drawCentreLabel(canvas, cx, cy, size);
    _drawOuterText(canvas, cx, cy, r * 0.92, size);
  }

  void _drawOuterRing(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = _ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.88,
      Paint()
        ..color = _ringColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawTickMarks(Canvas canvas, double cx, double cy, double r) {
    const tickCount = 36;
    final tickPaint = Paint()
      ..color = _ringColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i / tickCount) * 2 * math.pi - math.pi / 2;
      final isMajor = i % 9 == 0;
      final inner = r + (isMajor ? 4 : 6);
      final outer = r + 10;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        tickPaint,
      );
    }
  }

  void _drawFlagArc(Canvas canvas, double cx, double cy, double arcR, Size size) {
    final displayCodes = codes.take(_maxFlags).toList();
    if (displayCodes.isEmpty) return;

    final flagFontSize = _flagFontSize(displayCodes.length, size);

    for (int i = 0; i < displayCodes.length; i++) {
      final angle = displayCodes.length == 1
          ? -math.pi / 2 // single flag centred at top
          : (i / displayCodes.length) * 2 * math.pi - math.pi / 2;

      final r = displayCodes.length == 1 ? 0.0 : arcR;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      final emoji = _flag(displayCodes[i]);
      final tp = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: flagFontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // Overflow indicator.
    if (codes.length > _maxFlags) {
      final overflow = codes.length - _maxFlags;
      final tp = TextPainter(
        text: TextSpan(
          text: '+$overflow',
          style: TextStyle(
            color: _ringColor.withValues(alpha: 0.8),
            fontSize: size.width * 0.030,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, cy + arcR * 0.6 - tp.height / 2),
      );
    }
  }

  double _flagFontSize(int count, Size size) {
    if (count <= 1) return size.width * 0.20;
    if (count <= 4) return size.width * 0.12;
    if (count <= 8) return size.width * 0.09;
    return size.width * 0.075;
  }

  void _drawCentreLabel(Canvas canvas, double cx, double cy, Size size) {
    final label = scopeLabel ?? '${codes.length} Countries';

    // Split long labels at spaces into max two lines.
    final words = label.split(' ');
    final String line1;
    final String? line2;
    if (words.length <= 2 || label.length <= 12) {
      line1 = label;
      line2 = null;
    } else {
      final mid = words.length ~/ 2;
      line1 = words.take(mid).join(' ');
      line2 = words.skip(mid).join(' ');
    }

    final fontSize = _labelFontSize(label.length, size);

    if (line2 == null) {
      _paintCentred(canvas, line1, cx, cy, fontSize, Colors.white,
          FontWeight.w700);
    } else {
      _paintCentred(canvas, line1, cx, cy - fontSize * 0.7, fontSize,
          Colors.white, FontWeight.w700);
      _paintCentred(canvas, line2, cx, cy + fontSize * 0.7, fontSize,
          Colors.white, FontWeight.w700);
    }
  }

  double _labelFontSize(int charCount, Size size) {
    if (charCount <= 8) return size.width * 0.075;
    if (charCount <= 14) return size.width * 0.058;
    return size.width * 0.046;
  }

  void _drawOuterText(
      Canvas canvas, double cx, double cy, double textR, Size size) {
    final year = DateTime.now().year;
    final outerLabel = 'ROAVVY · TRAVEL · $year';
    final chars = outerLabel.split('');
    final fontSize = size.width * 0.028;
    final angleStep = (2 * math.pi) / outerLabel.length;

    for (int i = 0; i < chars.length; i++) {
      final angle = i * angleStep - math.pi / 2;
      final x = cx + textR * math.cos(angle);
      final y = cy + textR * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: chars[i],
          style: TextStyle(
            color: _ringColor.withValues(alpha: 0.75),
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _paintCentred(Canvas canvas, String text, double cx, double cy,
      double fontSize, Color color, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 200);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.codes != codes ||
      old.scopeLabel != scopeLabel ||
      old.transparentBackground != transparentBackground;
}
