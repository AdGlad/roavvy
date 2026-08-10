import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/design_dna.dart'
    show DesignPrinciple;
import 'package:mobile_flutter/features/merch/design_engine/reference/reference_style_analyzer.dart';

/// Build an opaque RGBA buffer of [w]×[h] with a per-pixel colour function.
Uint8List _rgba(int w, int h, List<int> Function(int x, int y) f) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final c = f(x, y);
      out[o] = c[0];
      out[o + 1] = c[1];
      out[o + 2] = c[2];
      out[o + 3] = 255;
    }
  }
  return out;
}

void main() {
  const w = 200, h = 200;

  test('a bright blob on a dark field reads as a strong focal point', () {
    final bytes = _rgba(w, h, (x, y) {
      final dx = x - w / 2, dy = y - h / 2;
      final inside = dx * dx + dy * dy < 30 * 30;
      return inside ? [255, 240, 220] : [12, 12, 16];
    });
    final f = analyzeReferenceRgba(bytes, w, h);
    expect(f.focalHierarchy, 'strong');
    expect(f.focalConcentration, greaterThan(0.4));
    expect(f.dominantColors, isNotEmpty);
  });

  test('a flat field reads as flat hierarchy and low contrast', () {
    final bytes = _rgba(w, h, (_, __) => [90, 100, 110]);
    final f = analyzeReferenceRgba(bytes, w, h);
    expect(f.focalHierarchy, 'flat');
    expect(f.legibility, 'low');
    expect(f.visualDensityHint, lessThan(0.1));
  });

  test('high-contrast split reads as high legibility', () {
    final bytes = _rgba(w, h, (x, y) => y < h / 2 ? [8, 8, 8] : [245, 245, 245]);
    final f = analyzeReferenceRgba(bytes, w, h);
    expect(f.legibility, 'high');
    expect(f.contrast, greaterThan(0.22));
  });

  test('saturated content reads as more colourful than greys', () {
    final grey = analyzeReferenceRgba(
        _rgba(w, h, (_, __) => [120, 120, 120]), w, h);
    final vivid = analyzeReferenceRgba(
        _rgba(w, h, (x, y) => x < w / 2 ? [220, 20, 30] : [20, 40, 220]), w, h);
    expect(vivid.colourfulness, greaterThan(grey.colourfulness));
    expect(vivid.principleEstimates()[DesignPrinciple.colourRelationships]!,
        greaterThan(
            grey.principleEstimates()[DesignPrinciple.colourRelationships]!));
  });

  test('objective principle estimates are all within [0,1]', () {
    final f = analyzeReferenceRgba(
        _rgba(w, h, (x, y) => [(x % 255), (y % 255), 128]), w, h);
    for (final v in f.principleEstimates().values) {
      expect(v, inInclusiveRange(0.0, 1.0));
    }
  });
}
