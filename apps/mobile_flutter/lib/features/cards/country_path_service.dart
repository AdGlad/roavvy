import 'dart:collection';
import 'dart:convert';
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
      for (final code in codes) pathFor(code, targetSize).catchError((_) => null),
    ]);
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  static String _cacheKey(String code, ui.Size size) =>
      '${code}_${size.width.round()}x${size.height.round()}';

  // ── Asset loading ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _loadJson(String code) async {
    // Continent keys use a different directory.
    final isContinent = _continentKeys.contains(code);
    final assetPath = isContinent
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
    'africa', 'asia', 'europe', 'north_america', 'oceania', 'south_america',
  };

  // ── Path construction ──────────────────────────────────────────────────────

  /// Builds a [ui.Path] from the parsed JSON, scaled to fit [targetSize].
  ///
  /// The normalised coordinate space is 1000 units wide × `h` units tall.
  /// The path is scaled (fit-inside, aspect-ratio preserved) and centred
  /// within [targetSize].
  static ui.Path? _buildPath(Map<String, dynamic> data, ui.Size targetSize) {
    try {
      final normW = (data['w'] as num).toDouble();
      final normH = (data['h'] as num).toDouble();
      final polys = data['polys'] as List;

      if (normW <= 0 || normH <= 0 || polys.isEmpty) return null;

      // Compute fit-inside scale and centering offsets.
      final scaleX = targetSize.width / normW;
      final scaleY = targetSize.height / normH;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final dx = (targetSize.width - normW * scale) / 2;
      final dy = (targetSize.height - normH * scale) / 2;

      final path = ui.Path();
      for (final poly in polys) {
        final pts = poly as List;
        if (pts.isEmpty) continue;
        final first = pts[0] as List;
        path.moveTo(
          (first[0] as num).toDouble() * scale + dx,
          (first[1] as num).toDouble() * scale + dy,
        );
        for (int i = 1; i < pts.length; i++) {
          final pt = pts[i] as List;
          path.lineTo(
            (pt[0] as num).toDouble() * scale + dx,
            (pt[1] as num).toDouble() * scale + dy,
          );
        }
        path.close();
      }
      return path;
    } catch (_) {
      return null;
    }
  }
}
