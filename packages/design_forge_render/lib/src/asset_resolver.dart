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
}
