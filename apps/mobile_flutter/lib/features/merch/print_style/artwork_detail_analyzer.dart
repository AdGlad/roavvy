import 'dart:typed_data';
import 'dart:ui' as ui;

/// Result of analysing a piece of merch artwork for detail-protection.
///
/// [protection] (`0..1`) is the global "how detailed is this artwork" score —
/// higher means busier art (dense grids, intricate emblems) that should receive
/// proportionally *less* distress. It drives [PrintStyleParams.detailFactor].
///
/// [edgeMap] is a small, row-major single-channel mask ([mapWidth]×[mapHeight],
/// `0..255`) marking local high-contrast features (flag emblems, text, thin
/// details). The print-style pipeline upsamples it and attenuates distress where
/// it is high, so small important details stay inked even at high global
/// distress.
class ArtworkDetail {
  const ArtworkDetail({
    required this.protection,
    required this.coverage,
    required this.edgeDensity,
    required this.edgeMap,
    required this.mapWidth,
    required this.mapHeight,
  });

  final double protection;

  /// Fraction of pixels that carry ink (alpha above [kInkAlphaThreshold]).
  final double coverage;

  /// Mean local edge strength over inked pixels (`0..1`).
  final double edgeDensity;

  final Uint8List edgeMap;
  final int mapWidth;
  final int mapHeight;

  /// A "no protection" default for artwork that could not be analysed — treats
  /// the art as fully paintable (no auto-reduction), matching pre-style
  /// behaviour.
  static final ArtworkDetail none = ArtworkDetail(
    protection: 0,
    coverage: 0,
    edgeDensity: 0,
    edgeMap: Uint8List(1),
    mapWidth: 1,
    mapHeight: 1,
  );
}

/// Alpha value above which a pixel counts as "inked".
const int kInkAlphaThreshold = 24;

/// Gain applied to raw mean edge strength before blending into [protection].
/// Edge densities are small in absolute terms; this lifts them into a useful
/// `0..1` range. Named so preset/analysis tests stay stable.
const double kEdgeDensityGain = 3.0;

/// Relative weights of edge density vs ink coverage in the [protection] score.
const double kProtectionEdgeWeight = 0.55;
const double kProtectionCoverageWeight = 0.45;

/// Target longer-edge size for the downscaled analysis buffer. Small keeps the
/// pure computation to sub-millisecond and the result resolution-independent.
const int kAnalysisSize = 64;

/// Analyses [image] by downscaling to ~[kAnalysisSize] and reading it back.
///
/// Requires a live rendering binding (uses [ui.Image.toByteData]). The heavy
/// lifting is delegated to [computeArtworkDetail], which is a pure function and
/// the primary unit-test surface. Returns [ArtworkDetail.none] if the image
/// could not be read.
class ArtworkDetailAnalyzer {
  const ArtworkDetailAnalyzer._();

  static Future<ArtworkDetail> analyze(
    ui.Image image, {
    int targetSize = kAnalysisSize,
  }) async {
    try {
      final w = image.width;
      final h = image.height;
      if (w <= 0 || h <= 0) return ArtworkDetail.none;

      final scale = targetSize / (w > h ? w : h);
      final tw = (w * scale).round().clamp(1, targetSize);
      final th = (h * scale).round().clamp(1, targetSize);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final small = await picture.toImage(tw, th);
      picture.dispose();

      final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      small.dispose();
      if (data == null) return ArtworkDetail.none;

      return computeArtworkDetail(data.buffer.asUint8List(), tw, th);
    } catch (_) {
      return ArtworkDetail.none;
    }
  }
}

/// Pure computation of [ArtworkDetail] from a raw RGBA buffer ([rgba], length
/// `w*h*4`, row-major). Deterministic and side-effect free — the same buffer
/// always yields the same result — so it is directly unit-testable with
/// synthetic buffers.
///
/// - **coverage**: fraction of pixels with alpha ≥ [kInkAlphaThreshold].
/// - **edgeMap**: per-pixel luminance-gradient magnitude (`0..255`), the local
///   protection mask.
/// - **edgeDensity**: mean edge strength over inked pixels (`0..1`).
/// - **protection**: `clamp(edgeWeight·edgeDensity·gain + coverageWeight·coverage)`.
ArtworkDetail computeArtworkDetail(Uint8List rgba, int w, int h) {
  if (w <= 0 || h <= 0 || rgba.length < w * h * 4) {
    return ArtworkDetail.none;
  }

  // Precompute luminance (0..255) and inked flags.
  final lum = Uint8List(w * h);
  final inked = Uint8List(w * h);
  var inkCount = 0;
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    final r = rgba[o];
    final g = rgba[o + 1];
    final b = rgba[o + 2];
    final a = rgba[o + 3];
    // Rec. 601 luma.
    lum[i] = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
    if (a >= kInkAlphaThreshold) {
      inked[i] = 1;
      inkCount++;
    }
  }

  final coverage = inkCount / (w * h);

  // Edge map: |dL/dx| + |dL/dy|, normalised to 0..255.
  final edgeMap = Uint8List(w * h);
  var edgeSum = 0.0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final right = x + 1 < w ? lum[i + 1] : lum[i];
      final down = y + 1 < h ? lum[i + w] : lum[i];
      final grad = (lum[i] - right).abs() + (lum[i] - down).abs(); // 0..510
      final e = (grad ~/ 2).clamp(0, 255); // 0..255
      edgeMap[i] = e;
      if (inked[i] == 1) edgeSum += e / 255.0;
    }
  }

  final edgeDensity = inkCount > 0 ? (edgeSum / inkCount) : 0.0;

  final protection = (kProtectionEdgeWeight *
              (edgeDensity * kEdgeDensityGain).clamp(0.0, 1.0) +
          kProtectionCoverageWeight * coverage)
      .clamp(0.0, 1.0);

  return ArtworkDetail(
    protection: protection,
    coverage: coverage,
    edgeDensity: edgeDensity,
    edgeMap: edgeMap,
    mapWidth: w,
    mapHeight: h,
  );
}
