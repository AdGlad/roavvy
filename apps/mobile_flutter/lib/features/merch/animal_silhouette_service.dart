import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:path_provider/path_provider.dart';

import 'bundled_silhouette_manifest.dart';

/// One selectable option within a category — e.g. one of several candidate
/// animals for a country. [slug] identifies the Storage object; [name] is
/// what's shown to the user (in [FlagShapeCustomiseScreen]'s shape carousel).
class SilhouetteOption {
  const SilhouetteOption({required this.name, required this.slug});
  final String name;
  final String slug;
}

/// Fetches, parses, and caches national symbol SVG silhouettes from Firebase
/// Storage, returning them as scaled [ui.Path] objects ready for use as clip
/// masks in [GridFlagsCard].
///
/// Storage paths:
///   `symbols/animals/{CC}/{slug}.svg`    — category `animal`
///   `symbols/plants/{CC}/{slug}.svg`     — category `plant`
///   `symbols/landmarks/{CC}/{slug}.svg`  — category `landmark`
///
/// A country can have multiple options per category (e.g. two candidate
/// animals); [FlagShapeCustomiseScreen] lets the user pick among them, one
/// carousel page per option. All options are looked up from the bundled
/// asset `assets/symbols/animal_slugs.json`, keyed by country code, then by
/// category, each a list of `{name, slug}`.
///
/// A specific choice is threaded through the rest of the rendering pipeline
/// as a composite `clipCode` string (`"CC|slug"`, see [encodeClipCode]) so
/// the existing single-String `clipCode` field on [GridClipShape] call sites
/// didn't need to grow a second parameter everywhere.
///
/// Three-tier cache, cheapest first:
///   1. In-memory LRU of parsed [ui.Path] objects (this session only).
///   2. On-disk raw SVG bytes in the app's Documents directory (persists
///      across launches — mirrors the pattern in [LandmarkImageService],
///      and is what keeps this feature usable offline per ADR / hard rule 4
///      in `apps/mobile_flutter/CLAUDE.md`). Revalidated at most once per
///      session (gated by tier 1, so this costs one metadata-only request
///      per country/category/slug, not per access): if Storage's object was
///      updated after the cached file's mtime, the disk cache is refreshed.
///      Any failure of that check (offline, timeout, deleted object) is
///      treated as "not stale" so the existing cache is trusted — this must
///      never block offline usability.
///   3. Firebase Storage download — reached on a cold cache miss or a stale
///      disk cache.
///
/// Returned paths are pre-scaled to fit an 800×533 canvas (same convention as
/// [CountryPathService]) so [_clipPathFor] can apply final scaling unchanged.
class AnimalSilhouetteService {
  AnimalSilhouetteService._();

  /// Separator between country code and slug in a composite clipCode.
  /// Country codes are 2 uppercase letters and slugs are snake_case, so this
  /// can't collide with either half.
  static const String kClipCodeSeparator = '|';

  // LRU path cache keyed by "{category}_{cc}_{slug}".
  static final LinkedHashMap<String, ui.Path?> _pathCache = LinkedHashMap();
  static const int _maxEntries = 80;

  // Bundled country → {category: [{name, slug}]} mapping loaded once.
  static Map<String, dynamic>? _slugMap;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns every available option for [category] ('animal', 'plant', or
  /// 'landmark') in [countryCode], in the order stored in the JSON. Empty
  /// (never null) if the country or category has no entries.
  static Future<List<SilhouetteOption>> optionsFor(
    String countryCode,
    String category,
  ) async {
    final cc = countryCode.toUpperCase();
    final map = await _loadSlugMap();
    final entry = map[cc] as Map<String, dynamic>?;
    final list = entry?[category] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(
          (e) => SilhouetteOption(
            name: e['name'] as String? ?? '',
            slug: e['slug'] as String? ?? '',
          ),
        )
        .where((o) => o.slug.isNotEmpty)
        .toList();
  }

  /// Encodes [countryCode] + [slug] into the composite string threaded
  /// through [GridClipShape]'s `clipCode` field.
  static String encodeClipCode(String countryCode, String slug) =>
      '${countryCode.toUpperCase()}$kClipCodeSeparator$slug';

  /// Decodes a composite clipCode back into (countryCode, slug), or null if
  /// it isn't in the `CC|slug` form (e.g. a plain country code from an
  /// unrelated clip shape like countryOutline).
  static (String, String)? decodeClipCode(String clipCode) {
    final i = clipCode.indexOf(kClipCodeSeparator);
    if (i <= 0 || i == clipCode.length - 1) return null;
    return (clipCode.substring(0, i), clipCode.substring(i + 1));
  }

  /// The encoded clipCode for the first available option for [category] in
  /// [countryCode], or null if there are none. For automated preview
  /// generators (e.g. the Shop's "Best Match" thumbnail) that need a
  /// reasonable default rather than the interactive picker in
  /// [FlagShapeCustomiseScreen].
  static Future<String?> defaultClipCodeFor(
    String countryCode,
    String category,
  ) async {
    final options = await optionsFor(countryCode, category);
    if (options.isEmpty) return null;
    return encodeClipCode(countryCode, options.first.slug);
  }

  /// Returns a [ui.Path] for the option encoded in [clipCode] (see
  /// [encodeClipCode]) within [category], pre-scaled to fit an 800×533
  /// canvas, or null if unavailable or [clipCode] can't be decoded.
  static Future<ui.Path?> pathForClipCode(
    String category,
    String clipCode,
  ) async {
    final decoded = decodeClipCode(clipCode);
    if (decoded == null) return null;
    final (cc, slug) = decoded;
    return _pathForSlug(category, cc.toUpperCase(), slug);
  }

  static Future<ui.Path?> _pathForSlug(
    String category,
    String cc,
    String slug,
  ) async {
    final key = '${category}_${cc}_$slug';

    if (_pathCache.containsKey(key)) {
      final hit = _pathCache.remove(key)!;
      _pathCache[key] = hit;
      return hit;
    }

    // Offline-first: if this (cc, slug) is a bundled silhouette, clip straight
    // from the bundled asset — no network, deterministic. The bundled file is
    // category-agnostic (assets/silhouettes/{cc}_{slug}.svg).
    if (kBundledSilhouetteSlugs[cc] == slug) {
      try {
        final data = await rootBundle
            .load('assets/silhouettes/${cc.toLowerCase()}_$slug.svg');
        final path = _parseSvg(data.buffer.asUint8List());
        _pathCache[key] = path;
        if (_pathCache.length > _maxEntries) {
          _pathCache.remove(_pathCache.keys.first);
        }
        return path;
      } catch (_) {
        // Fall through to disk/Storage on any bundled-load failure.
      }
    }

    Uint8List? svgBytes = await _readDiskCache(category, cc, slug);
    if (svgBytes == null) {
      svgBytes = await _downloadAndCache(cc, slug, category);
    } else if (await _isRemoteNewer(category, cc, slug)) {
      // Cached copy is stale relative to Storage; best-effort refresh. Keep
      // the existing bytes as a fallback if the re-download itself fails.
      svgBytes = await _downloadAndCache(cc, slug, category) ?? svgBytes;
    }
    if (svgBytes == null) {
      _pathCache[key] = null;
      return null;
    }

    final path = _parseSvg(svgBytes);
    _pathCache[key] = path;
    if (_pathCache.length > _maxEntries) _pathCache.remove(_pathCache.keys.first);
    return path;
  }

  static Future<Uint8List?> _downloadAndCache(
    String cc,
    String slug,
    String category,
  ) async {
    final bytes = await _downloadSvg(cc, slug, category);
    if (bytes != null) await _writeDiskCache(category, cc, slug, bytes);
    return bytes;
  }

  // ── Asset loading ──────────────────────────────────────────────────────────

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

  // ── Disk cache ─────────────────────────────────────────────────────────────
  //
  // Raw SVG bytes are cached under the app's Documents directory so a
  // silhouette downloaded once is available offline on every later launch,
  // without re-hitting Firebase Storage (bandwidth + egress cost).

  static Future<File> _diskCacheFile(String category, String cc, String slug) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/symbols_${category}_${cc.toLowerCase()}_$slug.svg');
  }

  static Future<Uint8List?> _readDiskCache(
    String category,
    String cc,
    String slug,
  ) async {
    try {
      final file = await _diskCacheFile(category, cc, slug);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }

  /// Returns true if the Storage object for this silhouette was modified
  /// after the cached file's on-disk mtime. Only a metadata request (no SVG
  /// bytes transferred). Best-effort: offline, a missing object, or a slow
  /// connection all resolve to false so the existing cache keeps serving —
  /// this check must never block or degrade offline usability.
  static Future<bool> _isRemoteNewer(String category, String cc, String slug) async {
    try {
      final file = await _diskCacheFile(category, cc, slug);
      final localModified = await file.lastModified();
      final ref = FirebaseStorage.instance.ref('symbols/${category}s/$cc/$slug.svg');
      final remoteUpdated = (await ref
              .getMetadata()
              .timeout(const Duration(seconds: 3)))
          .updated;
      if (remoteUpdated == null) return false;
      return remoteUpdated.isAfter(localModified);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _writeDiskCache(
    String category,
    String cc,
    String slug,
    Uint8List bytes,
  ) async {
    try {
      final file = await _diskCacheFile(category, cc, slug);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  // ── Firebase Storage download ──────────────────────────────────────────────

  static Future<Uint8List?> _downloadSvg(String cc, String slug, String category) async {
    try {
      final ref = FirebaseStorage.instance.ref('symbols/${category}s/$cc/$slug.svg');
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
