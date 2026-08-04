import 'dart:async';
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
    // Local protection mask (keeps emblems/text inked). Only needed when an
    // ink-removing pass runs.
    final needsErase = distressImg != null || scratchImg != null ||
        stampInkImg != null;
    final protectionImg =
        needsErase ? await _buildProtectionImage(params.detail) : null;

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
    if (params.effectiveHalftone > 0) {
      _applyHalftone(canvas, rect, params);
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

    // 3. Distress → transparency. Dark blotches erase ink (dstOut), scaled by
    //    effectiveDistress (already reduced for detailed artwork) and locally
    //    spared where the protection mask marks emblems/text.
    if (distressImg != null) {
      _erase(canvas, rect, distressImg, params.effectiveDistress,
          protection: protectionImg);
    }

    // 4. Scratches / ink chips (grunge-style ink loss), stronger streaks.
    if (scratchImg != null) {
      _erase(canvas, rect, scratchImg, params.effectiveRoughEdges,
          protection: protectionImg);
    }

    // 5. Stamp uneven ink + rough edges — finer, higher-contrast erosion that
    //    breaks up solid fills and roughens boundaries like a rubber stamp.
    if (stampInkImg != null) {
      _erase(canvas, rect, stampInkImg, params.effectiveRoughEdges,
          protection: protectionImg);
    }

    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    protectionImg?.dispose();
    return out;
  }

  /// Whether the style uses the scratch texture for its rough-edge/ink-loss
  /// character. Grunge does; the stamp's rough *edges* are handled by a
  /// dedicated edge treatment in a later milestone.
  bool _usesScratches(PrintStyleParams p) =>
      p.id == PrintStyleId.grunge || p.id == PrintStyleId.vintage;

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
  }) {
    final s = strength.clamp(0.0, 1.0);
    if (s <= 0) return;
    // Map luminance→alpha (dark texture → high erase alpha), scaled by strength,
    // and zero the RGB so only alpha matters.
    final matrix = <double>[
      0, 0, 0, 0, 0, // R' = 0
      0, 0, 0, 0, 0, // G' = 0
      0, 0, 0, 0, 0, // B' = 0
      // A' = strength * (255 - luminance); with R=G=B=lum, coefficient -s/3 each.
      -s / 3, -s / 3, -s / 3, 0, 255 * s,
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

  /// Applies a halftone dot screen to the current canvas contents. Builds an
  /// alpha mask (dots = keep ink, gaps = keep `1 - intensity` of ink) and
  /// composites it onto the artwork with [BlendMode.dstIn], so between-dot
  /// areas become partially transparent — a screen-print look that still shows
  /// the garment through the gaps.
  ///
  /// The cell size is [PrintStyleParams.halftoneScale] × the artwork's shorter
  /// side, so the dot frequency is identical in preview and print.
  void _applyHalftone(ui.Canvas canvas, ui.Rect rect, PrintStyleParams p) {
    final intensity = p.effectiveHalftone.clamp(0.0, 1.0);
    if (intensity <= 0) return;
    final shortSide = rect.width < rect.height ? rect.width : rect.height;
    final cell = (p.halftoneScale.clamp(0.004, 0.2)) * shortSide;
    if (cell < 1) return;
    final radius = cell * 0.42;

    canvas.saveLayer(rect, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    // Baseline: gaps retain (1 - intensity) of the ink.
    canvas.drawRect(
      rect,
      ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, 1 - intensity),
    );
    // Dots retain full ink.
    final dot = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    for (var cy = rect.top + cell / 2; cy < rect.bottom; cy += cell) {
      for (var cx = rect.left + cell / 2; cx < rect.right; cx += cell) {
        canvas.drawCircle(ui.Offset(cx, cy), radius, dot);
      }
    }
    canvas.restore();
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
