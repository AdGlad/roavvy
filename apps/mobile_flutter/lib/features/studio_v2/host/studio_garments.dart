import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../../shared/garment_mockup/garment_mockup_spec.dart';
import '../../shared/garment_mockup/garment_tint.dart';

/// Turns a Studio garment colour into a renderable shirt.
///
/// The Studio's palette (Black, White, Navy, Grey, Sand, Olive) is wider than
/// the bundled photography (Black, White, Blue, Grey, Red), and three of its
/// colours have no photograph at all. Rather than mapping Olive onto a grey
/// shirt and calling it close enough, every colour is produced by recolouring
/// one neutral garment to the exact hex — so what you pick is what you see, and
/// adding a seventh colour later needs no new asset.
///
/// Recoloured garments are cached by colour for the session: the pixel pass is
/// cheap but not free, and the Studio re-renders on every design change.
abstract final class StudioGarments {
  /// Default garment when a recipe carries no colour — the Studio's first
  /// palette entry (Black).
  static const defaultColour = ui.Color(0xFF1F2B33);

  static final Map<String, Future<ui.Image>> _cache = {};

  /// The mockup spec for a Studio [garmentColour] (a `#RRGGBB` hex) and face.
  static GarmentMockupSpec specFor({
    required String? garmentColour,
    required bool front,
  }) => BundledGarments.tshirt(
    colour: parseHex(garmentColour) ?? defaultColour,
    front: front,
  );

  /// Loads the garment layer for [spec] — the neutral shirt photo recoloured to
  /// the spec's tint, with the studio backdrop removed so the shirt sits on the
  /// Studio's dark hero rather than on a white card.
  static Future<ui.Image> load(GarmentMockupSpec spec) =>
      _cache.putIfAbsent(spec.garmentKey, () async {
        final data = await rootBundle.load(spec.assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final source = (await codec.getNextFrame()).image;
        final tint = spec.tintColour;
        final out =
            tint == null
                ? await GarmentTint.cutout(source)
                : await GarmentTint.recolour(source, tint);
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
  }
}
