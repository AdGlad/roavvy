import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'heart_layout_engine.dart';

// ── FlagImageCache ─────────────────────────────────────────────────────────────

/// LRU cache for rendered flag images, keyed by `{countryCode}_{tileSize}`.
///
/// Bounded to [maxEntries] to avoid unbounded memory growth.
class FlagImageCache {
  FlagImageCache({this.maxEntries = 300});

  final int maxEntries;

  final _cache = <String, ui.Image>{};  // insertion-ordered Map for LRU

  String _key(String code, double tileSize) =>
      '${code.toLowerCase()}_${tileSize.round()}';

  /// Returns the cached [ui.Image] for [code] at [tileSize], or `null`.
  ui.Image? get(String code, double tileSize) =>
      _cache[_key(code, tileSize)];

  /// Stores [image] for [code] at [tileSize], evicting oldest entry if full.
  void put(String code, double tileSize, ui.Image image) {
    final k = _key(code, tileSize);
    if (_cache.containsKey(k)) {
      _cache.remove(k);
    } else if (_cache.length >= maxEntries) {
      // Evict the oldest (first) entry.
      _cache.remove(_cache.keys.first);
    }
    _cache[k] = image;
  }

  /// Removes all entries.
  void clear() => _cache.clear();

  int get length => _cache.length;
}

// ── FlagTileRenderer ──────────────────────────────────────────────────────────

/// Renders a flag tile (SVG or emoji fallback) onto [canvas].
class FlagTileRenderer {
  const FlagTileRenderer._();

  /// SVG asset path for a given lowercase country code.
  static String svgAssetPath(String code) =>
      'assets/flags/svg/${code.toLowerCase()}.svg';

  /// Returns `true` when a flag SVG asset is expected for [code].
  ///
  /// Checks against the known bundle list.
  static bool hasSvg(String code) => _kBundledCodes.contains(code.toLowerCase());

  /// Draws the flag for [tile.countryCode] onto [canvas].
  ///
  /// If a cached [ui.Image] is available it is drawn immediately. Otherwise,
  /// falls back to drawing the emoji flag character using [TextPainter].
  ///
  /// [cornerRadius] is applied via a rounded-rect clip before drawing.
  /// [gapWidth] reduces the effective tile rect on all sides by gapWidth/2.
  static void renderFromCache(
    Canvas canvas,
    HeartTilePosition tile,
    FlagImageCache cache, {
    double cornerRadius = 2.0,
    double gapWidth = 1.0,
  }) {
    final inset = gapWidth / 2;
    final dst = tile.rect.deflate(inset);
    if (dst.isEmpty) return;

    final cached = cache.get(tile.countryCode, tile.rect.width);
    if (cached != null) {
      _drawImageInRect(canvas, cached, dst, cornerRadius);
      return;
    }

    // Fallback: emoji flag.
    _drawEmoji(canvas, tile.countryCode, dst, cornerRadius);
  }

  /// Draws a pre-loaded [ui.Image] into [dst] with optional corner rounding.
  static void drawImage(
    Canvas canvas,
    ui.Image image,
    Rect dst, {
    double cornerRadius = 2.0,
  }) {
    _drawImageInRect(canvas, image, dst, cornerRadius);
  }

  static void _drawImageInRect(
      Canvas canvas, ui.Image image, Rect dst, double cornerRadius) {
    canvas.save();
    if (cornerRadius > 0) {
      canvas.clipRRect(RRect.fromRectAndRadius(dst, Radius.circular(cornerRadius)));
    }
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  static void _drawEmoji(
      Canvas canvas, String code, Rect dst, double cornerRadius) {
    final emoji = _flagEmoji(code);
    if (emoji.isEmpty) return;

    canvas.save();
    if (cornerRadius > 0) {
      canvas.clipRRect(
          RRect.fromRectAndRadius(dst, Radius.circular(cornerRadius)));
    }

    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: dst.width * 0.7),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = dst.left + (dst.width - tp.width) / 2;
    final dy = dst.top + (dst.height - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
    canvas.restore();
  }

  static String _flagEmoji(String code) {
    if (code.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
        String.fromCharCode(base + code.codeUnitAt(1) - 65);
  }

  /// Loads a flag SVG into a [ui.Image] at [targetSize] and stores in [cache].
  ///
  /// Returns `null` if the SVG cannot be loaded.
  static Future<ui.Image?> loadSvgToCache(
    String code,
    double targetSize,
    FlagImageCache cache,
  ) async {
    final existing = cache.get(code, targetSize);
    if (existing != null) return existing;

    try {
      final loader = SvgAssetLoader(svgAssetPath(code));
      final pictureInfo = await vg.loadPicture(loader, null);
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);

      final srcSize = pictureInfo.size;
      final scale = targetSize / srcSize.width;
      c.scale(scale, scale);
      c.drawPicture(pictureInfo.picture);
      pictureInfo.picture.dispose();

      final picture = recorder.endRecording();
      final image =
          await picture.toImage(targetSize.round(), targetSize.round());
      picture.dispose();

      cache.put(code, targetSize, image);
      return image;
    } catch (_) {
      return null;
    }
  }
}

// ── Known bundled codes ────────────────────────────────────────────────────────

// Set of lowercase ISO codes for which an SVG is bundled (flag-icons 4x3).
// Trimmed to common travel codes; all others fall back to emoji.
const Set<String> _kBundledCodes = {
  'ac', 'ad', 'ae', 'af', 'ag', 'ai', 'al', 'am', 'ao', 'aq', 'ar', 'as',
  'at', 'au', 'aw', 'ax', 'az', 'ba', 'bb', 'bd', 'be', 'bf', 'bg', 'bh',
  'bi', 'bj', 'bl', 'bm', 'bn', 'bo', 'bq', 'br', 'bs', 'bt', 'bv', 'bw',
  'by', 'bz', 'ca', 'cc', 'cd', 'cf', 'cg', 'ch', 'ci', 'ck', 'cl', 'cm',
  'cn', 'co', 'cp', 'cq', 'cr', 'cu', 'cv', 'cw', 'cx', 'cy', 'cz', 'de',
  'dg', 'dj', 'dk', 'dm', 'do', 'dz', 'ea', 'ec', 'ee', 'eg', 'eh', 'er',
  'es', 'et', 'eu', 'ez', 'fi', 'fj', 'fk', 'fm', 'fo', 'fr', 'fx', 'ga',
  'gb', 'gd', 'ge', 'gf', 'gg', 'gh', 'gi', 'gl', 'gm', 'gn', 'gp', 'gq',
  'gr', 'gs', 'gt', 'gu', 'gw', 'gy', 'hk', 'hm', 'hn', 'hr', 'ht', 'hu',
  'ic', 'id', 'ie', 'il', 'im', 'in', 'io', 'iq', 'ir', 'is', 'it', 'je',
  'jm', 'jo', 'jp', 'ke', 'kg', 'kh', 'ki', 'km', 'kn', 'kp', 'kr', 'kw',
  'ky', 'kz', 'la', 'lb', 'lc', 'li', 'lk', 'lr', 'ls', 'lt', 'lu', 'lv',
  'ly', 'ma', 'mc', 'md', 'me', 'mf', 'mg', 'mh', 'mk', 'ml', 'mm', 'mn',
  'mo', 'mp', 'mq', 'mr', 'ms', 'mt', 'mu', 'mv', 'mw', 'mx', 'my', 'mz',
  'na', 'nc', 'ne', 'nf', 'ng', 'ni', 'nl', 'no', 'np', 'nr', 'nu', 'nz',
  'om', 'pa', 'pe', 'pf', 'pg', 'ph', 'pk', 'pl', 'pm', 'pn', 'pr', 'ps',
  'pt', 'pw', 'py', 'qa', 're', 'ro', 'rs', 'ru', 'rw', 'sa', 'sb', 'sc',
  'sd', 'se', 'sg', 'sh', 'si', 'sj', 'sk', 'sl', 'sm', 'sn', 'so', 'sr',
  'ss', 'st', 'sv', 'sx', 'sy', 'sz', 'ta', 'tc', 'td', 'tf', 'tg', 'th',
  'tj', 'tk', 'tl', 'tm', 'tn', 'to', 'tr', 'tt', 'tv', 'tw', 'tz', 'ua',
  'ug', 'um', 'un', 'us', 'uy', 'uz', 'va', 'vc', 've', 'vg', 'vi', 'vn',
  'vu', 'wf', 'ws', 'xk', 'ye', 'yt', 'za', 'zm', 'zw',
};
