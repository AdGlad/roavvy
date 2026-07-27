import 'package:flutter/widgets.dart';

import 'merch_variant_lookup.dart';

/// Curated print-size presets for the composited artwork (M189/M190).
///
/// Each placement has a **fixed printable area** (the real Printful printable
/// region — see the print-area constants below). [ImageSize] chooses how much
/// of that fixed area the artwork fills, as a fraction of it. This keeps the
/// preview honest: [ImageSize.large] fills the printable area exactly (never
/// bleeds past it), and every size maps to something the printer can actually
/// produce. The same fraction is applied to the print file sent to Printful, so
/// the preview matches the print (M190).
enum ImageSize {
  small,
  medium,
  large;

  /// Fraction of the placement's printable area the artwork fills. Large fills
  /// the whole printable area (1.0); it can never exceed it. Medium is the
  /// sensible default; Small is a compact print.
  double get fillFraction => switch (this) {
    ImageSize.small => 0.65,
    ImageSize.medium => 0.85,
    ImageSize.large => 1.0,
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

// ── Printable-area constants ──────────────────────────────────────────────────
//
// Each rect is the **full printable area** for a placement — the region a
// design at [ImageSize.large] fills exactly. Expressed in normalised (0–1)
// coordinates of the mockup image (800×1066 px). Smaller sizes fill a centred
// fraction of it (see [ImageSize.fillFraction]).
//
// The back area matches Printful's DTG back printfile aspect (12in × 16in =
// 0.75) and is sized/positioned to sit within the garment on the mockup photo,
// deliberately conservative so the preview is never larger than what Printful
// actually prints (M190). The chest badges keep their small footprint.
//   Front left-chest  (wearer's left = viewer's right)
//   Front center      (aspect 0.75, matches the DTG printfile)
//   Front right-chest (wearer's right = viewer's left)
//   Back              (aspect 0.75, matches the DTG printfile)
const _kTshirtFrontLeftChestArea = Rect.fromLTWH(0.55, 0.25, 0.18, 0.25);
const _kTshirtFrontCenterArea = Rect.fromLTWH(0.25, 0.22, 0.50, 0.40);
const _kTshirtFrontRightChestArea = Rect.fromLTWH(0.27, 0.25, 0.18, 0.25);
// Back recalibrated (M190): 0.75 aspect (Printful 12in×16in DTG printfile),
// centred and sized conservatively so the preview is never larger than what
// Printful actually prints. (Front/chest areas left as pre-M190.)
const _kTshirtBackPrintArea = Rect.fromLTWH(0.31, 0.235, 0.38, 0.507);

// Poster: edge-to-edge with a small margin (poster_a4.png has 5% padding on all sides)
const _kPosterPrintArea = Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);

/// Returns the centred sub-rect of [area] scaled by [fraction] (0–1). At
/// `fraction == 1.0` the printable area is returned unchanged; smaller values
/// shrink the artwork bounding box about the centre so it always stays inside
/// the printable area (it can never bleed past it).
Rect scaledPrintArea(Rect area, double fraction) {
  final f = fraction.clamp(0.05, 1.0);
  if (f >= 1.0) return area;
  final w = area.width * f;
  final h = area.height * f;
  return Rect.fromLTWH(
    area.left + (area.width - w) / 2,
    area.top + (area.height - h) / 2,
    w,
    h,
  );
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
  /// [imageSize] chooses how much of the placement's fixed printable area the
  ///   artwork fills (M190): Large fills it exactly (never exceeds it), Medium
  ///   (default) fills most of it, Small is a compact print. For
  ///   [MerchProduct.poster] the size is ignored (posters are edge-to-edge).
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
    final Rect printableArea;
    if (isFront) {
      printableArea = switch (frontPosition) {
        'center' => _kTshirtFrontCenterArea,
        'right_chest' => _kTshirtFrontRightChestArea,
        _ => _kTshirtFrontLeftChestArea, // 'left_chest' + default
      };
    } else {
      printableArea = _kTshirtBackPrintArea;
    }
    final printArea = scaledPrintArea(printableArea, imageSize.fillFraction);
    return ProductMockupSpec(assetPath: assetPath, printAreaNorm: printArea);
  }
}
