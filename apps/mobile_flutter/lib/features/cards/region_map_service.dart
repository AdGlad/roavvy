import 'dart:collection';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// A region (continent) map: every country's border polygons plus the merged
/// outer outline, all expressed in ONE shared raw frame `[0, w] × [0, h]`.
///
/// The painter applies a single transform to fit this frame into the grid zone,
/// so all countries and the outline stay aligned (M204/M205).
class RegionMap {
  const RegionMap({
    required this.w,
    required this.h,
    required this.countries,
    required this.outline,
  });

  /// Frame width (always 1000.0 in the bundled data).
  final double w;

  /// Frame height.
  final double h;

  /// Per-country border paths keyed by UPPERCASE ISO 3166-1 alpha-2 code.
  /// Every path is in raw frame coordinates (NO fit applied).
  final Map<String, ui.Path> countries;

  /// Merged outer boundary path in the SAME raw frame coordinates.
  final ui.Path outline;
}

/// Loads and caches [RegionMap]s from the bundled continent path assets (M203).
///
/// Assets live at:
///   `assets/continent_paths/{key}_countries.json` — per-country polygons
///   `assets/continent_paths/{key}.json`           — merged outer outline
///
/// Both share one frame `[0, w] × [0, h]`, so a single transform aligns them.
/// `key` ∈ {africa, asia, europe, north_america, oceania, south_america}.
class RegionMapService {
  RegionMapService._();

  static const Set<String> _continentKeys = {
    'africa', 'asia', 'europe', 'north_america', 'oceania', 'south_america',
  };

  // LRU cache keyed by continent key.
  static final LinkedHashMap<String, RegionMap> _cache = LinkedHashMap();
  static const int _maxEntries = 6;

  /// Returns the [RegionMap] for continent [key], or `null` on any failure
  /// (unknown key, missing/malformed asset). Results are cached (LRU).
  static Future<RegionMap?> mapFor(String key) async {
    if (!_continentKeys.contains(key)) return null;

    if (_cache.containsKey(key)) {
      // LRU: promote to end.
      final hit = _cache.remove(key)!;
      _cache[key] = hit;
      return hit;
    }

    final map = await _load(key);
    if (map == null) return null;

    _cache[key] = map;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return map;
  }

  static Future<RegionMap?> _load(String key) async {
    try {
      final countriesRaw = await rootBundle
          .loadString('assets/continent_paths/${key}_countries.json');
      final outlineRaw =
          await rootBundle.loadString('assets/continent_paths/$key.json');

      final cData = json.decode(countriesRaw) as Map<String, dynamic>;
      final oData = json.decode(outlineRaw) as Map<String, dynamic>;

      final w = (cData['w'] as num).toDouble();
      final h = (cData['h'] as num).toDouble();
      if (w <= 0 || h <= 0) return null;

      final rawCountries = cData['countries'] as Map<String, dynamic>;
      final countries = <String, ui.Path>{};
      for (final entry in rawCountries.entries) {
        final path = _pathFromPolys(entry.value as List);
        if (path != null) countries[entry.key.toUpperCase()] = path;
      }
      if (countries.isEmpty) return null;

      final outline = _pathFromPolys(oData['polys'] as List);
      if (outline == null) return null;

      return RegionMap(w: w, h: h, countries: countries, outline: outline);
    } catch (_) {
      return null;
    }
  }

  /// Builds a [ui.Path] from a list of polygons (`[[[x, y], …], …]`) in RAW
  /// frame coordinates. Returns `null` when no valid polygon is present.
  static ui.Path? _pathFromPolys(List rawPolys) {
    final path = ui.Path();
    var any = false;
    for (final poly in rawPolys) {
      final pts = poly as List;
      if (pts.length < 2) continue;
      path.moveTo((pts[0][0] as num).toDouble(), (pts[0][1] as num).toDouble());
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(
            (pts[i][0] as num).toDouble(), (pts[i][1] as num).toDouble());
      }
      path.close();
      any = true;
    }
    return any ? path : null;
  }
}
