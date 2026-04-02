import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'card_branding_footer.dart';
import 'flag_tile_renderer.dart';
import 'heart_layout_engine.dart';
import 'paper_texture_painter.dart';
import 'passport_layout_engine.dart';
import 'passport_stamp_model.dart';
import 'stamp_asset_loader.dart';
import 'stamp_painter.dart';

// ── Shared constants ─────────────────────────────────────────────────────────

String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

// ── Grid tile-size helper (M50-C1) ────────────────────────────────────────────

/// Adaptive tile size for [GridFlagsCard] (ADR-102).
///
/// `tileSize = clamp(floor(sqrt(canvasArea / n) * 0.85), 28, 90)`
///
/// Exposed with [@visibleForTesting] for unit testing without widget
/// infrastructure.
@visibleForTesting
double gridTileSize(double canvasArea, int n) {
  assert(n > 0, 'n must be > 0');
  final raw = (math.sqrt(canvasArea / n) * 0.85).floorToDouble();
  return raw.clamp(28.0, 90.0);
}

// ── GridFlagsCard ─────────────────────────────────────────────────────────────

/// Travel card template: flag emojis arranged in a flowing grid.
///
/// Dark navy background with amber accent. Up to 40 flags shown; overflow
/// shown as "+N more". Displays country count at the bottom.
class GridFlagsCard extends StatelessWidget {
  const GridFlagsCard({
    super.key,
    required this.countryCodes,
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
  });

  final List<String> countryCodes;
  final double aspectRatio;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    const maxFlags = 40;
    final visible = countryCodes.take(maxFlags).toList();
    final overflow = countryCodes.length - visible.length;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF0D2137)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: countryCodes.isEmpty
                  ? const Center(
                      child: Text(
                        'Scan your photos\nto fill your card',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Adaptive tile size (ADR-102 / M50-C1).
                        final tileSize = gridTileSize(
                          constraints.maxWidth * constraints.maxHeight,
                          visible.length,
                        );
                        final overflowFontSize =
                            math.max(10.0, tileSize * 0.5);
                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              for (final code in visible)
                                Text(_flag(code),
                                    style: TextStyle(fontSize: tileSize)),
                              if (overflow > 0)
                                Text(
                                  '+$overflow',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: overflowFontSize,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            CardBrandingFooter(
              countryCount: countryCodes.length,
              dateLabel: dateLabel,
            ),
          ],
        ),
      ),
    );
  }
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
class HeartFlagsCard extends StatelessWidget {
  const HeartFlagsCard({
    super.key,
    required this.countryCodes,
    this.trips = const [],
    this.flagOrder = HeartFlagOrder.randomized,
    this.config = const HeartRenderConfig(),
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final HeartFlagOrder flagOrder;
  final HeartRenderConfig config;
  final double aspectRatio;

  /// Pre-computed date range label, e.g. `"2024"` or `"2018–2024"`.
  /// Empty string omits the date label from the branding footer (ADR-101).
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    if (countryCodes.isEmpty) {
      return AspectRatio(
        aspectRatio: aspectRatio,
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
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeartPainter(
                    countryCodes: countryCodes,
                    trips: trips,
                    flagOrder: flagOrder,
                    config: config,
                    canvasSize: size,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CardBrandingFooter(
                  countryCount: countryCodes.length,
                  dateLabel: dateLabel,
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
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final HeartFlagOrder flagOrder;
  final HeartRenderConfig config;
  final Size canvasSize;

  // Shared cache across all painters in the same card preview.
  static final _sharedCache = FlagImageCache();

  @override
  void paint(Canvas canvas, Size size) {
    // Dark navy background behind the heart.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D2137),
    );

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

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.countryCodes != countryCodes ||
      old.flagOrder != flagOrder ||
      old.canvasSize != canvasSize;
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
                return Stack(
                  children: [
                    // Single unified painter: paper + stamps with BlendMode.multiply
                    Positioned.fill(
                      child: _PassportPagePainter(
                        countryCodes: countryCodes,
                        trips: trips,
                        canvasSize: size,
                        entryOnly: entryOnly,
                        forPrint: forPrint,
                        onWasForced: onWasForced,
                      ),
                    ),
                    // Branding footer: wordmark + count + date label (ADR-101)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CardBrandingFooter(
                        countryCount: countryCodes.length,
                        dateLabel: dateLabel,
                        textColor: const Color(0xFF8B6914),
                      ),
                    ),
                  ],
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
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final Size canvasSize;
  final bool entryOnly;
  final bool forPrint;
  final ValueChanged<bool>? onWasForced;

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
        old.forPrint != widget.forPrint) {
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

    if (mounted && loaded.isNotEmpty) {
      setState(() => _assets = loaded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MultiStampPainter(_stamps, _assets),
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
  _MultiStampPainter(this.stamps, this.assets);

  final List<StampData> stamps;

  /// Preloaded assets keyed by [StampAssetLoader.assetKey].
  final Map<String, StampAsset> assets;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paper texture background (drawn directly — not in saveLayer so it
    //    acts as the "destination" for the multiply blend)
    const PaperTexturePainter().paint(canvas, size);

    // 2. Open saveLayer with BlendMode.multiply: stamps multiply over paper
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..blendMode = BlendMode.multiply,
    );

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

    // 3. Wavy cancel lines: 2–3 faint ink strokes crossing the page
    if (stamps.isNotEmpty) {
      _drawWavyCancelLines(canvas, size, stamps.first.seed);
    }

    // 4. Vignette: subtle corner darkening (replaces PaperTexturePainter corner
    //    aging which was removed in M45)
    _drawVignette(canvas, size);
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

    // Draw the PNG — apply age opacity via paint alpha.
    canvas.drawImageRect(
      asset.image,
      Rect.fromLTWH(0, 0, meta.imageWidth, meta.imageHeight),
      Rect.fromCenter(center: Offset.zero, width: targetW, height: targetH),
      Paint()..color = Colors.white.withValues(alpha: stamp.ageEffect.opacity),
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
          color: stamp.inkColor.withValues(alpha: stamp.ageEffect.opacity),
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
