import 'package:flutter/widgets.dart';

import 'merch_variant_lookup.dart';

/// Immutable spec for a single bundled product mockup asset.
///
/// [assetPath] is the Flutter asset path (matches pubspec.yaml entry).
/// [printAreaNorm] is the region in the image where the card artwork is
/// composited, expressed in normalised 0.0–1.0 coordinates relative to
/// the effective image dimensions (Rect.fromLTWH semantics: left, top, width,
/// height). When [srcRectNorm] is set, "effective image" means the cropped
/// sub-rectangle; otherwise it means the full image.
///
/// [srcRectNorm] — optional source crop in normalised image coordinates. When
/// non-null, only that sub-rectangle of [assetPath] is used when drawing the
/// shirt background. Used to extract the front (left half) or back (right half)
/// from a single split image (ADR-115).
class ProductMockupSpec {
  const ProductMockupSpec({
    required this.assetPath,
    required this.printAreaNorm,
    this.srcRectNorm,
  });

  final String assetPath;

  /// Print area in normalised image coordinates (0.0–1.0, Rect.fromLTWH).
  /// Expressed relative to the effective (post-crop) image area.
  final Rect printAreaNorm;

  /// Optional source crop (0.0–1.0, Rect.fromLTWH). When non-null, the painter
  /// uses only this sub-rectangle of the asset image. Null means full image.
  final Rect? srcRectNorm;
}

// ── Asset path constants ──────────────────────────────────────────────────────

/// Single photoreal shirt mockup (1600×1066 JPEG).
/// Left half (x=0..799) = front view; right half (x=800..1599) = back view.
/// All five colour variants share this asset (ADR-115 Decision 3).
const _kShirtMockupFinal = 'assets/mockups/shirt-mockup-final.jpg';

const _kPosterA4 = 'assets/mockups/poster_a4.png';

// ── Source crop constants ─────────────────────────────────────────────────────

/// Left half of the split mockup image (front view).
const _kSrcFront = Rect.fromLTWH(0.0, 0.0, 0.5, 1.0);

/// Right half of the split mockup image (back view).
const _kSrcBack = Rect.fromLTWH(0.5, 0.0, 0.5, 1.0);

// ── Print area constants ──────────────────────────────────────────────────────
//
// T-shirt print areas are expressed relative to each half-image (800×1066 px).
// Calibrated against shirt-mockup-final.jpg (M59-01, ADR-115).
//   Front chest: left=0.30, top=0.32, width=0.40, height=0.45
//   Back:        left=0.30, top=0.30, width=0.40, height=0.45
const _kTshirtFrontPrintArea = Rect.fromLTWH(0.30, 0.32, 0.40, 0.45);
const _kTshirtBackPrintArea  = Rect.fromLTWH(0.30, 0.30, 0.40, 0.45);

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
  // T-shirt specs (colour × placement).
  // All colour variants share shirt-mockup-final.jpg (ADR-115 Decision 3);
  // colour swatch selection affects the Printful order colour, not the preview.
  static const _tshirtSpecs = <(String, String), ProductMockupSpec>{
    ('Black', 'front'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtFrontPrintArea,
      srcRectNorm: _kSrcFront,
    ),
    ('Black', 'back'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtBackPrintArea,
      srcRectNorm: _kSrcBack,
    ),
    ('White', 'front'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtFrontPrintArea,
      srcRectNorm: _kSrcFront,
    ),
    ('White', 'back'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtBackPrintArea,
      srcRectNorm: _kSrcBack,
    ),
    ('Navy', 'front'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtFrontPrintArea,
      srcRectNorm: _kSrcFront,
    ),
    ('Navy', 'back'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtBackPrintArea,
      srcRectNorm: _kSrcBack,
    ),
    ('Heather Grey', 'front'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtFrontPrintArea,
      srcRectNorm: _kSrcFront,
    ),
    ('Heather Grey', 'back'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtBackPrintArea,
      srcRectNorm: _kSrcBack,
    ),
    ('Red', 'front'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtFrontPrintArea,
      srcRectNorm: _kSrcFront,
    ),
    ('Red', 'back'): ProductMockupSpec(
      assetPath: _kShirtMockupFinal,
      printAreaNorm: _kTshirtBackPrintArea,
      srcRectNorm: _kSrcBack,
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
