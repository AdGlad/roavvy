import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/print_style/artwork_detail_analyzer.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style_textures.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

/// Builds a WxH RGBA buffer. [pixel] returns (r,g,b,a) for a coordinate.
Uint8List buildRgba(
  int w,
  int h,
  List<int> Function(int x, int y) pixel,
) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = pixel(x, y);
      final o = (y * w + x) * 4;
      out[o] = p[0];
      out[o + 1] = p[1];
      out[o + 2] = p[2];
      out[o + 3] = p[3];
    }
  }
  return out;
}

void main() {
  group('kPrintStylePresets', () {
    test('has an entry for every PrintStyleId', () {
      for (final id in PrintStyleId.values) {
        expect(kPrintStylePresets.containsKey(id), isTrue, reason: id.name);
        expect(kPrintStylePresets[id]!.id, id);
      }
    });

    test('clean preset is a zero-effect pass-through', () {
      final clean = kPrintStylePresets[PrintStyleId.clean]!;
      expect(clean.isClean, isTrue);
      expect(clean.distress, 0);
      expect(clean.grain, 0);
      expect(clean.fade, 0);
      expect(clean.roughEdges, 0);
      expect(clean.halftone, 0);
      expect(clean.colorTreatment, ColorTreatment.none);
    });

    test('grunge distresses more than vintage', () {
      expect(
        kPrintStylePresets[PrintStyleId.grunge]!.distress,
        greaterThan(kPrintStylePresets[PrintStyleId.vintage]!.distress),
      );
    });

    test('printStyleFromName round-trips and defaults to clean', () {
      for (final id in PrintStyleId.values) {
        expect(printStyleFromName(id.name), id);
      }
      expect(printStyleFromName('nonsense'), PrintStyleId.clean);
      expect(printStyleFromName(null), PrintStyleId.clean);
    });
  });

  group('computeArtworkDetail', () {
    // A busy, fully-inked checkerboard: max edge density + full coverage.
    ArtworkDetail busy() => computeArtworkDetail(
          buildRgba(32, 32, (x, y) {
            final on = (x + y).isEven;
            final v = on ? 255 : 0;
            return [v, v, v, 255];
          }),
          32,
          32,
        );

    // A sparse design: small uniform opaque block on a transparent field.
    ArtworkDetail sparse() => computeArtworkDetail(
          buildRgba(32, 32, (x, y) {
            final inBlock = x >= 12 && x < 20 && y >= 12 && y < 20;
            return inBlock ? [10, 120, 200, 255] : [0, 0, 0, 0];
          }),
          32,
          32,
        );

    test('busy artwork has higher protection than sparse', () {
      expect(busy().protection, greaterThan(sparse().protection));
    });

    test('detailFactor: busy < sparse (detailed art distressed less)', () {
      final base = kPrintStylePresets[PrintStyleId.grunge]!;
      final busyFactor = base.resolvedFor(busy()).detailFactor;
      final sparseFactor = base.resolvedFor(sparse()).detailFactor;
      expect(busyFactor, lessThan(sparseFactor));
      expect(busyFactor, inInclusiveRange(0.0, 1.0));
      expect(sparseFactor, inInclusiveRange(0.0, 1.0));
    });

    test('protection is monotonic in coverage (edge held flat)', () {
      // Uniform opaque colour → zero interior edges; only coverage varies.
      ArtworkDetail withCoverage(int opaqueRows) => computeArtworkDetail(
            buildRgba(16, 16, (x, y) {
              final opaque = y < opaqueRows;
              return opaque ? [80, 80, 80, 255] : [80, 80, 80, 0];
            }),
            16,
            16,
          );
      final low = withCoverage(4);
      final high = withCoverage(12);
      expect(high.coverage, greaterThan(low.coverage));
      expect(high.protection, greaterThan(low.protection));
    });

    test('edge map marks the high-contrast boundary, not flat interiors', () {
      final d = computeArtworkDetail(
        buildRgba(16, 16, (x, y) {
          // Left half black, right half white — a single vertical edge at x=8.
          final v = x < 8 ? 0 : 255;
          return [v, v, v, 255];
        }),
        16,
        16,
      );
      // Interior of a flat region has no edge; the seam column does.
      final flatInterior = d.edgeMap[3 * 16 + 3];
      final seam = d.edgeMap[3 * 16 + 7]; // pixel just left of the boundary
      expect(flatInterior, 0);
      expect(seam, greaterThan(100));
    });

    test('malformed buffer returns ArtworkDetail.none', () {
      final d = computeArtworkDetail(Uint8List(3), 4, 4);
      expect(d.protection, 0);
      expect(d.coverage, 0);
    });
  });

  group('seeded textures are deterministic', () {
    test('grain: same seed identical, different seed differs', () {
      final a = generateGrainBytes(seed: 7, size: 32);
      final b = generateGrainBytes(seed: 7, size: 32);
      final c = generateGrainBytes(seed: 8, size: 32);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.length, 32 * 32 * 4);
    });

    test('blotch: deterministic and tileable size', () {
      final a = generateBlotchBytes(seed: 3, size: 64, cells: 8);
      final b = generateBlotchBytes(seed: 3, size: 64, cells: 8);
      expect(a, equals(b));
      expect(a.length, 64 * 64 * 4);
    });

    test('scratch: deterministic; density changes output', () {
      final a = generateScratchBytes(seed: 5, size: 48, density: 1.0);
      final b = generateScratchBytes(seed: 5, size: 48, density: 1.0);
      final c = generateScratchBytes(seed: 5, size: 48, density: 2.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('crack: deterministic; different seed differs', () {
      final a = generateCrackBytes(seed: 9, size: 48);
      final b = generateCrackBytes(seed: 9, size: 48);
      final c = generateCrackBytes(seed: 10, size: 48);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      // Cracks are sparse: most of the field is intact (bright).
      var bright = 0;
      for (var i = 0; i < 48 * 48; i++) {
        if (a[i * 4] > 200) bright++;
      }
      expect(bright, greaterThan(48 * 48 ~/ 2));
    });

    test('torn edge: deterministic; erodes borders not the centre', () {
      final a = generateTornEdgeBytes(seed: 4, w: 64, h: 48);
      final b = generateTornEdgeBytes(seed: 4, w: 64, h: 48);
      expect(a, equals(b));
      // Centre pixel: no erosion (alpha 0). A corner: some erosion.
      final centre = a[((24 * 64) + 32) * 4 + 3];
      expect(centre, 0);
      final corner = a[0 * 4 + 3];
      expect(corner, greaterThan(0));
    });

    test('all texture bytes are opaque grayscale (R==G==B, A==255)', () {
      final g = generateGrainBytes(seed: 1, size: 8);
      for (var i = 0; i < 8 * 8; i++) {
        final o = i * 4;
        expect(g[o], g[o + 1]);
        expect(g[o + 1], g[o + 2]);
        expect(g[o + 3], 255);
      }
    });
  });
}
