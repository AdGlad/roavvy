import 'dart:collection';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

/// Fetches, parses, and caches national animal and plant SVG silhouettes from
/// Firebase Storage, returning them as scaled [ui.Path] objects ready for use
/// as clip masks in [GridFlagsCard].
///
/// Storage paths:
///   `symbols/animals/{CC}/{slug}.svg`  — [GridClipShape.animalSilhouette]
///   `symbols/plants/{CC}/{slug}.svg`   — [GridClipShape.plantSilhouette]
///
/// Animal slugs are looked up from the bundled asset
/// `assets/symbols/animal_slugs.json`. Plant slugs are derived from the
/// country_symbols.json data at build time (first plant entry per country).
///
/// Returned paths are pre-scaled to fit an 800×533 canvas (same convention as
/// [CountryPathService]) so [_clipPathFor] can apply final scaling unchanged.
class AnimalSilhouetteService {
  AnimalSilhouetteService._();

  // LRU path cache keyed by "{type}_{CC}" e.g. "animal_SC", "plant_SC".
  static final LinkedHashMap<String, ui.Path?> _pathCache = LinkedHashMap();
  static const int _maxEntries = 80;

  // Bundled country → {name, slug} mapping loaded once.
  static Map<String, dynamic>? _slugMap;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a [ui.Path] for the national animal of [countryCode], pre-scaled
  /// to fit an 800×533 canvas, or null if unavailable.
  static Future<ui.Path?> pathFor(String countryCode) =>
      _pathForType('animal', countryCode);

  /// Returns a [ui.Path] for the national plant of [countryCode], or null.
  static Future<ui.Path?> plantPathFor(String countryCode) =>
      _pathForType('plant', countryCode);

  static Future<ui.Path?> _pathForType(String type, String countryCode) async {
    final cc = countryCode.toUpperCase();
    final key = '${type}_$cc';

    if (_pathCache.containsKey(key)) {
      final hit = _pathCache.remove(key)!;
      _pathCache[key] = hit;
      return hit;
    }

    final slug = await _slugFor(cc, type);
    if (slug == null) {
      _pathCache[key] = null;
      return null;
    }

    final svgBytes = await _downloadSvg(cc, slug, type);
    if (svgBytes == null) {
      _pathCache[key] = null;
      return null;
    }

    final path = _parseSvg(svgBytes);
    _pathCache[key] = path;
    if (_pathCache.length > _maxEntries) _pathCache.remove(_pathCache.keys.first);
    return path;
  }

  /// Returns the display name of the national animal for [countryCode],
  /// or null if not in the bundled map.
  static Future<String?> animalNameFor(String countryCode) async {
    final cc = countryCode.toUpperCase();
    final map = await _loadSlugMap();
    return (map[cc] as Map<String, dynamic>?)?['name'] as String?;
  }

  /// Returns the display name of the national plant for [countryCode],
  /// or null if not in the bundled map.
  static Future<String?> plantNameFor(String countryCode) async {
    final cc = countryCode.toUpperCase();
    final map = await _loadSlugMap();
    return (map[cc] as Map<String, dynamic>?)?['plant_name'] as String?;
  }

  // ── Asset loading ──────────────────────────────────────────────────────────

  static Future<String?> _slugFor(String cc, String type) async {
    final map = await _loadSlugMap();
    final entry = map[cc] as Map<String, dynamic>?;
    if (entry == null) return null;
    return type == 'plant'
        ? entry['plant_slug'] as String?
        : entry['slug'] as String?;
  }

  static Future<Map<String, dynamic>> _loadSlugMap() async {
    if (_slugMap != null) return _slugMap!;
    try {
      final raw = await rootBundle.loadString('assets/symbols/animal_slugs.json');
      _slugMap = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      _slugMap = {};
    }
    return _slugMap!;
  }

  // ── Firebase Storage download ──────────────────────────────────────────────

  static Future<Uint8List?> _downloadSvg(String cc, String slug, String type) async {
    try {
      final ref = FirebaseStorage.instance.ref('symbols/${type}s/$cc/$slug.svg');
      return await ref.getData(512 * 1024); // 512 KB max
    } catch (_) {
      return null;
    }
  }

  // ── SVG → ui.Path ─────────────────────────────────────────────────────────

  /// Parses all `<path d="...">` elements from [svgBytes] and returns a
  /// combined [ui.Path] scaled to fit an 800×533 canvas, centred.
  ///
  /// Applies any `<g transform="translate(tx,ty) scale(sx,sy)">` found in the
  /// SVG (e.g. potrace's y-flip transform) before the 800×533 normalisation.
  ///
  /// SVGs are normalised at upload time (black fill, no stroke) so paths
  /// always represent solid silhouette shapes suitable for clip masks.
  ///
  /// Falls back to null on parse failure or empty result.
  static ui.Path? _parseSvg(Uint8List svgBytes) {
    try {
      final svgString = utf8.decode(svgBytes);

      // Extract all d="..." attribute values.
      final dPattern = RegExp(r'\bd="([^"]+)"');
      final matches = dPattern.allMatches(svgString);
      if (matches.isEmpty) return null;

      final combined = ui.Path();
      for (final m in matches) {
        final d = m.group(1)!.trim();
        if (d.isEmpty) continue;
        try {
          // Use only the dominant (largest bounding area) sub-path from each
          // <path> element, discarding inner "hole" sub-paths that make outline
          // SVGs render as hollow rings instead of filled silhouettes.
          combined.addPath(_dominantSubPath(d), ui.Offset.zero);
        } catch (_) {
          // Skip malformed path segments.
        }
      }

      // Apply SVG group transform if present (e.g. potrace outputs
      // "translate(tx,ty) scale(sx,sy)" to flip Y from math to screen coords).
      final groupXform = _parseGroupTransform(svgString);
      final preTransformed =
          groupXform != null ? combined.transform(groupXform) : combined;

      // Scale to fit 800×533, centred (matches CountryPathService convention).
      final bounds = preTransformed.getBounds();
      if (bounds.isEmpty || bounds.width <= 0 || bounds.height <= 0) return null;

      const targetW = 800.0;
      const targetH = 533.0;
      final scale = min(targetW / bounds.width, targetH / bounds.height);
      final dx = (targetW - bounds.width * scale) / 2 - bounds.left * scale;
      final dy = (targetH - bounds.height * scale) / 2 - bounds.top * scale;

      final matrix = Float64List(16)
        ..[0] = scale
        ..[5] = scale
        ..[10] = 1.0
        ..[15] = 1.0
        ..[12] = dx
        ..[13] = dy;

      return preTransformed.transform(matrix);
    } catch (_) {
      return null;
    }
  }

  /// Returns the sub-path with the largest bounding-box area from [d].
  ///
  /// A potrace SVG `d` attribute may contain multiple `M…Z` sub-paths: the
  /// outer boundary of the shape followed by inner "hole" boundaries.  By
  /// keeping only the largest sub-path we discard holes and produce a solid
  /// filled shape.  If there is only one sub-path it is returned unchanged.
  static ui.Path _dominantSubPath(String d) {
    // Split on every uppercase M that starts a new sub-path.
    // (Potrace uses uppercase M for sub-path starts; lowercase m is relative
    //  move within a path and rarely starts a new major contour.)
    final rawSegments = d.split(RegExp(r'(?=M)'));

    if (rawSegments.length <= 1) {
      return parseSvgPathData(d);
    }

    ui.Path? best;
    double bestArea = -1;
    for (final seg in rawSegments) {
      final s = seg.trim();
      if (s.isEmpty) continue;
      try {
        final p = parseSvgPathData(s);
        final b = p.getBounds();
        final area = b.width * b.height;
        if (area > bestArea) {
          bestArea = area;
          best = p;
        }
      } catch (_) {}
    }
    return best ?? parseSvgPathData(d);
  }

  /// Extracts a combined affine matrix from a potrace-style SVG group transform
  /// of the form `translate(tx,ty) scale(sx,sy)`.
  ///
  /// Returns null if no such transform is found or parsing fails.
  static Float64List? _parseGroupTransform(String svgString) {
    try {
      final pattern = RegExp(
        r'translate\(\s*([\d.eE+-]+)\s*,\s*([\d.eE+-]+)\s*\)'
        r'\s*scale\(\s*([\d.eE+-]+)\s*,\s*([\d.eE+-]+)\s*\)',
      );
      final m = pattern.firstMatch(svgString);
      if (m == null) return null;
      final tx = double.parse(m.group(1)!);
      final ty = double.parse(m.group(2)!);
      final sx = double.parse(m.group(3)!);
      final sy = double.parse(m.group(4)!);
      // Column-major 4×4: scale first, then translate.
      return Float64List(16)
        ..[0] = sx
        ..[5] = sy
        ..[10] = 1.0
        ..[15] = 1.0
        ..[12] = tx
        ..[13] = ty;
    } catch (_) {
      return null;
    }
  }
}
