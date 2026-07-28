// M200 — pixel-tier scorers over synthetic RGBA images. No rendering needed.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_flutter/features/merch/design_engine/design_params.dart';
import 'package:mobile_flutter/features/merch/design_engine/pixel_scorers.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile.dart';
import 'package:mobile_flutter/features/merch/design_engine/travel_profile_analyzer.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart';
import 'package:shared_models/shared_models.dart';

// ── Synthetic PNG builders (RGBA → PNG bytes) ────────────────────────────────

Uint8List _paint(
  int size,
  void Function(int x, int y, void Function(int, int, int, int) set) painter,
) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      painter(x, y, (r, g, b, a) => image.setPixelRgba(x, y, r, g, b, a));
    }
  }
  return img.encodePng(image);
}

Uint8List _solid(int r, int g, int b, int a, {int size = 32}) =>
    _paint(size, (x, y, set) => set(r, g, b, a));

/// Opaque; left half black, right half white → maximal luminance separation.
Uint8List _highContrastSplit({int size = 32}) => _paint(size, (x, y, set) {
      final v = x < size ~/ 2 ? 0 : 255;
      set(v, v, v, 255);
    });

/// Opaque; per-pixel random RGB → noisy, clashing, edges everywhere.
Uint8List _noisy({int size = 32, int seed = 7}) {
  final rng = math.Random(seed);
  return _paint(
    size,
    (x, y, set) =>
        set(rng.nextInt(256), rng.nextInt(256), rng.nextInt(256), 255),
  );
}

/// Opaque; two saturated complementary tones → coherent, harmonious palette.
Uint8List _harmoniousTwoTone({int size = 32}) => _paint(size, (x, y, set) {
      if (x < size ~/ 2) {
        set(20, 60, 220, 255); // saturated blue
      } else {
        set(230, 140, 20, 255); // saturated orange (complement)
      }
    });

/// Opaque high-contrast checkerboard with a moderate cell size → mid-band
/// detail (clear structure, not noise).
Uint8List _checkerboard({int size = 50, int cell = 5}) =>
    _paint(size, (x, y, set) {
      final on = ((x ~/ cell) + (y ~/ cell)) % 2 == 0;
      final v = on ? 0 : 255;
      set(v, v, v, 255);
    });

// ── Dummy genome / profile (pixel scorers ignore both) ───────────────────────

TripRecord _trip(String code) => TripRecord(
      id: '$code-t',
      countryCode: code,
      startedOn: DateTime(2022, 1, 1),
      endedOn: DateTime(2022, 1, 10),
      photoCount: 10,
      isManual: false,
    );

final TravelProfile _profile =
    TravelProfileAnalyzer.analyze(['FR', 'DE'].map(_trip).toList());

const DesignParams _params = DesignParams(
  template: CardTemplateType.grid,
  source: MerchCountrySource.allTime,
  countryCodes: ['FR', 'DE'],
);

double _c(Uint8List? bytes, [double weight = 1.0]) =>
    ContrastLegibilityScorer(weight: weight)
        .score(_params, _profile, thumbnail: bytes);
double _h(Uint8List? bytes) =>
    const ColorHarmonyScorer().score(_params, _profile, thumbnail: bytes);
double _e(Uint8List? bytes) =>
    const EdgeDensityScorer().score(_params, _profile, thumbnail: bytes);

void main() {
  group('ContrastLegibilityScorer', () {
    test('high-contrast split scores high; flat tones score low', () {
      final split = _c(_highContrastSplit());
      final black = _c(_solid(0, 0, 0, 255));
      final white = _c(_solid(255, 255, 255, 255));
      final noisy = _c(_noisy());
      expect(split, greaterThan(0.8));
      expect(black, lessThan(0.1));
      expect(white, lessThan(0.1));
      expect(split, greaterThan(black));
      expect(noisy, greaterThan(black));
      for (final v in [split, black, white, noisy]) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });

    test('null thumbnail yields a neutral 0.5', () {
      expect(_c(null), 0.5);
    });

    test('reports its configured weight', () {
      expect(const ContrastLegibilityScorer(weight: 1.3).weight, 1.3);
    });
  });

  group('ColorHarmonyScorer', () {
    test('harmonious two-tone beats muddy grey and clashing noise', () {
      final harmonious = _h(_harmoniousTwoTone());
      final muddy = _h(_solid(128, 128, 128, 255));
      final noisy = _h(_noisy());
      expect(harmonious, greaterThan(muddy));
      expect(harmonious, greaterThan(noisy));
      for (final v in [harmonious, muddy, noisy]) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });

    test('null thumbnail yields a neutral 0.5', () {
      expect(_h(null), 0.5);
    });
  });

  group('EdgeDensityScorer', () {
    test('mid-band structure beats a blank slab and pure noise', () {
      final mid = _e(_checkerboard());
      final blank = _e(_solid(0, 0, 0, 255));
      final noisy = _e(_noisy());
      expect(mid, greaterThan(0.7));
      expect(mid, greaterThan(blank));
      expect(mid, greaterThan(noisy));
      for (final v in [mid, blank, noisy]) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });

    test('null thumbnail yields a neutral 0.5', () {
      expect(_e(null), 0.5);
    });
  });

  group('kDefaultPixelScorers', () {
    test('exposes the three scorers, each bounded on every image', () {
      expect(kDefaultPixelScorers, hasLength(3));
      final images = <Uint8List?>[
        null,
        _solid(0, 0, 0, 255),
        _solid(255, 255, 255, 255),
        _highContrastSplit(),
        _noisy(),
        _harmoniousTwoTone(),
        _checkerboard(),
        _solid(0, 0, 0, 0), // fully transparent
      ];
      for (final s in kDefaultPixelScorers) {
        for (final im in images) {
          final v = s.score(_params, _profile, thumbnail: im);
          expect(v, inInclusiveRange(0.0, 1.0), reason: '${s.name} on $im');
        }
        expect(s.weight, greaterThan(0.0));
      }
    });
  });
}
