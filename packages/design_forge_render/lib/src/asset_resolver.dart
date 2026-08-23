import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

/// Resolves design assets (flags, silhouettes, outline paths) to renderable
/// `dart:ui` objects. Abstracted so the engine core never touches IO or the
/// asset bundle: the macOS Lab, a flutter test, and the mobile app each supply
/// their own resolver (from disk, from `rootBundle`, from a pre-baked atlas).
abstract class AssetResolver {
  /// Rasterise the flag for [code] (ISO-3166-1 alpha-2, lowercase) into a
  /// [ui.Image] of roughly [width]×[height]. Implementations should cache by
  /// (code, size) so batch rendering doesn't re-parse SVGs.
  Future<ui.Image> resolveFlag(
    String code, {
    required int width,
    required int height,
  });

  /// Rasterise an alpha mask for a shape-backed clip ([ClipShape.animalSilhouette]
  /// / `plantSilhouette` / `landmarkSilhouette` / `countryOutline` /
  /// `continentOutline`) into a [width]×[height] image whose opaque pixels are
  /// the shape. [code] identifies the specific asset (silhouette slug or ISO
  /// code). Returns null if this resolver can't supply the mask, so the caller
  /// can fall back (e.g. skip the clip). Default: unsupported.
  Future<ui.Image?> resolveClipMask(
    ClipShape shape,
    String? code, {
    required int width,
    required int height,
  }) async =>
      null;

  /// Build a "passport page" collage from [stamps] (each a country's entry or
  /// exit stamp with an optional trip date), **each filled with its own flag**
  /// and scattered at angles across a [width]×[height] transparent canvas. The
  /// date is drawn onto the stamp at the position from its metadata, exactly like
  /// the real passport t-shirt. Returns a fully-coloured image (not a mask) that
  /// replaces the artwork, or null if the resolver has no stamps. Default: none.
  Future<ui.Image?> resolvePassportCollage(
    List<PassportStampRef> stamps, {
    required int width,
    required int height,
    int seed = 0,
    double scatter = 0.5,
    double stampScale = 1.0,
    PassportInk ink = PassportInk.flag,
  }) async =>
      null;
}

/// One stamp to render: [slug] (e.g. `sc_entry`) + an optional trip [date] label
/// (e.g. `12 MAR 24`) drawn at the stamp's metadata date position.
class PassportStampRef {
  const PassportStampRef(this.slug, [this.date]);
  final String slug;
  final String? date;
}

/// How passport stamps are inked in the collage.
enum PassportInk {
  /// Each stamp filled with its own country's flag (default).
  flag,

  /// Plain solid black ink on transparent — like a real passport stamp.
  black,

  /// Plain solid white ink on transparent (for dark garments).
  white;

  static PassportInk fromId(String? id) {
    for (final v in PassportInk.values) {
      if (v.name == id) return v;
    }
    return PassportInk.flag;
  }
}
