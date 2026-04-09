import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';

// ── HeartFlagOrder ─────────────────────────────────────────────────────────────

/// Ordering strategy for flag tiles in the heart layout.
enum HeartFlagOrder {
  /// Deterministic shuffle seeded by country-code set hash (default).
  randomized,

  /// Earliest trip date ascending; falls back to alphabetical for ties.
  chronological,

  /// Country name A → Z.
  alphabetical,

  /// Grouped by continent, then by longitude (West → East within continent).
  geographic,
}

// ── HeartTilePosition ─────────────────────────────────────────────────────────

/// A single flag tile's position and assigned country code.
class HeartTilePosition {
  const HeartTilePosition({required this.rect, required this.countryCode});

  /// Position in canvas-space pixels.
  final Rect rect;

  /// ISO 3166-1 alpha-2 country code.
  final String countryCode;
}

// ── MaskCalculator ────────────────────────────────────────────────────────────

/// Evaluates the parametric heart equation and generates a clipping path.
///
/// Heart boundary: `(x² + y² − 1)³ − x²y³ ≤ 0`
/// where x and y are normalised to [−1.4, 1.4] over the canvas square.
class MaskCalculator {
  MaskCalculator._();

  // Normalise canvas coordinate to [-1.4, 1.4].
  static double _nx(double px, double sideLen) =>
      (px / sideLen - 0.5) * 2.8;

  static double _ny(double py, double sideLen) =>
      // y axis is inverted in canvas coordinates; heart "top" is at small y.
      (0.5 - py / sideLen) * 2.8;

  /// Returns `true` when the normalised point (nx, ny) is inside the heart.
  static bool isInsideHeart(double nx, double ny) {
    final xSq = nx * nx;
    final ySq = ny * ny;
    final inner = xSq + ySq - 1;
    return inner * inner * inner - xSq * ySq * ySq <= 0;
  }

  /// Estimates the fraction of [tile] (in canvas pixels) covered by the heart.
  ///
  /// Uses a 5-point sample (4 corners + centre). If ≥3/5 are inside the heart
  /// the tile passes immediately (fraction ≥0.60). Otherwise a denser 9-point
  /// test is run to check the 66% threshold more accurately.
  static double coverageFraction(Rect tile, double sideLen) {
    final pts5 = _samplePoints5(tile, sideLen);
    final inside5 = pts5.where((inside) => inside).length;

    if (inside5 >= 3) return inside5 / 5.0;

    // Dense 9-point test for edge tiles.
    final pts9 = _samplePoints9(tile, sideLen);
    return pts9.where((inside) => inside).length / 9.0;
  }

  static List<bool> _samplePoints5(Rect tile, double sideLen) {
    final cx = tile.center.dx;
    final cy = tile.center.dy;
    return [
      isInsideHeart(_nx(tile.left, sideLen), _ny(tile.top, sideLen)),
      isInsideHeart(_nx(tile.right, sideLen), _ny(tile.top, sideLen)),
      isInsideHeart(_nx(tile.left, sideLen), _ny(tile.bottom, sideLen)),
      isInsideHeart(_nx(tile.right, sideLen), _ny(tile.bottom, sideLen)),
      isInsideHeart(_nx(cx, sideLen), _ny(cy, sideLen)),
    ];
  }

  static List<bool> _samplePoints9(Rect tile, double sideLen) {
    final pts = <bool>[];
    for (final fx in [0.0, 0.5, 1.0]) {
      for (final fy in [0.0, 0.5, 1.0]) {
        final px = tile.left + tile.width * fx;
        final py = tile.top + tile.height * fy;
        pts.add(isInsideHeart(_nx(px, sideLen), _ny(py, sideLen)));
      }
    }
    return pts;
  }

  /// Returns a [ui.Path] tracing the heart boundary with [numPoints] vertices.
  ///
  /// The path is suitable for `Canvas.clipPath()`.
  static ui.Path heartPath(Size size, {int numPoints = 120}) {
    // Heart is drawn over a square whose side = min(width, height).
    final side = math.min(size.width, size.height).toDouble();
    final offsetX = (size.width - side) / 2;
    final offsetY = (size.height - side) / 2;

    final path = ui.Path();
    bool started = false;

    // Parametric sweep: t in [0, 2π] → polar coordinates on the heart.
    for (int i = 0; i <= numPoints; i++) {
      final t = 2 * math.pi * i / numPoints;
      // Standard parametric heart:
      //   x = 16 sin³(t)
      //   y = 13cos(t) − 5cos(2t) − 2cos(3t) − cos(4t)
      final hx = 16 * math.pow(math.sin(t), 3).toDouble();
      final hy = -(13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t));

      // Map from parametric range (~[-17,17] x and ~[-10,13] y) to [0,side].
      final px = offsetX + (hx / 17.0 + 1.0) * side / 2.0;
      final py = offsetY + (hy / 13.0 + 1.0) * side / 2.0;

      if (!started) {
        path.moveTo(px, py);
        started = true;
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }
}

// ── HeartLayoutEngine ─────────────────────────────────────────────────────────

/// Lays out flag tiles inside a heart-shaped mask.
///
/// See ADR-098 for algorithm details and density bands.
class HeartLayoutEngine {
  HeartLayoutEngine._();

  // Coverage threshold: tiles below this fraction are rejected.
  static const double _kCoverageThreshold = 0.66;

  // Density bands: [maxFlags, tileSize at 1024px reference].
  static const List<(int, int)> _kDensityBands = [
    (12, 180),
    (40, 110),
    (120, 72),
    (200, 52),
    (10000, 40),
  ];

  /// Returns positioned flag tiles for [codes] within a [canvasSize] canvas.
  ///
  /// The heart is drawn over a square equal to `min(canvasSize.width,
  /// canvasSize.height)`. Tile positions are in canvas-space pixels.
  static List<HeartTilePosition> layout(
    List<String> codes,
    Size canvasSize, {
    HeartFlagOrder order = HeartFlagOrder.randomized,
    List<TripRecord> trips = const [],
    int maxReruns = 2,
  }) {
    if (codes.isEmpty) return const [];

    final side = math.min(canvasSize.width, canvasSize.height);
    final offsetX = (canvasSize.width - side) / 2;
    final offsetY = (canvasSize.height - side) / 2;

    // Sort codes by the chosen ordering strategy.
    final sorted = sortCodes(codes, order, trips);

    List<HeartTilePosition>? result;
    var bandIndex = _bandIndexForCount(sorted.length);

    for (var attempt = 0; attempt <= maxReruns; attempt++) {
      final band = _kDensityBands[bandIndex.clamp(0, _kDensityBands.length - 1)];
      final tileSize = (band.$2 * side / 1024).floorToDouble();
      if (tileSize <= 0) break;

      final candidates =
          _generateCandidates(side, tileSize, offsetX, offsetY);

      if (candidates.length >= sorted.length) {
        // Assign flags to candidates; discard surplus outer tiles if over.
        final tiles = candidates.take(sorted.length).toList();
        result = [
          for (var i = 0; i < tiles.length; i++)
            HeartTilePosition(rect: tiles[i], countryCode: sorted[i]),
        ];
        break;
      }

      // Not enough valid tiles — increase density (go to next tighter band).
      bandIndex++;
      if (bandIndex >= _kDensityBands.length) {
        // Use all candidates, filling as many flags as possible.
        result = [
          for (var i = 0; i < candidates.length; i++)
            HeartTilePosition(
                rect: candidates[i], countryCode: sorted[i % sorted.length]),
        ];
        break;
      }
    }

    return result ?? const [];
  }

  static int _bandIndexForCount(int count) {
    for (var i = 0; i < _kDensityBands.length; i++) {
      if (count <= _kDensityBands[i].$1) return i;
    }
    return _kDensityBands.length - 1;
  }

  /// Generates valid tile Rects ordered from the heart centre outward.
  static List<Rect> _generateCandidates(
      double side, double tileSize, double offsetX, double offsetY) {
    final candidates = <(Rect, double)>[];
    final center = Offset(offsetX + side / 2, offsetY + side / 2);

    for (var row = 0.0; row + tileSize <= side; row += tileSize) {
      for (var col = 0.0; col + tileSize <= side; col += tileSize) {
        final rect = Rect.fromLTWH(
            offsetX + col, offsetY + row, tileSize, tileSize);
        final coverage = MaskCalculator.coverageFraction(rect, side);
        if (coverage >= _kCoverageThreshold) {
          // Distance from heart centre for ordering (closest first).
          final dx = rect.center.dx - center.dx;
          final dy = rect.center.dy - center.dy;
          candidates.add((rect, dx * dx + dy * dy));
        }
      }
    }

    // Sort by distance to centre ascending (densest in middle first).
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    return candidates.map((e) => e.$1).toList();
  }

  /// Sorts [codes] according to [order].
  ///
  /// Exposed as a public static so [CardEditorScreen] can apply the same
  /// ordering to the Grid template (ADR-119).
  static List<String> sortCodes(
      List<String> codes, HeartFlagOrder order, List<TripRecord> trips) {
    final sorted = List<String>.from(codes);

    switch (order) {
      case HeartFlagOrder.randomized:
        final seed = codes.join().hashCode;
        sorted.shuffle(math.Random(seed));

      case HeartFlagOrder.alphabetical:
        sorted.sort((a, b) {
          final nameA = kCountryNames[a] ?? a;
          final nameB = kCountryNames[b] ?? b;
          return nameA.compareTo(nameB);
        });

      case HeartFlagOrder.chronological:
        final earliestByCode = <String, DateTime>{};
        for (final trip in trips) {
          final existing = earliestByCode[trip.countryCode];
          if (existing == null || trip.startedOn.isBefore(existing)) {
            earliestByCode[trip.countryCode] = trip.startedOn;
          }
        }
        sorted.sort((a, b) {
          final dateA = earliestByCode[a];
          final dateB = earliestByCode[b];
          if (dateA == null && dateB == null) {
            return (kCountryNames[a] ?? a).compareTo(kCountryNames[b] ?? b);
          }
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateA.compareTo(dateB);
        });

      case HeartFlagOrder.geographic:
        // Sort by continent bucket index, then by approximate longitude.
        sorted.sort((a, b) {
          final contA = _continentOrder(a);
          final contB = _continentOrder(b);
          if (contA != contB) return contA.compareTo(contB);
          return (_approxLongitude(a)).compareTo(_approxLongitude(b));
        });
    }

    return sorted;
  }

  // Continent sort order (West → East, loosely).
  static int _continentOrder(String code) {
    const order = {
      'NA': 0, 'SA': 1, 'EU': 2, 'AF': 3, 'AS': 4, 'OC': 5,
    };
    return order[kCountryContinent[code]] ?? 6;
  }

  // Very rough longitude lookup using continent + sub-region heuristics.
  static double _approxLongitude(String code) {
    // Rough country centroids for geographic ordering — simplified but
    // sufficient for visual grouping. Extended list covers common travel codes.
    const centroids = <String, double>{
      'CA': -96, 'US': -98, 'MX': -102, 'GT': -90, 'BZ': -88, 'HN': -87,
      'SV': -89, 'NI': -85, 'CR': -84, 'PA': -80, 'CU': -77, 'JM': -77,
      'HT': -73, 'DO': -70, 'PR': -67, 'TT': -61,
      'CO': -74, 'VE': -66, 'GY': -59, 'SR': -56, 'BR': -51, 'EC': -78,
      'PE': -76, 'BO': -64, 'PY': -58, 'UY': -56, 'AR': -64, 'CL': -71,
      'IS': -18, 'PT': -8, 'GB': -2, 'IE': -8, 'ES': -4, 'FR': 2,
      'NL': 5, 'BE': 4, 'LU': 6, 'DE': 10, 'DK': 10, 'NO': 10,
      'SE': 18, 'FI': 26, 'CH': 8, 'AT': 14, 'IT': 12, 'MT': 14,
      'PL': 20, 'CZ': 15, 'SK': 18, 'HU': 19, 'SI': 15, 'HR': 16,
      'BA': 17, 'RS': 21, 'ME': 19, 'AL': 20, 'MK': 22, 'GR': 22,
      'BG': 25, 'RO': 25, 'MD': 29, 'UA': 32, 'BY': 28, 'LT': 24,
      'LV': 25, 'EE': 25, 'RU': 60, 'TR': 36,
      'MA': -6, 'DZ': 3, 'TN': 9, 'LY': 17, 'EG': 30, 'SD': 30,
      'ET': 40, 'SO': 46, 'KE': 38, 'TZ': 35, 'MZ': 35, 'ZA': 25,
      'NG': 8, 'GH': -1, 'SN': -14, 'ML': -2, 'CI': -6, 'CM': 12,
      'CD': 25, 'AO': 18, 'ZM': 28, 'ZW': 30, 'BW': 24, 'NA': 18,
      'GE': 44, 'AM': 45, 'AZ': 47, 'IR': 53, 'IQ': 44, 'SA': 45,
      'AE': 54, 'OM': 57, 'YE': 48, 'JO': 37, 'IL': 35, 'LB': 35,
      'SY': 38, 'KZ': 67, 'UZ': 63, 'TM': 59, 'AF': 67, 'PK': 70,
      'IN': 78, 'NP': 84, 'BD': 90, 'LK': 81, 'MV': 73,
      'CN': 104, 'MN': 103, 'KP': 127, 'KR': 128, 'JP': 138,
      'MM': 96, 'TH': 101, 'LA': 103, 'VN': 106, 'KH': 105,
      'PH': 122, 'MY': 112, 'SG': 104, 'ID': 120, 'TL': 126,
      'AU': 133, 'NZ': 172, 'PG': 144, 'FJ': 178,
    };
    return centroids[code] ?? 0;
  }
}
