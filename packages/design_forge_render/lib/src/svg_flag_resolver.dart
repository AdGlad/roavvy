import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'asset_resolver.dart';

/// Loads a string asset for a key (flag code / silhouette slug / outline id),
/// e.g. from disk or the asset bundle.
typedef SvgStringLookup = Future<String> Function(String key);

/// Loads raw bytes for a key (e.g. a PNG stamp), from disk or the asset bundle.
typedef AssetBytesLookup = Future<Uint8List> Function(String key);

/// An [AssetResolver] that rasterises flag SVGs (and, optionally, silhouette
/// SVGs used as clip masks) via `flutter_svg` — fully headless (no widget tree,
/// no `BuildContext`). Rasterised images are cached so batch/live renders don't
/// re-parse SVGs.
class SvgFlagResolver implements AssetResolver {
  SvgFlagResolver(
    this._flagLookup, {
    SvgStringLookup? silhouetteLookup,
    SvgStringLookup? countryOutlineLookup,
    SvgStringLookup? continentOutlineLookup,
    AssetBytesLookup? passportStampLookup,
    SvgStringLookup? passportMetaLookup,
  })  : _silhouetteLookup = silhouetteLookup,
        _countryOutlineLookup = countryOutlineLookup,
        _continentOutlineLookup = continentOutlineLookup,
        _passportStampLookup = passportStampLookup,
        _passportMetaLookup = passportMetaLookup;

  final SvgStringLookup _flagLookup;
  final SvgStringLookup? _silhouetteLookup;

  /// Returns a `{w,h,polys:[[[x,y]…]…]}` JSON string for a country/continent id.
  final SvgStringLookup? _countryOutlineLookup;
  final SvgStringLookup? _continentOutlineLookup;

  /// Returns raw PNG bytes for a real passport entry/exit stamp (ink on
  /// transparent) — its alpha is used directly as the clip mask.
  final AssetBytesLookup? _passportStampLookup;

  /// Returns the stamp's JSON metadata (date x/y/font, image w/h) so the trip
  /// date can be drawn at the right spot, matching the passport t-shirt.
  final SvgStringLookup? _passportMetaLookup;

  final Map<String, Future<ui.Image>> _flagCache = {};
  final Map<String, Future<ui.Image?>> _maskCache = {};

  @override
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  }) {
    final key = '$code@${width}x$height';
    return _flagCache.putIfAbsent(
        key, () => _rasterFill(_flagLookup, code.toLowerCase(), width, height));
  }

  @override
  Future<ui.Image?> resolveClipMask(
    ClipShape shape,
    String? code, {
    required int width,
    required int height,
  }) {
    if (code == null) return Future.value(null);
    final key = '${shape.name}:$code@${width}x$height';

    final isSilhouette = shape == ClipShape.animalSilhouette ||
        shape == ClipShape.plantSilhouette ||
        shape == ClipShape.landmarkSilhouette;
    if (isSilhouette && _silhouetteLookup != null) {
      return _maskCache.putIfAbsent(
          key, () => _rasterContain(_silhouetteLookup!, code, width, height));
    }
    if (shape == ClipShape.countryOutline && _countryOutlineLookup != null) {
      return _maskCache.putIfAbsent(
          key, () => _rasterOutline(_countryOutlineLookup!, code, width, height));
    }
    if (shape == ClipShape.continentOutline && _continentOutlineLookup != null) {
      return _maskCache.putIfAbsent(
          key, () => _rasterOutline(_continentOutlineLookup!, code, width, height));
    }
    if (shape == ClipShape.passportStampOutline && _passportStampLookup != null) {
      // code may be `slug` or `slug|DATE` (real trip date, drawn on the stamp).
      final bar = code.indexOf('|');
      final slug = bar < 0 ? code : code.substring(0, bar);
      final date = bar < 0 ? null : code.substring(bar + 1);
      return _maskCache.putIfAbsent(
          key, () => _stampInk(slug, date, width, height));
    }
    return Future.value(null);
  }

  Future<ui.Image?> _decodePng(AssetBytesLookup lookup, String key) async {
    try {
      final codec = await ui.instantiateImageCodec(await lookup(key));
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// A stamp's **ink** as a [w]×[h] alpha image: the PNG (contain-fit, centred)
  /// plus the trip [date] drawn at the metadata position (`middle`-anchored), so
  /// the alpha is exactly the stamp outline + date — no added border. Used both
  /// as a clip mask and (via [_flagStamp]) as the flag-fill mask, so the date
  /// reads in the stamp's ink colour, matching the real passport t-shirt.
  Future<ui.Image?> _stampInk(String slug, String? date, int w, int h) async {
    final stamp = await _decodePng(_passportStampLookup!, slug);
    if (stamp == null) return null;
    _StampDateSpec? spec;
    if (date != null && date.trim().isNotEmpty && _passportMetaLookup != null) {
      try {
        spec = _StampDateSpec.parse(await _passportMetaLookup!(slug));
      } catch (_) {/* no date overlay */}
    }
    final out = await _record(w, h, (canvas) {
      final s = math.min(w / stamp.width, h / stamp.height) * 0.96;
      final dw = stamp.width * s, dh = stamp.height * s;
      final ox = (w - dw) / 2, oy = (h - dh) / 2;
      canvas.drawImageRect(
          stamp,
          ui.Rect.fromLTWH(0, 0, stamp.width.toDouble(), stamp.height.toDouble()),
          ui.Rect.fromLTWH(ox, oy, dw, dh),
          ui.Paint()..filterQuality = ui.FilterQuality.medium);
      if (spec != null) {
        final para = (ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: ui.TextAlign.left,
          fontSize: spec.fontSize * s,
          fontWeight: _fontWeight(spec.fontWeight),
        ))
              ..pushStyle(ui.TextStyle(
                  color: const ui.Color(0xFFFFFFFF),
                  letterSpacing: spec.letterSpacing * s))
              ..addText(date!.trim()))
            .build()
          ..layout(const ui.ParagraphConstraints(width: 100000));
        final tw = para.longestLine <= 0 ? para.maxIntrinsicWidth : para.longestLine;
        final th = para.height;
        // Date position is `middle`-anchored at (spec.x, spec.y) in image coords.
        canvas.drawParagraph(
            para, ui.Offset(ox + spec.x * s - tw / 2, oy + spec.y * s - th / 2));
      }
    });
    stamp.dispose();
    return out;
  }

  static ui.FontWeight _fontWeight(int w) =>
      ui.FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)];

  /// A single stamp image at [size]²: the stamp ink (+ [date]) inked per [ink] —
  /// filled with the country's own flag, or plain solid black / white on
  /// transparent (a real passport stamp). Null if the stamp asset is missing.
  Future<ui.Image?> _stampImage(
      String slug, String? date, int size, PassportInk ink) async {
    final mask = await _stampInk(slug, date, size, size);
    if (mask == null) return null;
    final rect = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    ui.Image out;
    if (ink == PassportInk.flag) {
      final cc = slug.split('_').first;
      final flag = await resolveFlag(cc, width: size, height: size);
      out = await _record(size, size, (canvas) {
        canvas.saveLayer(rect, ui.Paint());
        final fs = math.max(size / flag.width, size / flag.height);
        canvas.drawImageRect(
            flag,
            ui.Rect.fromLTWH(0, 0, flag.width.toDouble(), flag.height.toDouble()),
            ui.Rect.fromCenter(
                center: ui.Offset(size / 2, size / 2),
                width: flag.width * fs,
                height: flag.height * fs),
            ui.Paint()..filterQuality = ui.FilterQuality.medium);
        canvas.drawImage(
            mask, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
        canvas.restore();
      });
    } else {
      final colour = ink == PassportInk.black
          ? const ui.Color(0xFF000000)
          : const ui.Color(0xFFFFFFFF);
      out = await _record(size, size, (canvas) {
        canvas.saveLayer(rect, ui.Paint());
        canvas.drawRect(rect, ui.Paint()..color = colour);
        canvas.drawImage(
            mask, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
        canvas.restore();
      });
    }
    mask.dispose();
    return out;
  }

  @override
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async {
    if (_passportStampLookup == null || stamps.isEmpty) return null;
    final key = 'collage:${[for (final s in stamps) '${s.slug}=${s.date}'].join(",")}'
        '@${width}x$height#$seed:${scatter.toStringAsFixed(2)}'
        ':${stampScale.toStringAsFixed(2)}:${ink.name}';
    return _maskCache.putIfAbsent(key, () async {
      final cell = (math.min(width, height) / 2.4).round().clamp(64, 640);
      final items = <ui.Image>[];
      for (final ref in stamps) {
        final s = await _stampImage(ref.slug.toLowerCase(), ref.date, cell, ink);
        if (s != null) items.add(s);
      }
      if (items.isEmpty) return null;
      final n = items.length;

      final rng = DeterministicRng(seed != 0
              ? seed
              : _stableHash([for (final s in stamps) s.slug].join(',')))
          .stream('collage');

      // Random placement (mobile parity): shuffle, then even grid cells with
      // per-cell jitter (scatter). Fisher–Yates for a deterministic shuffle.
      final order = List<int>.generate(n, (i) => i);
      for (var i = n - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final t = order[i];
        order[i] = order[j];
        order[j] = t;
      }

      final margin = 0.05;
      final marginX = width * margin, marginY = height * margin;
      final usableW = width - marginX * 2, usableH = height - marginY * 2;
      final aspect = usableW / math.max(1.0, usableH);
      final rows = math.max(1, math.sqrt(n / aspect).ceil());
      final cols = math.max(1, (n / rows).ceil());
      final cellW = usableW / cols, cellH = usableH / rows;
      final base = math.min(cellW, cellH);

      return _record(width, height, (canvas) {
        void place(ui.Image img, double cx, double cy, double deg, double target) {
          final s = target / math.max(img.width, img.height).toDouble();
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(deg * math.pi / 180);
          canvas.scale(s);
          canvas.drawImage(img, ui.Offset(-img.width / 2, -img.height / 2),
              ui.Paint()..filterQuality = ui.FilterQuality.medium);
          canvas.restore();
        }

        for (var k = 0; k < n; k++) {
          final img = items[order[k]];
          final col = k % cols, row = k ~/ cols;
          // Jitter within the cell by the scatter amount (0 = tight grid).
          final jx = (rng.nextDouble() - 0.5) * cellW * scatter;
          final jy = (rng.nextDouble() - 0.5) * cellH * scatter;
          final variety = 0.9 + rng.nextDouble() * 0.2;
          // Adaptive: cells shrink with count; stampScale lets the user pack
          // more in. Capped so a few stamps don't blow up the page.
          final target = math.min(
              base * 1.12 * variety * stampScale, math.min(width, height) * 0.8);
          final half = target * 0.55;
          final cx = (marginX + (col + 0.5) * cellW + jx)
              .clamp(marginX + half, width - marginX - half);
          final cy = (marginY + (row + 0.5) * cellH + jy)
              .clamp(marginY + half, height - marginY - half);
          place(img, cx, cy, (rng.nextDouble() * 2 - 1) * 20, target);
        }
        for (final img in items) {
          img.dispose();
        }
      });
    });
  }

  /// Small stable hash (FNV-1a) so the collage scatter is reproducible across
  /// sessions (String.hashCode is not guaranteed stable).
  int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 0x01000193;
      h &= 0x7fffffff;
    }
    return h;
  }

  /// Rasterise a flag SVG at its **native aspect ratio**, scaled to fit within
  /// width×height. The returned image therefore carries the flag's true
  /// proportions (e.g. 3:2), so the composition stage can fit/cover it without
  /// distortion (no more stretched discs). Returns the largest non-distorted
  /// raster that fits the requested box.
  Future<ui.Image> _rasterFill(
      SvgStringLookup lookup, String key, int width, int height) async {
    final info = await vg.loadPicture(SvgStringLoader(await lookup(key)), null);
    final picture = info.picture;
    final src = info.size;
    final s = (src.width <= 0 || src.height <= 0)
        ? 1.0
        : math.min(width / src.width, height / src.height);
    final w = math.max(1, (src.width * s).round());
    final h = math.max(1, (src.height * s).round());
    final image = await _record(w, h, (canvas) {
      canvas.scale(s, s);
      canvas.drawPicture(picture);
    });
    picture.dispose();
    return image;
  }

  /// Rasterise an SVG aspect-fit (contain) and centred into width×height on a
  /// transparent background — for silhouette clip masks (the opaque shape is the
  /// mask). Returns null if the asset is missing.
  Future<ui.Image?> _rasterContain(
      SvgStringLookup lookup, String key, int width, int height) async {
    String svg;
    try {
      svg = _sanitizeSvg(await lookup(key));
    } catch (_) {
      return null;
    }
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    final picture = info.picture;
    final src = info.size;
    final image = await _record(width, height, (canvas) {
      final s = src.width == 0 || src.height == 0
          ? 1.0
          : math.min(width / src.width, height / src.height) * 0.92;
      final dw = src.width * s;
      final dh = src.height * s;
      canvas.translate((width - dw) / 2, (height - dh) / 2);
      canvas.scale(s, s);
      canvas.drawPicture(picture);
    });
    picture.dispose();
    return image;
  }

  /// Repairs common malformations in the bundled potrace silhouette SVGs so the
  /// stricter `flutter_svg` compiler accepts them:
  ///  * strips the `<!DOCTYPE …>` and `<metadata>…</metadata>` blocks;
  ///  * fixes the misplaced self-closing slash `<path d="…"/ fill-rule="…">`
  ///    → `<path d="…" fill-rule="…"/>` (potrace emits the `/` in the wrong spot).
  static String _sanitizeSvg(String svg) {
    var s = svg
        .replaceFirst(RegExp(r'<!DOCTYPE[^>]*>', dotAll: true), '')
        .replaceAll(RegExp(r'<metadata>.*?</metadata>', dotAll: true), '');
    // Move a stray `/ ` (slash + space + trailing attributes) to a proper `/>`.
    s = s.replaceAllMapped(RegExp(r'/(\s+[^>/]*?)>'), (m) => '${m[1]}/>');
    return s;
  }

  /// Rasterise a country/continent OUTLINE (`{w,h,polys}` polygon JSON) into a
  /// filled alpha mask, aspect-fit and centred. Returns null if missing/invalid.
  Future<ui.Image?> _rasterOutline(
      SvgStringLookup lookup, String key, int width, int height) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(await lookup(key.toLowerCase())) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final w0 = (data['w'] as num?)?.toDouble() ?? 0;
    final h0 = (data['h'] as num?)?.toDouble() ?? 0;
    final polys = data['polys'] as List?;
    if (w0 <= 0 || h0 <= 0 || polys == null || polys.isEmpty) return null;

    final path = ui.Path();
    for (final poly in polys) {
      final pts = poly as List;
      for (var i = 0; i < pts.length; i++) {
        final p = pts[i] as List;
        final x = (p[0] as num).toDouble();
        final y = (p[1] as num).toDouble();
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    return _record(width, height, (canvas) {
      final s = math.min(width / w0, height / h0) * 0.94;
      canvas.translate((width - w0 * s) / 2, (height - h0 * s) / 2);
      canvas.scale(s, s);
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF)
          ..style = ui.PaintingStyle.fill
          ..isAntiAlias = true,
      );
    });
  }

  Future<ui.Image> _record(
      int width, int height, void Function(ui.Canvas) draw) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    draw(canvas);
    return recorder.endRecording().toImage(width, height);
  }
}

/// The date-overlay spec parsed from a stamp's `mobile_meta/<base>.json` — where
/// and how to draw the trip date, in the PNG's native image coordinate space.
/// Mirrors the fields the production passport t-shirt uses.
class _StampDateSpec {
  const _StampDateSpec({
    required this.x,
    required this.y,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
  });

  final double x;
  final double y;
  final double fontSize;
  final int fontWeight;
  final double letterSpacing;

  static _StampDateSpec parse(String jsonStr) {
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    final d = (j['date'] as Map).cast<String, dynamic>();
    return _StampDateSpec(
      x: (d['x'] as num).toDouble(),
      y: (d['y'] as num).toDouble(),
      fontSize: (d['font_size'] as num).toDouble(),
      fontWeight: (d['font_weight'] as num?)?.toInt() ?? 700,
      letterSpacing: (d['letter_spacing'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
