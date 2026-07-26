import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'merch_variant_lookup.dart';

/// Curated print-scale presets for the composited artwork (M189).
///
/// The multiplier is applied to a placement's base [ProductMockupSpec.printAreaNorm]
/// Rect *about its centre*, so the design grows or shrinks in place.
///
/// [medium] is the identity (×1.0): existing designs render byte-identically
/// by default, so nothing changes unless the user explicitly picks another size.
enum ImageSize {
  small,
  medium,
  large;

  /// Factor applied to the base print-area Rect about its centre.
  ///
  /// Medium MUST stay exactly 1.0 (identity) so default output is unchanged.
  double get scaleMultiplier => switch (this) {
    ImageSize.small => 0.75,
    ImageSize.medium => 1.0,
    ImageSize.large => 1.3,
  };

  /// Parses the stored enum name back to an [ImageSize], tolerating unknown /
  /// missing values by falling back to [ImageSize.medium] (backward compat).
  static ImageSize fromName(String? s) => switch (s) {
    'small' => ImageSize.small,
    'large' => ImageSize.large,
    _ => ImageSize.medium,
  };
}

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
  'Blue': 'assets/mockups/Blue-tshirt-front.jpeg',
  'Grey': 'assets/mockups/Grey-tshirt-front.jpeg',
  'Red': 'assets/mockups/Red-tshirt-front.jpeg',
};
const _kTshirtBack = <String, String>{
  'Black': 'assets/mockups/Black-tshirt-back.jpeg',
  'White': 'assets/mockups/White-tshirt-back.jpg',
  'Blue': 'assets/mockups/Blue-tshirt-back.jpeg',
  'Grey': 'assets/mockups/Grey-tshirt-back.jpeg',
  'Red': 'assets/mockups/Red-tshirt-back.jpeg',
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
//   Back: left=0.30, top=0.22, width=0.40, height=0.50
const _kTshirtFrontLeftChestArea = Rect.fromLTWH(0.55, 0.25, 0.18, 0.25);
const _kTshirtFrontCenterArea = Rect.fromLTWH(0.25, 0.22, 0.50, 0.40);
const _kTshirtFrontRightChestArea = Rect.fromLTWH(0.27, 0.25, 0.18, 0.25);
const _kTshirtBackPrintArea = Rect.fromLTWH(0.30, 0.22, 0.40, 0.50);

// Poster: edge-to-edge with a small margin (poster_a4.png has 5% padding on all sides)
const _kPosterPrintArea = Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);

// ── Per-placement maximum print areas (M189 Image Size) ──────────────────────
//
// When [ImageSize.large] scales a base print area about its centre, the result
// is clamped to fit inside these bounding boxes so the artwork never bleeds past
// the printable area of the garment. Each box is centred on its base area.
//
// The full-front (center) and back placements may grow into the printable
// garment area; the small left/right-chest badges are capped tighter so Large
// stays a chest-sized badge on-garment rather than sprawling onto the shoulder.
const _kTshirtFrontLeftChestMaxArea = Rect.fromLTWH(0.53, 0.225, 0.22, 0.30);
const _kTshirtFrontRightChestMaxArea = Rect.fromLTWH(0.25, 0.225, 0.22, 0.30);
const _kTshirtFrontCenterMaxArea = Rect.fromLTWH(0.15, 0.15, 0.70, 0.60);
const _kTshirtBackMaxArea = Rect.fromLTWH(0.18, 0.12, 0.64, 0.72);

/// Scales [base] about its centre by [k], then clamps the result to fit inside
/// [maxArea] (and, implicitly, the unit square, since [maxArea] ⊆ [0,1]).
///
/// [ImageSize.medium] (k == 1.0) short-circuits to return [base] unchanged so
/// default output is byte-identical to the pre-M189 constants.
Rect _scaledPrintArea(Rect base, double k, Rect maxArea) {
  if (k == 1.0) return base;

  final cx = base.left + base.width / 2;
  final cy = base.top + base.height / 2;

  // Cap the scaled size to the placement's max box; keep the shared centre.
  final w = math.min(base.width * k, maxArea.width);
  final h = math.min(base.height * k, maxArea.height);

  var left = cx - w / 2;
  var top = cy - h / 2;

  // Nudge back inside the bounding box if the centred rect overhangs an edge.
  if (left < maxArea.left) left = maxArea.left;
  if (top < maxArea.top) top = maxArea.top;
  if (left + w > maxArea.right) left = maxArea.right - w;
  if (top + h > maxArea.bottom) top = maxArea.bottom - h;

  return Rect.fromLTWH(left, top, w, h);
}

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
  /// [imageSize] scales the resolved print area about its centre (M189):
  ///   Small shrinks it, [ImageSize.medium] (default) leaves it unchanged, and
  ///   Large grows it — clamped so it never bleeds past the printable area.
  ///   For [MerchProduct.poster] the size is ignored (posters are edge-to-edge).
  ///
  /// Throws [ArgumentError] if no spec is registered for the combination.
  static ProductMockupSpec specsFor(
    MerchProduct product, {
    String colour = 'Black',
    String placement = 'front',
    String frontPosition = 'left_chest',
    ImageSize imageSize = ImageSize.medium,
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
    final Rect baseArea;
    final Rect maxArea;
    if (isFront) {
      switch (frontPosition) {
        case 'center':
          baseArea = _kTshirtFrontCenterArea;
          maxArea = _kTshirtFrontCenterMaxArea;
        case 'right_chest':
          baseArea = _kTshirtFrontRightChestArea;
          maxArea = _kTshirtFrontRightChestMaxArea;
        default: // 'left_chest' + default
          baseArea = _kTshirtFrontLeftChestArea;
          maxArea = _kTshirtFrontLeftChestMaxArea;
      }
    } else {
      baseArea = _kTshirtBackPrintArea;
      maxArea = _kTshirtBackMaxArea;
    }
    final printArea = _scaledPrintArea(
      baseArea,
      imageSize.scaleMultiplier,
      maxArea,
    );
    return ProductMockupSpec(assetPath: assetPath, printAreaNorm: printArea);
  }
}
