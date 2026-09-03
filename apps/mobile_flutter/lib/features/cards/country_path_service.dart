import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Loads, scales, and caches Flutter [ui.Path] objects from bundled country /
/// continent outline JSON assets (M171).
///
/// Assets live at:
///   `assets/country_paths/{iso2}.json`   — ISO 3166-1 alpha-2 lowercase
///   `assets/continent_paths/{key}.json`  — africa, asia, europe, …
///
/// JSON format:
/// ```json
/// {"w": 1000, "h": <height>, "polys": [[[x, y], ...], ...]}
/// ```
/// Coordinates are normalised to a 1000-unit-wide canvas preserving aspect ratio.
class CountryPathService {
  CountryPathService._();

  // LRU cache keyed by "code_WxH" (e.g. "jp_400x300").
  static final LinkedHashMap<String, ui.Path> _cache = LinkedHashMap();
  static const int _maxEntries = 40;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a scaled [ui.Path] for [code] fitted inside [targetSize].
  ///
  /// [code] is an ISO 3166-1 alpha-2 country code (lowercase) or a continent
  /// key (e.g. `'europe'`). Returns `null` on any load or parse failure.
  static Future<ui.Path?> pathFor(String code, ui.Size targetSize) async {
    final key = _cacheKey(code, targetSize);
    if (_cache.containsKey(key)) {
      // LRU: promote to end.
      final hit = _cache.remove(key)!;
      _cache[key] = hit;
      return hit;
    }

    final raw = await _loadJson(code);
    if (raw == null) return null;

    final path = _buildPath(raw, targetSize);
    if (path == null) return null;

    _cache[key] = path;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return path;
  }

  /// Warms the cache for [codes] before navigation so paths are ready on first
  /// paint. Errors are silently swallowed — callers fall back to circle clip.
  static Future<void> preload(List<String> codes, ui.Size targetSize) async {
    await Future.wait([
      for (final code in codes)
        pathFor(code, targetSize).catchError((_) => null),
    ]);
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  static String _cacheKey(String code, ui.Size size) =>
      '${code}_${size.width.round()}x${size.height.round()}';

  // ── Asset loading ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _loadJson(String code) async {
    // Continent keys use a different directory.
    final isContinent = _continentKeys.contains(code);
    final assetPath =
        isContinent
            ? 'assets/continent_paths/$code.json'
            : 'assets/country_paths/$code.json';

    try {
      final raw = await rootBundle.loadString(assetPath);
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static const Set<String> _continentKeys = {
    'africa',
    'asia',
    'europe',
    'north_america',
    'oceania',
    'south_america',
  };

  // ── Path construction ──────────────────────────────────────────────────────

  /// Builds a [ui.Path] from the parsed JSON, scaled to fit [targetSize].
  ///
  /// The normalised coordinate space is 1000 units wide × `h` units tall.
  /// The path is scaled (fit-inside, aspect-ratio preserved) and centred
  /// within [targetSize].
  static ui.Path? _buildPath(Map<String, dynamic> data, ui.Size targetSize) {
    try {
      final rawPolys = data['polys'] as List;
      if (rawPolys.isEmpty) return null;

      // Parse to lists of (x, y) points.
      final polys = <List<List<double>>>[];
      for (final poly in rawPolys) {
        final pts = poly as List;
        if (pts.isEmpty) continue;
        polys.add([
          for (final pt in pts)
            [(pt[0] as num).toDouble(), (pt[1] as num).toDouble()],
        ]);
      }
      if (polys.isEmpty) return null;

      // Drop far-flung outlier polygons (tiny distant islands / antimeridian
      // wrap) so the MAIN landmass fills the target and getBounds() is tight —
      // otherwise a continent renders as a small, skewed sliver (the country
      // files have no outliers, so they are unaffected).
      final kept = _mainlandPolys(polys);

      // Fit the kept (de-outliered) bounds to the target, aspect preserved.
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final poly in kept) {
        for (final p in poly) {
          if (p[0] < minX) minX = p[0];
          if (p[0] > maxX) maxX = p[0];
          if (p[1] < minY) minY = p[1];
          if (p[1] > maxY) maxY = p[1];
        }
      }
      final w = maxX - minX, h = maxY - minY;
      if (w <= 0 || h <= 0) return null;
      final scaleX = targetSize.width / w;
      final scaleY = targetSize.height / h;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final dx = (targetSize.width - w * scale) / 2 - minX * scale;
      final dy = (targetSize.height - h * scale) / 2 - minY * scale;

      final path = ui.Path();
      for (final poly in kept) {
        path.moveTo(poly[0][0] * scale + dx, poly[0][1] * scale + dy);
        for (int i = 1; i < poly.length; i++) {
          path.lineTo(poly[i][0] * scale + dx, poly[i][1] * scale + dy);
        }
        path.close();
      }
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Filters out far-flung outlier polygons using an area-weighted centroid and
  /// spread. A polygon is kept when it is a meaningful share of the total area
  /// (a real landmass) OR sits within [_outlierSd]× the area-weighted spread of
  /// the mass — so tiny distant specks and antimeridian-wrapped fragments are
  /// removed while every significant landmass is preserved. A single-polygon
  /// shape (e.g. a country outline) is always returned unchanged.
  static List<List<List<double>>> _mainlandPolys(
    List<List<List<double>>> polys,
  ) {
    if (polys.length <= 1) return polys;

    double areaOf(List<List<double>> p) {
      var a = 0.0;
      for (var i = 0; i < p.length; i++) {
        final j = (i + 1) % p.length;
        a += p[i][0] * p[j][1] - p[j][0] * p[i][1];
      }
      return a.abs() / 2;
    }

    List<double> centroidOf(List<List<double>> p) {
      var sx = 0.0, sy = 0.0;
      for (final pt in p) {
        sx += pt[0];
        sy += pt[1];
      }
      return [sx / p.length, sy / p.length];
    }

    final areas = polys.map(areaOf).toList();
    final total = areas.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return polys;

    var cx = 0.0, cy = 0.0;
    final centroids = polys.map(centroidOf).toList();
    for (var i = 0; i < polys.length; i++) {
      cx += centroids[i][0] * areas[i];
      cy += centroids[i][1] * areas[i];
    }
    cx /= total;
    cy /= total;

    var variance = 0.0;
    for (var i = 0; i < polys.length; i++) {
      final ddx = centroids[i][0] - cx, ddy = centroids[i][1] - cy;
      variance += areas[i] * (ddx * ddx + ddy * ddy);
    }
    final sd = math.sqrt(variance / total);

    final kept = <List<List<double>>>[];
    for (var i = 0; i < polys.length; i++) {
      final dist = math.sqrt(
        math.pow(centroids[i][0] - cx, 2) + math.pow(centroids[i][1] - cy, 2),
      );
      // Keep real landmasses (≥1% of area) OR anything within the mass spread.
      if (areas[i] >= 0.01 * total || dist <= _outlierSd * sd) {
        kept.add(polys[i]);
      }
    }
    return kept.isEmpty ? polys : kept;
  }

  static const double _outlierSd = 2.5;
}
