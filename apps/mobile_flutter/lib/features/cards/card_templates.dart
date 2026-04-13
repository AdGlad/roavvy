import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'card_branding_footer.dart';
import 'flag_tile_renderer.dart';
import 'grid_math_engine.dart';
import 'heart_layout_engine.dart';
import 'paper_texture_painter.dart';
import 'passport_layout_engine.dart';
import 'passport_stamp_model.dart';
import 'stamp_asset_loader.dart';
import 'stamp_painter.dart';

// ── Adaptive grid sizing ──────────────────────────────────────────────────────

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
    this.transparentBackground = false,
    this.onAssetsLoaded,
  });

  final List<String> countryCodes;
  final double aspectRatio;
  final String? titleOverride;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  /// When `true`, renders with a transparent background instead of the default
  /// dark navy. Used by [CardImageRenderer] for t-shirt compositing (ADR-123).
  final bool transparentBackground;

  /// Called once when all SVG flag assets have finished loading into the shared
  /// cache. Used by [CardImageRenderer] to delay PNG capture until SVGs are
  /// ready (ADR-123).
  final VoidCallback? onAssetsLoaded;

  @override
  State<GridFlagsCard> createState() => _GridFlagsCardState();
}

class _GridFlagsCardState extends State<GridFlagsCard> {
  // ValueNotifier is a ChangeNotifier subclass that can be incremented from any
  // class without needing to call the protected notifyListeners() (ADR-123).
  final _repaintNotifier = ValueNotifier<int>(0);
  bool _preloadStarted = false;
  bool _onAssetsLoadedFired = false;

  @override
  void dispose() {
    _repaintNotifier.dispose();
    super.dispose();
  }

  /// Schedules async SVG loading for all country codes at [tileWidth].
  /// Fires [widget.onAssetsLoaded] exactly once when all pending loads complete
  /// (or immediately if nothing needs loading). Cache hits are skipped.
  /// Guards against being called multiple times from [LayoutBuilder].
  void _preloadSvgs(double tileWidth) {
    if (tileWidth <= 0 || _preloadStarted) return;
    _preloadStarted = true;

    final toLoad = widget.countryCodes
        .where((code) =>
            FlagTileRenderer.hasSvg(code) &&
            _GridPainter._sharedCache.get(code, tileWidth) == null)
        .toList();

    if (toLoad.isEmpty) {
      _fireOnAssetsLoaded();
      return;
    }

    var remaining = toLoad.length;
    for (final code in toLoad) {
      FlagTileRenderer.loadSvgToCache(code, tileWidth, _GridPainter._sharedCache)
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
    final bgColor = widget.transparentBackground
        ? Colors.transparent
        : const Color(0xFF0D2137);

    if (widget.countryCodes.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: bgColor,
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
        '${widget.countryCodes.length} Countries'
            '${widget.dateLabel.isNotEmpty ? ' \u00B7 ${widget.dateLabel}' : ''}';

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        decoration: BoxDecoration(color: bgColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                effectiveTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  final layout = GridMathEngine.calculate(
                    width: size.width,
                    height: size.height,
                    itemCount: widget.countryCodes.length,
                  );
                  final tileWidth = layout.columns > 0
                      ? size.width / layout.columns
                      : 0.0;
                  _preloadSvgs(tileWidth);
                  return CustomPaint(
                    size: size,
                    painter: _GridPainter(
                      countryCodes: widget.countryCodes,
                      canvasSize: size,
                      repaintNotifier: _repaintNotifier,
                    ),
                  );
                },
              ),
            ),
            CardBrandingFooter(
              countryCount: widget.countryCodes.length,
              dateLabel: widget.dateLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.countryCodes,
    required this.canvasSize,
    required ValueNotifier<int> repaintNotifier,
  }) : super(repaint: repaintNotifier);

  final List<String> countryCodes;
  final Size canvasSize;

  // Shared across all _GridPainter instances and accessible from
  // _GridFlagsCardState for SVG preloading (ADR-123).
  static final _sharedCache = FlagImageCache();

  @override
  void paint(Canvas canvas, Size size) {
    if (countryCodes.isEmpty) return;
    if (size.width <= 0 || size.height <= 0) return;

    final layout = GridMathEngine.calculate(
      width: size.width,
      height: size.height,
      itemCount: countryCodes.length,
    );

    if (layout.columns == 0 || layout.rows == 0) return;

    // Stretch tiles to fill the canvas with no gaps (ADR-123).
    final tileWidth = size.width / layout.columns;
    final tileHeight = size.height / layout.rows;

    int index = 0;
    for (int r = 0; r < layout.rows; r++) {
      final itemsInThisRow = r == layout.rows - 1
          ? countryCodes.length - (r * layout.columns)
          : layout.columns;

      for (int c = 0; c < itemsInThisRow; c++) {
        final code = countryCodes[index];
        final rect = Rect.fromLTWH(
          c * tileWidth,
          r * tileHeight,
          tileWidth,
          tileHeight,
        );

        final tile = HeartTilePosition(rect: rect, countryCode: code);
        FlagTileRenderer.renderFromCache(
          canvas,
          tile,
          _sharedCache,
          cornerRadius: 0.0,
          gapWidth: 0.0,
        );

        index++;
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.countryCodes != countryCodes || old.canvasSize != canvasSize;
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
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final HeartFlagOrder flagOrder;
  final HeartRenderConfig config;
  final double aspectRatio;
  final String? titleOverride;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  @override
  State<HeartFlagsCard> createState() => _HeartFlagsCardState();
}

class _HeartFlagsCardState extends State<HeartFlagsCard> {
  // ValueNotifier is a ChangeNotifier subclass that can be incremented from any
  // class without needing to call the protected notifyListeners() (ADR-123).
  final _repaintNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _repaintNotifier.dispose();
    super.dispose();
  }

  /// Schedules async SVG loading for all tiles produced by [HeartLayoutEngine]
  /// at [canvasSize]. Skips codes already in cache and codes without SVG assets.
  void _preloadSvgsForSize(Size canvasSize) {
    final tiles = HeartLayoutEngine.layout(
      widget.countryCodes,
      canvasSize,
      order: widget.flagOrder,
      trips: widget.trips,
    );
    for (final tile in tiles) {
      final code = tile.countryCode;
      final tileSize = tile.rect.width;
      if (tileSize <= 0) continue;
      if (!FlagTileRenderer.hasSvg(code)) continue;
      if (_HeartPainter._sharedCache.get(code, tileSize) != null) continue;
      FlagTileRenderer.loadSvgToCache(code, tileSize, _HeartPainter._sharedCache)
          .then((img) {
        if (mounted && img != null) _repaintNotifier.value++;
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
    this.transparentBackground = false,
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

  /// When `true`, the parchment background tint is removed (ADR-117).
  final bool transparentBackground;

  /// Called once the async SVG stamp asset load is complete (or determined to
  /// be empty). Used by [CardImageRenderer] to know when it is safe to capture
  /// the painted widget — capturing before this fires renders the fallback
  /// procedural [StampPainter] instead of the SVG country stamps.
  final VoidCallback? onAssetsLoaded;

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
                  transparentBackground: transparentBackground,
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
    this.transparentBackground = false,
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
  final bool transparentBackground;

  /// See [PassportStampsCard.onAssetsLoaded].
  final VoidCallback? onAssetsLoaded;

  @override
  State<_PassportPagePainter> createState() => _PassportPagePainterState();
}

class _PassportPagePainterState extends State<_PassportPagePainter> {
  late List<StampData> _stamps;
  bool _wasForced = false;
  Map<String, StampAsset> _assets = const {};

  @override
  void initState() {
    super.initState();
    _applyLayoutResult(_computeLayoutResult());
    _loadAssets();
  }

  @override
  void didUpdateWidget(_PassportPagePainter old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.countryCodes, widget.countryCodes) ||
        !listEquals(old.trips, widget.trips) ||
        old.canvasSize != widget.canvasSize ||
        old.entryOnly != widget.entryOnly ||
        old.forPrint != widget.forPrint ||
        old.stampColor != widget.stampColor ||
        old.dateColor != widget.dateColor) {
      setState(() {
        _applyLayoutResult(_computeLayoutResult());
        _assets = const {};
      });
      _loadAssets();
    }
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
  });

  final List<StampData> stamps;

  /// Preloaded assets keyed by [StampAssetLoader.assetKey].
  final Map<String, StampAsset> assets;

  final String dateLabel;
  final String? titleOverride;
  final bool transparentBackground;
  final int countryCount;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paper texture background (drawn directly — not in saveLayer so it
    //    acts as the "destination" for the multiply blend)
    // Tint is removed if transparentBackground is true (ADR-117).
    if (!transparentBackground) {
      const PaperTexturePainter().paint(canvas, size);
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
    final textColor = const Color(0xFF8B6914);
    _drawBranding(canvas, size, countryCount, dateLabel, textColor);
    
    final defaultTitle = '$countryCount Countries \u00B7 $dateLabel';
    _drawTitle(canvas, size, titleOverride ?? defaultTitle, textColor);

    // 4. Wavy cancel lines and vignette: paper-only effects.
    // Skip when transparentBackground=true (POD / white-ink mode) — they are
    // designed for parchment and appear as dark artifacts on a transparent canvas.
    if (!transparentBackground) {
      if (stamps.isNotEmpty) {
        _drawWavyCancelLines(canvas, size, stamps.first.seed);
      }
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
        text: '$count countries',
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
    // Positioned in the top safe zone (18% of height)
    final y = (size.height * 0.18 - tp.height) / 2 + 4;
    tp.paint(canvas, Offset(x, y));
  }

  /// Renders a stamp from its PNG asset, scaled to the stamp's bounding box,
  /// with the date string overlaid at the position specified in the metadata.
  void _drawAssetStamp(Canvas canvas, StampData stamp, StampAsset asset) {
    final meta = asset.metadata;
    final baseRadius = 38.0 * stamp.scale;
    final targetW = baseRadius * 2.8;
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
      old.stamps != stamps || old.assets != assets;
}
