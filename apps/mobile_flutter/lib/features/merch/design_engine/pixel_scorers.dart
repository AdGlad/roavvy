import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'travel_profile.dart';

/// M200 — the pixel ("tier 2") scorers (§6.3). Each decodes the rendered
/// thumbnail bytes and measures a property that the analytic geometry tier
/// cannot see — actual contrast, colour relationships, and edge/detail density.
///
/// The [DesignScorer.score] contract is synchronous, so decoding uses the
/// `image` package's synchronous [img.decodePng] (already a dependency) rather
/// than the async `dart:ui` codec. Bytes are decoded once and down-sampled to a
/// bounded grid (see [_SampledThumbnail]); the decode is memoised on the byte
/// reference so the three scorers scoring the same thumbnail in sequence only
/// decode once.
///
/// All scorers return a neutral 0.5 when [thumbnail] is null (the analytic tier)
/// or when the bytes cannot be decoded / carry too little ink to judge. Outputs
/// are always in [0, 1].

// ── Sampling ─────────────────────────────────────────────────────────────────

/// Max sampled grid dimension. Thumbnails are down-sampled to at most this many
/// cells per axis so each scorer's inner loop is bounded regardless of the
/// raster resolution.
const int _kMaxSample = 64;

/// Alpha (0..1) at or above which a pixel counts as artwork "ink" rather than
/// transparent background.
const double _kOpaqueAlpha = 0.5;

double _luminance(double r, double g, double b) =>
    0.2126 * r + 0.7152 * g + 0.0722 * b;

/// A decoded thumbnail down-sampled to a [gw]×[gh] grid of normalised (0..1)
/// RGBA channels.
class _SampledThumbnail {
  _SampledThumbnail(this.gw, this.gh, this.r, this.g, this.b, this.a);

  final int gw;
  final int gh;
  final Float64List r;
  final Float64List g;
  final Float64List b;
  final Float64List a;

  int get length => gw * gh;
}

// Single-entry memo keyed on the byte reference. Pixel scoring runs on the UI
// thread only (never in an isolate), so a mutable top-level cache is safe.
Uint8List? _memoBytes;
_SampledThumbnail? _memoSample;
bool _memoComputed = false;

_SampledThumbnail? _sampleCached(Uint8List bytes) {
  if (_memoComputed && identical(bytes, _memoBytes)) return _memoSample;
  final sample = _decodeSample(bytes);
  _memoBytes = bytes;
  _memoSample = sample;
  _memoComputed = true;
  return sample;
}

_SampledThumbnail? _decodeSample(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  img.Image? image;
  try {
    image = img.decodePng(bytes) ?? img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (image == null) return null;
  final w = image.width;
  final h = image.height;
  if (w == 0 || h == 0) return null;

  final gw = w < _kMaxSample ? w : _kMaxSample;
  final gh = h < _kMaxSample ? h : _kMaxSample;
  final r = Float64List(gw * gh);
  final g = Float64List(gw * gh);
  final b = Float64List(gw * gh);
  final a = Float64List(gw * gh);

  for (var gy = 0; gy < gh; gy++) {
    final sy = gy * h ~/ gh;
    for (var gx = 0; gx < gw; gx++) {
      final sx = gx * w ~/ gw;
      final p = image.getPixel(sx, sy);
      final idx = gy * gw + gx;
      r[idx] = p.rNormalized.toDouble();
      g[idx] = p.gNormalized.toDouble();
      b[idx] = p.bNormalized.toDouble();
      a[idx] = p.aNormalized.toDouble();
    }
  }
  return _SampledThumbnail(gw, gh, r, g, b, a);
}

({double h, double s, double v}) _rgbToHsv(double r, double g, double b) {
  final maxc = math.max(r, math.max(g, b));
  final minc = math.min(r, math.min(g, b));
  final d = maxc - minc;
  double h;
  if (d == 0) {
    h = 0;
  } else if (maxc == r) {
    h = 60 * (((g - b) / d) % 6);
  } else if (maxc == g) {
    h = 60 * (((b - r) / d) + 2);
  } else {
    h = 60 * (((r - g) / d) + 4);
  }
  if (h < 0) h += 360;
  final s = maxc == 0 ? 0.0 : d / maxc;
  return (h: h, s: s, v: maxc);
}

// ── Contrast / legibility ─────────────────────────────────────────────────────

/// Measures the luminance spread of the artwork's ink — the separation between
/// its lightest and darkest regions. A flat, single-tone design (all-black,
/// all-white) reads as low contrast → illegible; a design with a clear
/// light/dark separation reads as legible. Uses a robust p90−p10 spread so a
/// few stray pixels don't dominate.
class ContrastLegibilityScorer implements DesignScorer {
  const ContrastLegibilityScorer({this.weight = 1.0});

  @override
  final double weight;

  @override
  String get name => 'ContrastLegibility';

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    if (thumbnail == null) return 0.5;
    final s = _sampleCached(thumbnail);
    if (s == null) return 0.5;

    final lums = <double>[];
    for (var i = 0; i < s.length; i++) {
      if (s.a[i] >= _kOpaqueAlpha) {
        lums.add(_luminance(s.r[i], s.g[i], s.b[i]));
      }
    }
    if (lums.length < 4) return 0.5; // too little ink to judge

    lums.sort();
    final p10 = lums[(lums.length * 0.10).floor()];
    final hiIdx = (lums.length * 0.90).floor().clamp(0, lums.length - 1);
    final p90 = lums[hiIdx];
    return (p90 - p10).clamp(0.0, 1.0);
  }
}

// ── Colour harmony ────────────────────────────────────────────────────────────

/// Samples the artwork palette and rewards a coherent, saturated relationship
/// while penalising two failure modes a designer avoids: muddy (desaturated
/// grey mush) and clashing (hues scattered across the whole wheel). Combines a
/// mean-saturation term (muddiness) with a hue-concentration term (chaos),
/// measured over a saturation-weighted hue histogram.
class ColorHarmonyScorer implements DesignScorer {
  const ColorHarmonyScorer({this.weight = 0.8});

  @override
  final double weight;

  @override
  String get name => 'ColorHarmony';

  static const int _bins = 12;

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    if (thumbnail == null) return 0.5;
    final s = _sampleCached(thumbnail);
    if (s == null) return 0.5;

    final hist = List<double>.filled(_bins, 0);
    var satSum = 0.0;
    var weightSum = 0.0;
    var opaque = 0;
    for (var i = 0; i < s.length; i++) {
      if (s.a[i] < _kOpaqueAlpha) continue;
      final hsv = _rgbToHsv(s.r[i], s.g[i], s.b[i]);
      opaque++;
      satSum += hsv.s;
      // Grey / black / white contribute ~0, so they don't spread the histogram.
      final w = hsv.s * hsv.v;
      weightSum += w;
      hist[(hsv.h / 30).floor() % _bins] += w;
    }
    if (opaque < 4) return 0.5;

    // Muddiness: a desaturated palette scores low.
    final meanSat = satSum / opaque;
    final satScore = (meanSat / 0.35).clamp(0.0, 1.0);
    if (weightSum <= 1e-6) return 0.15; // fully desaturated → muddy

    // Chaos: entropy of the hue distribution. Concentrated (few coherent hues)
    // → harmonious; spread evenly across the wheel → clashing.
    var entropy = 0.0;
    for (final bin in hist) {
      if (bin <= 0) continue;
      final p = bin / weightSum;
      entropy -= p * math.log(p);
    }
    final norm = entropy / math.log(_bins); // 0 concentrated .. 1 chaotic
    final hueScore = (1.0 - norm).clamp(0.0, 1.0);

    return (0.5 * satScore + 0.5 * hueScore).clamp(0.0, 1.0);
  }
}

// ── Edge / detail density ─────────────────────────────────────────────────────

/// Measures how busy the artwork is by counting significant transitions between
/// adjacent samples (a luminance jump, or an ink↔background boundary). Peaks in
/// a healthy mid-band — like the analytic whitespace scorer — so a blank slab
/// (no edges) and visual noise (edges everywhere) both score low, while a design
/// with clear, readable structure scores high.
class EdgeDensityScorer implements DesignScorer {
  const EdgeDensityScorer({
    this.weight = 0.8,
    this.idealDensity = 0.18,
    this.tolerance = 0.18,
    this.lumThreshold = 0.20,
  });

  @override
  final double weight;

  /// Fraction of adjacent-sample transitions that reads as an ideal amount of
  /// detail.
  final double idealDensity;

  /// Half-width of the healthy band around [idealDensity].
  final double tolerance;

  /// Minimum luminance jump between two opaque samples to count as an edge.
  final double lumThreshold;

  @override
  String get name => 'EdgeDensity';

  @override
  double score(
    DesignParams params,
    TravelProfile profile, {
    Uint8List? thumbnail,
  }) {
    if (thumbnail == null) return 0.5;
    final s = _sampleCached(thumbnail);
    if (s == null) return 0.5;

    var edges = 0;
    var comparisons = 0;
    for (var gy = 0; gy < s.gh; gy++) {
      for (var gx = 0; gx < s.gw; gx++) {
        final i = gy * s.gw + gx;
        if (gx + 1 < s.gw) {
          comparisons++;
          if (_isEdge(s, i, i + 1)) edges++;
        }
        if (gy + 1 < s.gh) {
          comparisons++;
          if (_isEdge(s, i, i + s.gw)) edges++;
        }
      }
    }
    if (comparisons == 0) return 0.5;

    final density = edges / comparisons;
    return (1.0 - (density - idealDensity).abs() / tolerance).clamp(0.0, 1.0);
  }

  bool _isEdge(_SampledThumbnail s, int i, int j) {
    final oi = s.a[i] >= _kOpaqueAlpha;
    final oj = s.a[j] >= _kOpaqueAlpha;
    if (oi != oj) return true; // ink ↔ background boundary
    if (!oi && !oj) return false; // both transparent
    final li = _luminance(s.r[i], s.g[i], s.b[i]);
    final lj = _luminance(s.r[j], s.g[j], s.b[j]);
    return (li - lj).abs() > lumThreshold;
  }
}

/// The default pixel-tier scorers (§6.3), run on the top-K survivors per
/// generation once their thumbnails are rendered.
const List<DesignScorer> kDefaultPixelScorers = [
  ContrastLegibilityScorer(),
  ColorHarmonyScorer(),
  EdgeDensityScorer(),
];
