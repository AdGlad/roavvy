import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'artwork_detail_analyzer.dart';
import 'print_style.dart';
import 'print_style_textures.dart';

/// Applies a [PrintStyleParams] to finished merch artwork, on device and
/// deterministically. This is the single stage inserted between
/// `CardImageRenderer` and the bytes that become both the preview source and
/// the Printful print file.
///
/// Design constraints honoured here:
/// - **Clean is a byte-perfect pass-through** — existing designs are unchanged.
/// - Distress removes ink by making pixels **transparent** (garment shows
///   through); it never paints the garment colour into the artwork.
/// - Effects are masked to the artwork's own alpha so transparent areas stay
///   transparent (no gray specks on the shirt fabric).
/// - Procedural textures are seeded and defined in artwork-normalised space, so
///   a small preview and a 12× print render look identical.
class PrintStylePipeline {
  PrintStylePipeline._();

  static final PrintStylePipeline instance = PrintStylePipeline._();

  /// Applies [params] to PNG [bytes], returning styled PNG bytes.
  ///
  /// Returns [bytes] unchanged (same instance) when [params] is clean, so the
  /// default path is free and byte-identical.
  Future<Uint8List> applyToBytes(
    Uint8List bytes,
    PrintStyleParams params,
  ) async {
    if (params.isClean) return bytes;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    try {
      final styled = await apply(src, params);
      final data = await styled.toByteData(format: ui.ImageByteFormat.png);
      styled.dispose();
      if (data == null) return bytes;
      return data.buffer.asUint8List();
    } finally {
      src.dispose();
    }
  }

  /// Applies [params] to a decoded [source] image, returning a new styled image
  /// at the same pixel dimensions. Caller owns both images.
  ///
  /// When [params] is clean, returns a straight copy of [source].
  Future<ui.Image> apply(ui.Image source, PrintStyleParams params) async {
    final w = source.width;
    final h = source.height;
    final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    final srcRect = rect;

    // Pre-load any textures needed (async) before entering the canvas pass.
    final grainImg = params.grain > 0
        ? await PrintStyleTextures.instance.get(PrintTextureKind.grain,
            params.seed, size: 256)
        : null;
    final distressImg = params.effectiveDistress > 0
        ? await PrintStyleTextures.instance.get(PrintTextureKind.blotch,
            params.seed, size: 256)
        : null;
    final scratchImg = params.effectiveRoughEdges > 0 && _usesScratches(params)
        ? await PrintStyleTextures.instance.get(PrintTextureKind.scratch,
            params.seed ^ 0x5bd1e995, size: 256)
        : null;
    final stampInkImg =
        params.effectiveRoughEdges > 0 && params.id == PrintStyleId.stamp
            ? await PrintStyleTextures.instance.get(PrintTextureKind.stampInk,
                params.seed ^ 0x27d4eb2f, size: 256)
            : null;
    // Fine mottled breakup, layered on top of the coarse blotch so distress
    // reads as dense grungy ink loss rather than a few soft blobs.
    final mottleImg = params.effectiveDistress > 0.25
        ? await PrintStyleTextures.instance.get(PrintTextureKind.mottle,
            params.seed ^ 0x9e3779b1, size: 256)
        : null;
    // Branching crack network (cracked-paint / grunge).
    final crackImg = params.effectiveCracks > 0
        ? await PrintStyleTextures.instance.get(PrintTextureKind.crack,
            params.seed ^ 0x165667b1, size: 256)
        : null;
    // Soft cloud for acid-wash bleach patches.
    final washImg = params.acidWash > 0
        ? await PrintStyleTextures.instance.get(PrintTextureKind.wash,
            params.seed ^ 0x2545f491, size: 256)
        : null;
    // Ragged torn outer edge (design frays into the garment).
    final tornEdgeImg =
        params.effectiveRoughEdges > 0 && _usesTornEdges(params)
            ? await _buildTornEdgeImage(
                params.seed, w, h, params.effectiveRoughEdges)
            : null;
    // Local protection mask (keeps emblems/text inked). Only needed when an
    // ink-removing pass runs.
    final needsErase = distressImg != null || scratchImg != null ||
        stampInkImg != null || mottleImg != null || crackImg != null;
    final protectionImg =
        needsErase ? await _buildProtectionImage(params.detail) : null;

    // Halftone coverage grid (sampled before the canvas pass).
    List<double>? halftoneGrid;
    int halftoneCols = 0, halftoneRows = 0;
    if (params.effectiveHalftone > 0) {
      halftoneCols = _halftoneCols(rect, params);
      if (halftoneCols >= 2) {
        halftoneRows =
            (halftoneCols * rect.height / rect.width).round().clamp(2, 400);
        halftoneGrid =
            await _coverageGrid(source, halftoneCols, halftoneRows);
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 1. Base: source with colour treatment + fade baked in.
    final basePaint = ui.Paint();
    final colorFilter = _buildColorFilter(params);
    if (colorFilter != null) basePaint.colorFilter = colorFilter;
    canvas.drawImageRect(source, srcRect, rect, basePaint);

    // 1b. Halftone — screen-print dot treatment. Keeps ink inside dots and
    //     thins it between them (partial transparency), so solid fills read as
    //     a dot screen. Dot geometry is in artwork-normalised space so preview
    //     and print match.
    if (params.effectiveHalftone > 0 && halftoneGrid != null) {
      _applyHalftone(
          canvas, rect, params, halftoneGrid, halftoneCols, halftoneRows);
    }

    // 2. Grain — masked to the artwork's alpha, composited with soft light so it
    //    modulates ink tone without tinting transparent areas.
    if (grainImg != null && params.grain > 0) {
      canvas.saveLayer(
        rect,
        ui.Paint()
          ..blendMode = ui.BlendMode.softLight
          ..color = ui.Color.fromRGBO(0, 0, 0, params.grain.clamp(0.0, 1.0)),
      );
      _fillTiled(canvas, rect, grainImg, ui.BlendMode.srcOver);
      // Keep grain only where the artwork has ink.
      canvas.drawImageRect(
        source,
        srcRect,
        rect,
        ui.Paint()..blendMode = ui.BlendMode.dstIn,
      );
      canvas.restore();
    }

    // 2b. Acid wash — cloudy bleach that lightens the ink in soft patches. A
    //     screen layer (bright cloud → lift toward white) masked to the artwork
    //     alpha, so the garment fabric between/around the ink is untouched.
    if (washImg != null && params.acidWash > 0) {
      _applyAcidWash(canvas, rect, source, srcRect, washImg, params.acidWash);
    }

    // 3. Distress → transparency. Dark blotches erase ink (dstOut), scaled by
    //    effectiveDistress (already reduced for detailed artwork) and locally
    //    spared where the protection mask marks emblems/text.
    if (distressImg != null) {
      _erase(canvas, rect, distressImg, params.effectiveDistress,
          protection: protectionImg, hardness: params.distressHardness);
    }

    // 3b. Fine mottle — dense grungy breakup layered over the coarse blotch.
    if (mottleImg != null) {
      _erase(canvas, rect, mottleImg, params.effectiveDistress * 0.7,
          protection: protectionImg, hardness: params.distressHardness);
    }

    // 3c. Cracks — thin transparent fissures through the ink. Not protected, so
    //     cracks read clearly even across emblems (matches cracked-paint refs).
    //     Always crisp regardless of the style's overall hardness.
    if (crackImg != null) {
      _erase(canvas, rect, crackImg, params.effectiveCracks, hardness: 0.85);
    }

    // 4. Scratches / ink chips (grunge-style ink loss), stronger streaks.
    if (scratchImg != null) {
      _erase(canvas, rect, scratchImg, params.effectiveRoughEdges,
          protection: protectionImg, hardness: params.distressHardness);
    }

    // 5. Stamp uneven ink + rough edges — finer, higher-contrast erosion that
    //    breaks up solid fills and roughens boundaries like a rubber stamp.
    //    Stamp ink reads crisp, so bias hardness up.
    if (stampInkImg != null) {
      _erase(canvas, rect, stampInkImg, params.effectiveRoughEdges,
          protection: protectionImg,
          hardness: math.max(params.distressHardness, 0.7));
    }

    // 6. Torn outer edge — frays the design boundary into the garment. Alpha of
    //    the mask already encodes the erase amount, so dstOut directly.
    if (tornEdgeImg != null) {
      canvas.drawImageRect(
        tornEdgeImg,
        ui.Rect.fromLTWH(
            0, 0, tornEdgeImg.width.toDouble(), tornEdgeImg.height.toDouble()),
        rect,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstOut
          ..filterQuality = ui.FilterQuality.low,
      );
    }

    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    protectionImg?.dispose();
    tornEdgeImg?.dispose();
    return out;
  }

  /// Whether the style uses the scratch texture for its rough-edge/ink-loss
  /// character. Grunge does; the stamp's rough *edges* are handled by a
  /// dedicated edge treatment in a later milestone.
  bool _usesScratches(PrintStyleParams p) =>
      p.id == PrintStyleId.grunge || p.id == PrintStyleId.vintage;

  /// Styles whose boundary should fray into the garment.
  bool _usesTornEdges(PrintStyleParams p) =>
      p.id == PrintStyleId.grunge ||
      p.id == PrintStyleId.vintage ||
      p.id == PrintStyleId.stamp ||
      p.id == PrintStyleId.edgeTear;

  /// Builds a torn-edge erase mask ([ui.Image], alpha = erase) sized to the
  /// artwork but capped for cost — the tear is low-frequency, so upscaling from
  /// the cap is imperceptible while keeping print-resolution renders cheap.
  Future<ui.Image> _buildTornEdgeImage(
      int seed, int w, int h, double strength) {
    const cap = 512;
    final longSide = w > h ? w : h;
    final scale = longSide > cap ? cap / longSide : 1.0;
    final tw = (w * scale).round().clamp(2, cap);
    final th = (h * scale).round().clamp(2, cap);
    // Deeper tears for stronger rough-edge styles (Edge Tear reaches furthest
    // into the garment; grunge/vintage stay a subtler fray).
    final margin = (0.10 + 0.16 * strength.clamp(0.0, 1.0)).clamp(0.10, 0.26);
    final bytes = generateTornEdgeBytes(
        seed: seed ^ 0xa5a5f00d,
        w: tw,
        h: th,
        margin: margin,
        strength: strength);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        bytes, tw, th, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Erases ink from the current canvas using [tex]'s luminance as the erase
  /// shape (dark = erase), scaled by [strength] (0..1), so distressed ink turns
  /// transparent (the garment shows through).
  ///
  /// When [protection] is supplied (its alpha marks high-contrast emblem/text
  /// pixels), the erase amount is locally reduced to `shape · strength ·
  /// (1 − protection)`, keeping important details inked even at high distress.
  /// This is achieved with a dst-out layer: the eraser shape is drawn into the
  /// layer, the protection mask thins it (dstOut inside the layer), and on
  /// restore the layer erodes the base.
  void _erase(
    ui.Canvas canvas,
    ui.Rect rect,
    ui.Image tex,
    double strength, {
    ui.Image? protection,
    double hardness = 0.5,
  }) {
    final s = strength.clamp(0.0, 1.0);
    if (s <= 0) return;
    // Map luminance→alpha (dark texture → high erase alpha), scaled by strength,
    // and zero the RGB so only alpha matters.
    //
    // [hardness] steepens the luminance→alpha ramp with a contrast gain about
    // the midpoint: low hardness → soft, cloudy fade; high hardness → the ramp
    // clips to 0/255 quickly, giving sharp worn chunks (real distress / stamp).
    //   e   = 255 - lum                       (linear eraser)
    //   e'  = 128 + gain·(e - 128)  clamped    (contrast about mid)
    //   A'  = strength · e'
    // With R=G=B=lum: coefficient = -s·gain/3 per channel; the clamp is applied
    // by the alpha channel itself (0..255).
    final gain = 1.0 + hardness.clamp(0.0, 1.0) * 3.0; // 1 (soft) … 4 (hard)
    final coef = -s * gain / 3.0;
    final constA = s * (128.0 + 127.0 * gain);
    final matrix = <double>[
      0, 0, 0, 0, 0, // R' = 0
      0, 0, 0, 0, 0, // G' = 0
      0, 0, 0, 0, 0, // B' = 0
      coef, coef, coef, 0, constA, // A'
    ];

    if (protection == null) {
      canvas.drawRect(
        rect,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstOut
          ..colorFilter = ui.ColorFilter.matrix(matrix)
          ..shader = ui.ImageShader(tex, ui.TileMode.repeated,
              ui.TileMode.repeated, _tileMatrix(rect, tex)),
      );
      return;
    }

    // Protected path: accumulate the eraser in a layer, thin it where protected,
    // then dst-out the whole layer onto the base.
    canvas.saveLayer(rect, ui.Paint()..blendMode = ui.BlendMode.dstOut);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..colorFilter = ui.ColorFilter.matrix(matrix)
        ..shader = ui.ImageShader(tex, ui.TileMode.repeated,
            ui.TileMode.repeated, _tileMatrix(rect, tex)),
    );
    // Thin the eraser where protection alpha is high (dstOut inside the layer).
    canvas.drawImageRect(
      protection,
      ui.Rect.fromLTWH(
          0, 0, protection.width.toDouble(), protection.height.toDouble()),
      rect,
      ui.Paint()
        ..blendMode = ui.BlendMode.dstOut
        ..filterQuality = ui.FilterQuality.low,
    );
    canvas.restore();
  }

  /// Lifts the ink toward white in soft cloudy patches (acid-wash bleach).
  ///
  /// The grayscale [wash] cloud is tiled and screened over the current canvas
  /// (bright cloud → bleach, dark cloud → untouched), scaled by [intensity], and
  /// masked to the artwork's own alpha so only inked pixels bleach — the garment
  /// fabric stays clean.
  void _applyAcidWash(
    ui.Canvas canvas,
    ui.Rect rect,
    ui.Image source,
    ui.Rect srcRect,
    ui.Image wash,
    double intensity,
  ) {
    final s = intensity.clamp(0.0, 1.0);
    if (s <= 0) return;
    canvas.saveLayer(rect, ui.Paint()..blendMode = ui.BlendMode.screen);
    // Tile the cloud, scaling brightness by intensity so the bleach lift is
    // controlled (RGB × s; full alpha inside the masked region).
    canvas.drawRect(
      rect,
      ui.Paint()
        ..colorFilter = ui.ColorFilter.matrix(<double>[
          s, 0, 0, 0, 0, //
          0, s, 0, 0, 0, //
          0, 0, s, 0, 0, //
          0, 0, 0, 0, 255, //
        ])
        ..shader = ui.ImageShader(wash, ui.TileMode.repeated,
            ui.TileMode.repeated, _tileMatrix(rect, wash)),
    );
    // Confine the bleach to inked pixels.
    canvas.drawImageRect(
      source,
      srcRect,
      rect,
      ui.Paint()..blendMode = ui.BlendMode.dstIn,
    );
    canvas.restore();
  }

  /// Fraction of an edge pixel's strength used as local distress protection.
  static const double _kProtectStrength = 0.85;

  /// Builds a protection mask image (alpha = local edge strength) from the
  /// artwork detail analysis, or null when no analysis / edges are present.
  /// The mask is small (analysis resolution) and upscaled during compositing.
  Future<ui.Image?> _buildProtectionImage(ArtworkDetail? detail) async {
    if (detail == null || detail.mapWidth <= 1 || detail.mapHeight <= 1) {
      return null;
    }
    final w = detail.mapWidth;
    final h = detail.mapHeight;
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      final o = i * 4;
      // rgb=0; alpha = edge strength scaled by protect strength.
      rgba[o + 3] = (detail.edgeMap[i] * _kProtectStrength).round().clamp(0, 255);
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Number of dot cells across the artwork's shorter side for a given style.
  int _halftoneCols(ui.Rect rect, PrintStyleParams p) {
    final shortSide = rect.width < rect.height ? rect.width : rect.height;
    final cell = (p.halftoneScale.clamp(0.004, 0.2)) * shortSide;
    if (cell < 1) return 0;
    return (shortSide / cell).round().clamp(2, 400);
  }

  /// Applies a halftone dot screen whose dot size follows the artwork's local
  /// ink coverage ([grid]: `cols × rows`, values 0..1). Denser/darker ink → big
  /// dots (near-solid); faint/edge ink → small dots that dissolve into a burst —
  /// matching classic screen-print halftone. Composited with [BlendMode.dstIn]
  /// so between-dot areas become transparent (garment shows through).
  ///
  /// The grid is sampled in artwork-normalised space, so the dot geometry is
  /// identical in preview and print.
  void _applyHalftone(
    ui.Canvas canvas,
    ui.Rect rect,
    PrintStyleParams p,
    List<double> grid,
    int cols,
    int rows,
  ) {
    final intensity = p.effectiveHalftone.clamp(0.0, 1.0);
    if (intensity <= 0 || cols < 2 || rows < 2) return;
    final cellW = rect.width / cols;
    final cellH = rect.height / rows;
    final cell = cellW < cellH ? cellW : cellH;
    // Large enough that full-coverage cells fill solid (no interior gaps); lower
    // coverage shrinks the dot, so only faint/edge areas dissolve into a burst.
    final maxRadius = cell * 0.95;

    canvas.saveLayer(rect, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    // Baseline: gaps retain (1 - intensity) of the ink (0 for pure Halftone).
    canvas.drawRect(
      rect,
      ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, 1 - intensity),
    );
    final dot = ui.Paint()..color = const ui.Color(0xFFFFFFFF);

    // Rotate the dot lattice to [halftoneAngle] (classic AM screens sit at 45°,
    // where the eye least reads the grid) and offset alternate rows by half a
    // cell (brick packing) so it reads as a screen, not a square dot matrix.
    // Coverage is sampled from the axis-aligned [grid] at each dot's centre.
    final angle = p.halftoneAngle;
    final ca = math.cos(angle);
    final sa = math.sin(angle);
    final cx0 = rect.center.dx;
    final cy0 = rect.center.dy;
    // Lattice must cover the rect after rotation → span its diagonal.
    final diag =
        math.sqrt(rect.width * rect.width + rect.height * rect.height);
    final n = (diag / cell).ceil() + 2;
    for (var j = -n; j <= n; j++) {
      final rowOffset = (j & 1) == 0 ? 0.0 : 0.5; // brick offset
      final ly = j * cell;
      for (var i = -n; i <= n; i++) {
        final lx = (i + rowOffset) * cell;
        // Rotate the lattice point about the artwork centre.
        final px = cx0 + lx * ca - ly * sa;
        final py = cy0 + lx * sa + ly * ca;
        if (px < rect.left - cell ||
            px > rect.right + cell ||
            py < rect.top - cell ||
            py > rect.bottom + cell) {
          continue;
        }
        // Sample coverage at this centre (nearest cell in the axis-aligned grid).
        final gx = ((px - rect.left) / rect.width * cols)
            .floor()
            .clamp(0, cols - 1);
        final gy = ((py - rect.top) / rect.height * rows)
            .floor()
            .clamp(0, rows - 1);
        final cov = grid[gy * cols + gx];
        if (cov <= 0.02) continue;
        // Area ∝ coverage → radius ∝ sqrt(coverage).
        final r = maxRadius * math.sqrt(cov.clamp(0.0, 1.0));
        if (r < 0.3) continue;
        canvas.drawCircle(ui.Offset(px, py), r, dot);
      }
    }
    canvas.restore();
  }

  /// Downsamples [source] to a `cols × rows` coverage grid (0..1) for halftone
  /// dot sizing. Coverage combines ink presence (alpha) with a darkness boost so
  /// darker ink produces larger dots. Small readback (cols×rows), cheap even at
  /// print resolution.
  Future<List<double>> _coverageGrid(
    ui.Image source,
    int cols,
    int rows,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final small = await picture.toImage(cols, rows);
    picture.dispose();
    final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    final grid = List<double>.filled(cols * rows, 0);
    if (data == null) return grid;
    final bytes = data.buffer.asUint8List();
    // Edge feather: fade coverage toward the artwork border so the outer band
    // dissolves into a graduated dot burst (centre stays solid) — the classic
    // halftone look (ref: halftone.jpeg). Margin as a fraction of each axis.
    const feather = 0.16;
    for (var ry = 0; ry < rows; ry++) {
      final ny = rows > 1 ? ry / (rows - 1) : 0.5;
      final vY = _smoothEdge(ny, feather);
      for (var cx = 0; cx < cols; cx++) {
        final nx = cols > 1 ? cx / (cols - 1) : 0.5;
        final vignette = math.min(_smoothEdge(nx, feather), vY);
        final o = (ry * cols + cx) * 4;
        final a = bytes[o + 3] / 255.0;
        final lum =
            (bytes[o] * 0.299 + bytes[o + 1] * 0.587 + bytes[o + 2] * 0.114) /
                255.0;
        final darkness = 1.0 - lum;
        grid[ry * cols + cx] =
            (a * (0.82 + 0.18 * darkness) * vignette).clamp(0.0, 1.0);
      }
    }
    return grid;
  }

  /// Smoothstep ramp that is 1 in the interior and falls to 0 within [margin]
  /// of either edge (position [t] in 0..1).
  double _smoothEdge(double t, double margin) {
    final d = t < 0.5 ? t : 1 - t;
    if (d >= margin) return 1.0;
    final x = (d / margin).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// Fills [rect] by tiling [tex] with the given [blendMode].
  void _fillTiled(
    ui.Canvas canvas,
    ui.Rect rect,
    ui.Image tex,
    ui.BlendMode blendMode,
  ) {
    final paint = ui.Paint()
      ..blendMode = blendMode
      ..shader = ui.ImageShader(
        tex,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        _tileMatrix(rect, tex),
      );
    canvas.drawRect(rect, paint);
  }

  /// Scales the tile so a fixed number of repeats spans the artwork's shorter
  /// side — keeps texture frequency resolution-independent (preview ↔ print).
  Float64List _tileMatrix(ui.Rect rect, ui.Image tex) {
    const repeatsAcrossShortSide = 3.0;
    final shortSide = rect.width < rect.height ? rect.width : rect.height;
    final scale = shortSide / (tex.width * repeatsAcrossShortSide);
    return Float64List.fromList(<double>[
      scale, 0, 0, 0, //
      0, scale, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]);
  }

  /// Builds the colour-grading filter from [colorTreatment] + [fade].
  /// Returns null when neither applies (base drawn untouched).
  ui.ColorFilter? _buildColorFilter(PrintStyleParams p) {
    final isDuotone = p.colorTreatment == ColorTreatment.duotone &&
        p.duotoneA != null &&
        p.duotoneB != null;
    if (p.colorTreatment == ColorTreatment.none && p.fade <= 0 && !isDuotone) {
      return null;
    }

    // Duotone maps luminance onto a two-colour gradient (a→shadow, b→highlight).
    // Expressible as a single colour matrix, so it composes with fade below.
    if (isDuotone) {
      var m = _duotone(p.duotoneA!, p.duotoneB!);
      if (p.fade > 0) m = _mul(_fade(p.fade), m);
      return ui.ColorFilter.matrix(m);
    }

    // Compose: fade(contrast/lift) · warm · saturation.
    var m = _identity();

    final sat = switch (p.colorTreatment) {
      ColorTreatment.muted => 0.75,
      ColorTreatment.vintageWarm => 0.6,
      ColorTreatment.monoInk => 0.0,
      _ => 1.0,
    };
    if (sat != 1.0) m = _mul(_saturation(sat), m);

    if (p.colorTreatment == ColorTreatment.vintageWarm) {
      m = _mul(_warm(), m);
    }

    if (p.fade > 0) {
      m = _mul(_fade(p.fade), m);
    }

    return ui.ColorFilter.matrix(m);
  }

  /// Duotone colour matrix: output channel = a + (b − a)·luma, per channel, with
  /// alpha preserved. Maps dark ink toward [a] and bright ink toward [b].
  List<double> _duotone(ui.Color a, ui.Color b) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    List<double> row(double bc, double ac) {
      final aInt = ch(ac);
      // out = a + (b-a)·(luma/255). luma = lr·R+lg·G+lb·B is 0..255, so the
      // per-channel coefficients carry the /255 normalisation.
      final d = (ch(bc) - aInt) / 255.0;
      return <double>[d * lr, d * lg, d * lb, 0, aInt.toDouble()];
    }

    return <double>[
      ...row(b.r, a.r),
      ...row(b.g, a.g),
      ...row(b.b, a.b),
      0, 0, 0, 1, 0, //
    ];
  }

  // ── Colour matrix helpers (4×5 row-major, Flutter ColorFilter.matrix) ──────

  List<double> _identity() => <double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ];

  /// Luminance-preserving saturation. [s] = 1 identity, 0 grayscale.
  List<double> _saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = 1 - s;
    return <double>[
      lr * sr + s, lg * sr, lb * sr, 0, 0, //
      lr * sr, lg * sr + s, lb * sr, 0, 0, //
      lr * sr, lg * sr, lb * sr + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Warm, aged cast: lift reds, drop blues, small sepia bias.
  List<double> _warm() => <double>[
        1.06, 0, 0, 0, 6, //
        0, 1.0, 0, 0, 2, //
        0, 0, 0.86, 0, -4, //
        0, 0, 0, 1, 0, //
      ];

  /// Fade: reduce contrast toward mid-gray and lift the black point. [f] 0..1.
  List<double> _fade(double f) {
    final c = 1 - 0.4 * f; // contrast multiplier
    final lift = 22 * f; // black-point lift in 0..255
    final bias = 128 * (1 - c) + lift;
    return <double>[
      c, 0, 0, 0, bias, //
      0, c, 0, 0, bias, //
      0, 0, c, 0, bias, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Multiplies two 4×5 colour matrices (applies [a] after [b]).
  List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        // Add a's translation column contribution when col is the constant col.
        if (col == 4) sum += a[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }
}
