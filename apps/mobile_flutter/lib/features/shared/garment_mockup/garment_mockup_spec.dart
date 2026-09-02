import 'package:flutter/widgets.dart';

/// What the garment-mockup renderer needs to know to composite a design onto a
/// garment: which photo, where the printable area sits on it, and where the
/// fabric shading comes from.
///
/// Deliberately free of any commerce vocabulary (no product, no print size, no
/// Printful geometry) so both the V1 merch flow and Studio V2 can share one
/// renderer without either importing the other. Callers layer their own domain
/// on top — `ProductMockupSpec` adds the merch registry, Studio V2 picks from
/// [BundledGarments].
@immutable
class GarmentMockupSpec {
  const GarmentMockupSpec({
    required this.assetPath,
    required this.printAreaNorm,
    this.srcRectNorm,
    this.shadowMapAssetPath,
    this.tintColour,
  });

  /// Flutter asset path of the garment photo (must be declared in pubspec).
  final String assetPath;

  /// Printable area in normalised (0–1) coordinates of the effective (post-crop)
  /// garment image, `Rect.fromLTWH` semantics.
  final Rect printAreaNorm;

  /// Optional source crop of [assetPath], normalised. Null uses the whole image.
  final Rect? srcRectNorm;

  /// Optional greyscale fabric shadow/wrinkle map bundled alongside the garment
  /// photo. Null means the photo's own luminance supplies the folds.
  final String? shadowMapAssetPath;

  /// When set, the garment is recoloured to this exact colour: its backdrop is
  /// removed, its luminance normalised, and the result multiplied by this
  /// colour, so the folds survive and the shirt reads as precisely this hex.
  ///
  /// This is what lets a palette offer colours no photograph exists for.
  final Color? tintColour;

  /// The image whose luminance supplies the fabric shading pass.
  String get shadingAssetPath => shadowMapAssetPath ?? assetPath;

  /// A cache key that distinguishes every visually distinct garment layer.
  String get garmentKey =>
      tintColour == null
          ? assetPath
          : '$assetPath#${tintColour!.toARGB32().toRadixString(16)}';

  GarmentMockupSpec withTint(Color? colour) => GarmentMockupSpec(
    assetPath: assetPath,
    printAreaNorm: printAreaNorm,
    srcRectNorm: srcRectNorm,
    shadowMapAssetPath: shadowMapAssetPath,
    tintColour: colour,
  );
}

/// The bundled garment photography and its printable geometry — one source of
/// truth shared by the merch registry and Studio V2, so the two can never drift
/// apart about where a design actually prints.
abstract final class BundledGarments {
  /// Per-colour t-shirt photos. Keys are the photographed colours; palettes with
  /// more colours than this should tint [tintBase] instead of mapping onto a
  /// near-miss photo.
  static const tshirtFront = <String, String>{
    'Black': 'assets/mockups/Black-tshirt-front.jpeg',
    'White': 'assets/mockups/White-tshirt-front.jpg',
    'Blue': 'assets/mockups/Blue-tshirt-front.jpeg',
    'Grey': 'assets/mockups/Grey-tshirt-front.jpeg',
    'Red': 'assets/mockups/Red-tshirt-front.jpeg',
  };

  static const tshirtBack = <String, String>{
    'Black': 'assets/mockups/Black-tshirt-back.jpeg',
    'White': 'assets/mockups/White-tshirt-back.jpg',
    'Blue': 'assets/mockups/Blue-tshirt-back.jpeg',
    'Grey': 'assets/mockups/Grey-tshirt-back.jpeg',
    'Red': 'assets/mockups/Red-tshirt-back.jpeg',
  };

  /// The photos used as the neutral base for tinting. The white shirt carries
  /// the fullest fold detail (a black shirt's shadows crush), so it recolours to
  /// any hue most faithfully.
  static const tintBaseFront = 'assets/mockups/White-tshirt-front.jpg';
  static const tintBaseBack = 'assets/mockups/White-tshirt-back.jpg';

  /// Full printable areas, normalised to the garment photo. A design at the
  /// largest print size fills these exactly; smaller sizes fill a centred
  /// fraction. Calibrated against Printful's real DTG geometry (see the merch
  /// registry for the derivation).
  static const frontLeftChestArea = Rect.fromLTWH(0.55, 0.25, 0.18, 0.25);
  static const frontCenterArea = Rect.fromLTWH(0.25, 0.22, 0.50, 0.40);
  static const frontRightChestArea = Rect.fromLTWH(0.27, 0.25, 0.18, 0.25);
  static const backPrintArea = Rect.fromLTWH(0.29, 0.10, 0.42, 0.56);

  static const posterAsset = 'assets/mockups/poster_a4.png';
  static const posterPrintArea = Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);

  /// A t-shirt spec for [colour], recoloured when the palette has no photograph
  /// of it. [front] picks the face; [printArea] defaults to the face's main
  /// print region.
  static GarmentMockupSpec tshirt({
    required Color colour,
    bool front = true,
    Rect? printArea,
  }) {
    final base = front ? tintBaseFront : tintBaseBack;
    return GarmentMockupSpec(
      assetPath: base,
      printAreaNorm: printArea ?? (front ? frontCenterArea : backPrintArea),
      tintColour: colour,
    );
  }
}
