import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'signature_qa.dart';

/// Extra checks for two-country (pair) signature renders (ADR-185 §4, M207).
///
/// Runs on the same transparent artwork as [SignatureQa], plus the geometry
/// the composition reports ([PairGeometry.of]). Without geometry the seam is
/// assumed vertical through the middle and the emblem check is skipped.
///
/// - `pair_seam` (soft): the two flags are too alike where they meet, so the
///   seam disappears (Indonesia + Monaco). Passes when the seam has a gap.
/// - `pair_emblem` (hard): a flag's emblem/canton is less than
///   [minEmblemVisible] visible (a seam through Mexico's eagle).
/// - `pair_balance` (soft): one side holds less than [minHalfShare] of the
///   ink.
/// - `pair_swap` (hard): the same pair in the other order fails.
class PairQa {
  const PairQa._();

  /// Mean RGB distance (0–441) across the seam below which the seam is
  /// reported as illegible.
  static const double minSeamDistance = 60;

  /// Share of an emblem box that must stay visible.
  static const double minEmblemVisible = 0.7;

  /// Each half's share of the ink must lie in [minHalfShare, 1 - minHalfShare].
  static const double minHalfShare = 0.4;

  static const int _inkAlpha = 128;

  static Future<QaReport> checkImage(ui.Image image,
      {PairGeometry? geometry}) async {
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    return analyse(data!.buffer.asUint8List(), image.width, image.height,
        geometry: geometry);
  }

  /// [rgba] is straight RGBA, [width]×[height].
  static QaReport analyse(Uint8List rgba, int width, int height,
      {PairGeometry? geometry}) {
    final hard = <QaFinding>[];
    final soft = <QaFinding>[];
    final seam = geometry?.seam ?? PairSeam.vertical(0.5);

    final seamDistance = seamLegibility(rgba, width, height, seam);
    if (seamDistance != null && seamDistance < minSeamDistance) {
      soft.add(QaFinding(
          'pair_seam',
          'The two flags look alike where they meet '
              '(colour distance ${seamDistance.toStringAsFixed(0)} < '
              '${minSeamDistance.toStringAsFixed(0)}); add a seam gap'));
    }

    final share = leftShare(rgba, width, height, seam);
    if (share != null && (share < minHalfShare || share > 1 - minHalfShare)) {
      soft.add(QaFinding(
          'pair_balance',
          'Unbalanced halves: A has ${(share * 100).toStringAsFixed(0)}% of '
              'the ink (want ${(minHalfShare * 100).round()}–'
              '${((1 - minHalfShare) * 100).round()}%)'));
    }

    final emblems = <String, double>{};
    for (final c in geometry?.crops ?? const <FlagCrop>[]) {
      final v = c.emblemVisible;
      emblems['${c.slot}:${c.code}'] = _round(v);
      final f = emblemFinding(c);
      if (f != null) hard.add(f);
    }

    return QaReport(hard: hard, soft: soft, metrics: {
      'pair': {
        if (seamDistance != null) 'seamDistance': _round(seamDistance),
        if (share != null) 'leftShare': _round(share),
        'seamGap': seam.gap,
        if (emblems.isNotEmpty) 'emblemVisible': emblems,
      },
    });
  }

  /// The hard finding for a crop that hides too much of its flag's emblem,
  /// or null.
  static QaFinding? emblemFinding(FlagCrop crop) {
    final v = crop.emblemVisible;
    if (v >= minEmblemVisible) return null;
    return QaFinding(
        'pair_emblem',
        '${crop.code.toUpperCase()} shows only ${(v * 100).round()}% of its '
            '${crop.focus.kind.name} (need ${(minEmblemVisible * 100).round()}%)');
  }

  /// The hard finding when the swapped pair ([swapKey], e.g. `co+us`) fails,
  /// or null.
  static QaFinding? swapFinding(String swapKey, QaReport swapped) {
    if (swapped.status != QaStatus.fail) return null;
    return QaFinding(
        'pair_swap',
        'Swapped (${swapKey.toUpperCase()}) fails: '
            '${swapped.hard.map((f) => f.message).join('; ')}');
  }

  /// Median, over rows where both sides of the seam carry ink, of the RGB
  /// distance between the mean colours just left and just right of it.
  /// Null when the seam has a gap or the flags never meet (nothing to judge).
  static double? seamLegibility(
      Uint8List rgba, int width, int height, PairSeam seam) {
    if (seam.gap > 0) return null;
    final band = math.max(2, (width * 0.03).round());
    final distances = <double>[];
    // A channel the renderer drew along the seam (e.g. Curtain Split's
    // automatic gap for look-alike flags) counts as a drawn seam.
    var inkedRows = 0, channelRows = 0;
    for (var y = 0; y < height; y++) {
      final sx = (seam.xAt((y + 0.5) / height) * width).round();
      final l = _meanInk(rgba, width, y, sx - 1 - band, sx - 1);
      final r = _meanInk(rgba, width, y, sx + 1, sx + 1 + band);
      if (l == null || r == null) continue;
      inkedRows++;
      if (_isChannel(rgba, width, y, sx)) channelRows++;
      final dr = l.$1 - r.$1, dg = l.$2 - r.$2, db = l.$3 - r.$3;
      distances.add(math.sqrt(dr * dr + dg * dg + db * db));
    }
    if (distances.length < math.max(4, height * 0.1)) return null;
    if (channelRows > inkedRows * 0.6) return null;
    distances.sort();
    return distances[distances.length ~/ 2];
  }

  /// Share of the ink on A's side of the seam, or null with no ink.
  static double? leftShare(
      Uint8List rgba, int width, int height, PairSeam seam) {
    var left = 0, total = 0;
    for (var y = 0; y < height; y++) {
      final sx = seam.xAt((y + 0.5) / height) * width;
      for (var x = 0; x < width; x++) {
        if (rgba[(y * width + x) * 4 + 3] < _inkAlpha) continue;
        total++;
        if (x + 0.5 < sx) left++;
      }
    }
    return total == 0 ? null : left / total;
  }

  /// True when the pixels at the seam (±1) are bare garment.
  static bool _isChannel(Uint8List rgba, int width, int y, int sx) {
    var bare = 0;
    for (var x = sx - 1; x <= sx + 1; x++) {
      if (x < 0 || x >= width) continue;
      if (rgba[(y * width + x) * 4 + 3] < _inkAlpha) bare++;
    }
    return bare >= 2;
  }

  static (double, double, double)? _meanInk(
      Uint8List rgba, int width, int y, int x0, int x1) {
    var n = 0;
    var r = 0.0, g = 0.0, b = 0.0;
    for (var x = math.max(0, x0); x < math.min(width, x1); x++) {
      final i = (y * width + x) * 4;
      if (rgba[i + 3] < _inkAlpha) continue;
      r += rgba[i];
      g += rgba[i + 1];
      b += rgba[i + 2];
      n++;
    }
    // Need most of the band inked, so a ragged edge doesn't count.
    if (n == 0 || n < (x1 - x0) * 0.6) return null;
    return (r / n, g / n, b / n);
  }

  static double _round(double v) => (v * 10000).roundToDouble() / 10000;
}
