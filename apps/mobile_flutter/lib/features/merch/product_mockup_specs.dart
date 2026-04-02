import 'package:flutter/widgets.dart';

import 'merch_variant_lookup.dart';

/// Immutable spec for a single bundled product mockup asset.
///
/// [assetPath] is the Flutter asset path (matches pubspec.yaml entry).
/// [printAreaNorm] is the region in the image where the card artwork is
/// composited, expressed in normalised 0.0–1.0 coordinates relative to
/// the image dimensions (Rect.fromLTWH semantics: left, top, width, height).
///
/// Print area coordinates were calibrated against the 600×800 placeholder
/// images in assets/mockups/. Replace placeholders with production photography
/// and re-calibrate before shipping (see ADR-107, Risk 1).
class ProductMockupSpec {
  const ProductMockupSpec({
    required this.assetPath,
    required this.printAreaNorm,
  });

  final String assetPath;

  /// Print area in normalised image coordinates (0.0–1.0, Rect.fromLTWH).
  final Rect printAreaNorm;
}

// ── Asset path constants ──────────────────────────────────────────────────────

const _kTshirtBlackFront    = 'assets/mockups/tshirt_black_front.png';
const _kTshirtBlackBack     = 'assets/mockups/tshirt_black_back.png';
const _kTshirtWhiteFront    = 'assets/mockups/tshirt_white_front.png';
const _kTshirtWhiteBack     = 'assets/mockups/tshirt_white_back.png';
const _kTshirtNavyFront     = 'assets/mockups/tshirt_navy_front.png';
const _kTshirtNavyBack      = 'assets/mockups/tshirt_navy_back.png';
const _kTshirtHGFront       = 'assets/mockups/tshirt_heather_grey_front.png';
const _kTshirtHGBack        = 'assets/mockups/tshirt_heather_grey_back.png';
const _kTshirtRedFront      = 'assets/mockups/tshirt_red_front.png';
const _kTshirtRedBack       = 'assets/mockups/tshirt_red_back.png';
const _kPosterA4            = 'assets/mockups/poster_a4.png';

// ── Print area constants ──────────────────────────────────────────────────────
//
// T-shirt chest area (front and back): centred, upper-mid region.
// Calibrated against 600×800 placeholder: left=150px, top=160px, w=300px, h=320px
// → normalised: left=0.25, top=0.20, width=0.50, height=0.40
const _kTshirtPrintArea = Rect.fromLTWH(0.25, 0.20, 0.50, 0.40);

// Poster: edge-to-edge with a small margin (poster_a4.png has 5% padding on all sides)
const _kPosterPrintArea = Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);

// ── Registry ─────────────────────────────────────────────────────────────────

/// Static registry mapping (product, colour, placement) → [ProductMockupSpec].
///
/// Usage:
/// ```dart
/// final spec = ProductMockupSpecs.specsFor(
///   MerchProduct.tshirt, colour: 'Black', placement: 'front',
/// );
/// ```
///
/// For posters, [colour] and [placement] are ignored — there is a single spec
/// regardless of paper type or size.
abstract final class ProductMockupSpecs {
  // T-shirt specs (colour × placement)
  static const _tshirtSpecs = <(String, String), ProductMockupSpec>{
    ('Black', 'front'): ProductMockupSpec(
      assetPath: _kTshirtBlackFront,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Black', 'back'): ProductMockupSpec(
      assetPath: _kTshirtBlackBack,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('White', 'front'): ProductMockupSpec(
      assetPath: _kTshirtWhiteFront,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('White', 'back'): ProductMockupSpec(
      assetPath: _kTshirtWhiteBack,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Navy', 'front'): ProductMockupSpec(
      assetPath: _kTshirtNavyFront,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Navy', 'back'): ProductMockupSpec(
      assetPath: _kTshirtNavyBack,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Heather Grey', 'front'): ProductMockupSpec(
      assetPath: _kTshirtHGFront,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Heather Grey', 'back'): ProductMockupSpec(
      assetPath: _kTshirtHGBack,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Red', 'front'): ProductMockupSpec(
      assetPath: _kTshirtRedFront,
      printAreaNorm: _kTshirtPrintArea,
    ),
    ('Red', 'back'): ProductMockupSpec(
      assetPath: _kTshirtRedBack,
      printAreaNorm: _kTshirtPrintArea,
    ),
  };

  static const _posterSpec = ProductMockupSpec(
    assetPath: _kPosterA4,
    printAreaNorm: _kPosterPrintArea,
  );

  /// Returns the [ProductMockupSpec] for the given [product], [colour], and
  /// [placement]. For [MerchProduct.poster], [colour] and [placement] are
  /// ignored.
  ///
  /// Throws [ArgumentError] if no spec is registered for the combination.
  static ProductMockupSpec specsFor(
    MerchProduct product, {
    String colour = 'Black',
    String placement = 'front',
  }) {
    if (product == MerchProduct.poster) return _posterSpec;
    final spec = _tshirtSpecs[(colour, placement)];
    if (spec == null) {
      throw ArgumentError(
        'No ProductMockupSpec registered for '
        'product=$product colour=$colour placement=$placement',
      );
    }
    return spec;
  }
}
