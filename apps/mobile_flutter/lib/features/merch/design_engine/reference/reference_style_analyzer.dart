import 'dart:math' as math;
import 'dart:typed_data';

import '../procedural/design_dna.dart' show DesignPrinciple;

/// Version of the host analyzer. Bump when the algorithm changes so re-analysed
/// records are comparable.
const String kReferenceAnalyzerVersion = '0.1.0';

/// Objective, machine-computed features of one reference image. Only the
/// *measurable* axes are produced here (colour, focal concentration, contrast,
/// density); subjective calls (verdict, template feel, tags) stay human. These
/// map onto the same abstract [DesignPrinciple] axes the engine reasons about,
/// so references can seed the Roavvy Design DNA.
class ReferenceFeatures {
  const ReferenceFeatures({
    required this.dominantColors,
    required this.focalConcentration,
    required this.visualDensityHint,
    required this.colourfulness,
    required this.contrast,
    required this.aspectRatio,
  });

  /// Up to 4 representative colours as `#RRGGBB`, most-frequent first.
  final List<String> dominantColors;

  /// Share of saliency in the busiest ~10% of the frame, 0..1 (higher ⇒ a
  /// stronger single focal point).
  final double focalConcentration;

  /// Fraction of the frame that is visually "busy", 0..1.
  final double visualDensityHint;

  /// Mean saturation of opaque pixels, 0..1.
  final double colourfulness;

  /// Global luminance spread (RMS), 0..1 — a legibility proxy.
  final double contrast;

  final double aspectRatio;

  /// Bucketed word for the schema's `features.focalHierarchy`.
  String get focalHierarchy =>
      focalConcentration > 0.40
          ? 'strong'
          : focalConcentration > 0.25
          ? 'medium'
          : 'flat';

  /// Bucketed word for the schema's `features.legibility`.
  String get legibility =>
      contrast > 0.22 ? 'high' : (contrast > 0.11 ? 'medium' : 'low');

  /// The objective abstract-principle estimates this image implies. Feeds
  /// `StyleDna` when aggregating the Roavvy Design DNA.
  Map<DesignPrinciple, double> principleEstimates() => {
    DesignPrinciple.visualHierarchy: ((focalConcentration - 0.10) / 0.5).clamp(
      0.0,
      1.0,
    ),
    DesignPrinciple.visualDensity: visualDensityHint,
    DesignPrinciple.negativeSpace: (1 - visualDensityHint).clamp(0.0, 1.0),
    DesignPrinciple.colourRelationships: colourfulness,
  };

  Map<String, dynamic> toFeaturesJson() => {
    'dominantColors': dominantColors,
    'focalHierarchy': focalHierarchy,
    'legibility': legibility,
  };

  Map<String, dynamic> toAnalysisJson() => {
    'analyzerVersion': kReferenceAnalyzerVersion,
    'computedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
    'aspectRatio': double.parse(aspectRatio.toStringAsFixed(3)),
    'focalConcentration': double.parse(focalConcentration.toStringAsFixed(3)),
    'visualDensityHint': double.parse(visualDensityHint.toStringAsFixed(3)),
    'colourfulness': double.parse(colourfulness.toStringAsFixed(3)),
    'source': 'host-dart-ui',
  };
}

class _Bucket {
  int r = 0, g = 0, b = 0, n = 0;
  void add(int rr, int gg, int bb) {
    r += rr;
    g += gg;
    b += bb;
    n++;
  }

  String get hex {
    final rr = (r / n).round().clamp(0, 255);
    final gg = (g / n).round().clamp(0, 255);
    final bb = (b / n).round().clamp(0, 255);
    return '#${rr.toRadixString(16).padLeft(2, '0')}'
            '${gg.toRadixString(16).padLeft(2, '0')}'
            '${bb.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}

/// Analyse raw RGBA pixels (row-major, 4 bytes/pixel) into [ReferenceFeatures].
/// Pure + deterministic; no image decoding here (the caller decodes, e.g. via
/// `dart:ui`), so this is trivially unit-testable and reusable on any platform.
ReferenceFeatures analyzeReferenceRgba(Uint8List rgba, int width, int height) {
  const grid = 12; // coarse saliency grid
  final cellLum = List<double>.filled(grid * grid, 0);
  final cellCnt = List<int>.filled(grid * grid, 0);
  final buckets = <int, _Bucket>{};

  var lumSum = 0.0, lumSqSum = 0.0, satSum = 0.0;
  var opaque = 0;
  final stepX = math.max(1, (width / 96).floor());
  final stepY = math.max(1, (height / 96).floor());

  for (var y = 0; y < height; y += stepY) {
    for (var x = 0; x < width; x += stepX) {
      final o = (y * width + x) * 4;
      if (o + 3 >= rgba.length) continue;
      if (rgba[o + 3] < 24) continue; // ignore near-transparent
      final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2];
      final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      final sat = mx == 0 ? 0.0 : (mx - mn) / mx;
      lumSum += lum;
      lumSqSum += lum * lum;
      satSum += sat;
      opaque++;
      final gx = (x * grid ~/ width).clamp(0, grid - 1);
      final gy = (y * grid ~/ height).clamp(0, grid - 1);
      final ci = gy * grid + gx;
      cellLum[ci] += lum;
      cellCnt[ci]++;
      // Quantise colour to 5 levels/channel for frequency bucketing.
      final key = (r * 5 ~/ 256) * 25 + (g * 5 ~/ 256) * 5 + (b * 5 ~/ 256);
      (buckets[key] ??= _Bucket()).add(r, g, b);
    }
  }

  if (opaque == 0) {
    final aspect = height == 0 ? 1.0 : width / height;
    return ReferenceFeatures(
      dominantColors: const [],
      focalConcentration: 0,
      visualDensityHint: 0,
      colourfulness: 0,
      contrast: 0,
      aspectRatio: aspect,
    );
  }

  final meanLum = lumSum / opaque;
  final contrast = math.sqrt(
    math.max(0, lumSqSum / opaque - meanLum * meanLum),
  );
  final colourfulness = satSum / opaque;

  // Per-cell mean luminance → saliency = deviation from the occupied-grid mean.
  var occupied = 0;
  var gridMeanSum = 0.0;
  for (var i = 0; i < cellLum.length; i++) {
    if (cellCnt[i] > 0) {
      cellLum[i] /= cellCnt[i];
      gridMeanSum += cellLum[i];
      occupied++;
    }
  }
  final gridMean = occupied == 0 ? 0.0 : gridMeanSum / occupied;
  final saliency = <double>[];
  var busy = 0;
  for (var i = 0; i < cellLum.length; i++) {
    if (cellCnt[i] == 0) continue;
    final s = (cellLum[i] - gridMean).abs();
    saliency.add(s);
    if (s > 0.10) busy++;
  }
  saliency.sort((a, b) => b.compareTo(a));
  final total = saliency.fold<double>(0, (a, b) => a + b);
  final topK = math.max(1, (saliency.length * 0.1).ceil());
  final topSum = saliency.take(topK).fold<double>(0, (a, b) => a + b);
  final focalConcentration =
      total <= 0 ? 0.0 : (topSum / total).clamp(0.0, 1.0);
  final visualDensityHint = occupied == 0 ? 0.0 : busy / occupied;

  // Dominant colours: top buckets by frequency, deduped by hex.
  final ranked = buckets.values.toList()..sort((a, b) => b.n - a.n);
  final dominant = <String>[];
  for (final bkt in ranked) {
    final hx = bkt.hex;
    if (!dominant.contains(hx)) dominant.add(hx);
    if (dominant.length >= 4) break;
  }

  return ReferenceFeatures(
    dominantColors: dominant,
    focalConcentration: focalConcentration,
    visualDensityHint: visualDensityHint.clamp(0.0, 1.0),
    colourfulness: colourfulness.clamp(0.0, 1.0),
    contrast: contrast.clamp(0.0, 1.0),
    aspectRatio: height == 0 ? 1.0 : width / height,
  );
}
