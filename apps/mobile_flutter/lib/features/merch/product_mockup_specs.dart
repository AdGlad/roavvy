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

const _kPosterA4 = 'assets/mockups/poster_a4.png';

// Per-colour t-shirt mockup JPEGs (front and back for each available colour).
const _kTshirtFront = <String, String>{
  'Black': 'assets/mockups/Black-tshirt-front.jpeg',
  'White': 'assets/mockups/White-tshirt-front.jpg',
  'Blue':  'assets/mockups/Blue-tshirt-front.jpeg',
  'Grey':  'assets/mockups/Grey-tshirt-front.jpeg',
  'Red':   'assets/mockups/Red-tshirt-front.jpeg',
};
const _kTshirtBack = <String, String>{
  'Black': 'assets/mockups/Black-tshirt-back.jpeg',
  'White': 'assets/mockups/White-tshirt-back.jpg',
  'Blue':  'assets/mockups/Blue-tshirt-back.jpeg',
  'Grey':  'assets/mockups/Grey-tshirt-back.jpeg',
  'Red':   'assets/mockups/Red-tshirt-back.jpeg',
};

// ── Print area constants ──────────────────────────────────────────────────────
//
// T-shirt print areas are expressed relative to each image (800×1066 px).
// Calibrated against the split shirt mockups (M59-01, ADR-115).
//   Front left-chest  (wearer's left = viewer's right):
//     left=0.55, top=0.25, width=0.18, height=0.25
//   Front center:
//     left=0.25, top=0.22, width=0.50, height=0.40
//   Front right-chest (wearer's right = viewer's left):
//     left=0.27, top=0.25, width=0.18, height=0.25
//   Back: left=0.30, top=0.30, width=0.40, height=0.45
const _kTshirtFrontLeftChestArea  = Rect.fromLTWH(0.55, 0.25, 0.18, 0.25);
const _kTshirtFrontCenterArea     = Rect.fromLTWH(0.25, 0.22, 0.50, 0.40);
const _kTshirtFrontRightChestArea = Rect.fromLTWH(0.27, 0.25, 0.18, 0.25);
const _kTshirtBackPrintArea       = Rect.fromLTWH(0.30, 0.30, 0.40, 0.45);

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
  static const _posterSpec = ProductMockupSpec(
    assetPath: _kPosterA4,
    printAreaNorm: _kPosterPrintArea,
  );

  /// Returns the [ProductMockupSpec] for the given [product], [colour], and
  /// face. For [MerchProduct.poster], [colour] and [placement] are ignored.
  ///
  /// [placement] is `'front'` or `'back'`.
  /// [frontPosition] controls the print area when [placement] is `'front'`:
  ///   `'left_chest'` (default), `'center'`, or `'right_chest'`.
  ///
  /// Throws [ArgumentError] if no spec is registered for the combination.
  static ProductMockupSpec specsFor(
    MerchProduct product, {
    String colour = 'Black',
    String placement = 'front',
    String frontPosition = 'left_chest',
  }) {
    if (product == MerchProduct.poster) return _posterSpec;
    final isFront = placement == 'front';
    final assetPath = (isFront ? _kTshirtFront : _kTshirtBack)[colour];
    if (assetPath == null) {
      throw ArgumentError(
        'No mockup asset registered for '
        'product=$product colour=$colour placement=$placement',
      );
    }
    final Rect printArea;
    if (isFront) {
      printArea = switch (frontPosition) {
        'center'      => _kTshirtFrontCenterArea,
        'right_chest' => _kTshirtFrontRightChestArea,
        _             => _kTshirtFrontLeftChestArea, // 'left_chest' + default
      };
    } else {
      printArea = _kTshirtBackPrintArea;
    }
    return ProductMockupSpec(assetPath: assetPath, printAreaNorm: printArea);
  }
}
