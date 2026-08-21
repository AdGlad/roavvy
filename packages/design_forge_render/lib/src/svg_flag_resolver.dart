import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'asset_resolver.dart';

/// Loads a string asset for a key (flag code / silhouette slug / outline id),
/// e.g. from disk or the asset bundle.
typedef SvgStringLookup = Future<String> Function(String key);

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
  })  : _silhouetteLookup = silhouetteLookup,
        _countryOutlineLookup = countryOutlineLookup,
        _continentOutlineLookup = continentOutlineLookup;

  final SvgStringLookup _flagLookup;
  final SvgStringLookup? _silhouetteLookup;

  /// Returns a `{w,h,polys:[[[x,y]…]…]}` JSON string for a country/continent id.
  final SvgStringLookup? _countryOutlineLookup;
  final SvgStringLookup? _continentOutlineLookup;

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
    return Future.value(null);
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
