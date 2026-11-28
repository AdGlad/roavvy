import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Rect;

import 'garment_mockup_spec.dart';
import 'garment_tint.dart';

/// Turns a Studio garment colour into a renderable shirt.
///
/// The Studio's palette is the eight colourways the shirt is actually stocked
/// in (see `StudioController.garments`), which is wider than the bundled
/// photography and does not line up with it. Rather than mapping a colour onto
/// the nearest photographed shirt and calling it close enough, every colour is
/// produced by recolouring one neutral garment to the exact hex — so what you
/// pick is what you see, and adding a ninth colour later needs no new asset.
///
/// Recoloured garments are cached by colour for the session: the pixel pass is
/// cheap but not free, and the Studio re-renders on every design change.
abstract final class StudioGarments {
  /// Default garment when a recipe carries no colour — the Studio's first
  /// palette entry (Black).
  static const defaultColour = ui.Color(0xFF0E0E0E);

  /// Reads a garment asset's bytes by its asset path (`assets/mockups/…`).
  ///
  /// The app bundles the photography, so the default reads the asset bundle.
  /// The macOS Design Lab has no copy of its own: it points this at the
  /// mobile app's `assets/` folder on disk, so both hosts show the SAME photos
  /// through the same tint, shading and fabric-print code.
  static Future<Uint8List> Function(String assetPath) loadBytes =
      _bundleBytes;

  static Future<Uint8List> _bundleBytes(String path) async =>
      (await rootBundle.load(path)).buffer.asUint8List();

  static final Map<String, Future<ui.Image>> _cache = {};
  static final Map<String, Future<ui.Image>> _shadingCache = {};

  /// The mockup spec for a Studio [garmentColour] (a `#RRGGBB` hex) and face.
  ///
  /// [printArea] places the artwork on the garment — the Studio's front print
  /// moves between left chest, right chest and full front, so the preview has
  /// to follow it rather than always centring. Null uses the face's default
  /// region.
  static GarmentMockupSpec specFor({
    required String? garmentColour,
    required bool front,
    Rect? printArea,
  }) => BundledGarments.tshirt(
    colour: parseHex(garmentColour) ?? defaultColour,
    front: front,
    printArea: printArea,
  );

  /// Loads the garment layer for [spec] — the neutral shirt photo recoloured to
  /// the spec's tint, with the studio backdrop removed so the shirt sits on the
  /// Studio's dark hero rather than on a white card.
  static Future<ui.Image> load(GarmentMockupSpec spec) =>
      _cache.putIfAbsent(spec.garmentKey, () async {
        final codec = await ui.instantiateImageCodec(
          await loadBytes(spec.assetPath),
        );
        final source = (await codec.getNextFrame()).image;
        final tint = spec.tintColour;
        final out =
            tint == null
                ? await GarmentTint.cutout(source)
                : await GarmentTint.recolour(source, tint);
        source.dispose();
        return out;
      });

  /// Loads the *fold* layer for [spec] — the photograph reduced to a
  /// [GarmentTint.luminanceMap].
  ///
  /// The shading pass exists to lay the fabric's folds back over the ink, and a
  /// fold is a luminance, not a colour. Feeding it the tinted garment instead
  /// hands the print the shirt's own dye: on a red shirt the flags wash out
  /// pink and the lettering all but disappears. Cached by
  /// [GarmentMockupSpec.shadingAssetPath], so all six colours share one entry —
  /// the folds are a property of the photograph, not of the tint.
  static Future<ui.Image> loadShading(GarmentMockupSpec spec) =>
      _shadingCache.putIfAbsent(spec.shadingAssetPath, () async {
        final codec = await ui.instantiateImageCodec(
          await loadBytes(spec.shadingAssetPath),
        );
        final source = (await codec.getNextFrame()).image;
        final out = await GarmentTint.luminanceMap(source);
        source.dispose();
        return out;
      });

  /// `#RRGGBB` / `#AARRGGBB` → colour. Null for null or malformed input, so a
  /// bad value falls back to the default rather than crashing the preview.
  static ui.Color? parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'ff$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : ui.Color(v);
  }

  /// Releases every cached garment layer.
  static void evict() {
    for (final f in _cache.values) {
      f.then((img) => img.dispose()).ignore();
    }
    _cache.clear();
    for (final f in _shadingCache.values) {
      f.then((img) => img.dispose()).ignore();
    }
    _shadingCache.clear();
  }
}
