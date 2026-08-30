import 'dart:convert';
import 'dart:typed_data';

import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Mobile-safe [AssetResolver] for the Studio V2 render pipeline.
///
/// Unlike the macOS Lab's repo-disk `FlagSource`, this reads the app's **bundled**
/// assets via Flutter `rootBundle` — so there is NO repo-filesystem dependency on
/// device. It plugs into the same injection seam M0 established: the shared
/// `design_studio` / `design_forge_render` stack only knows the [AssetResolver]
/// interface; this host supplies the platform loading.
///
/// Supports the app's bundled flags (`assets/flags/svg/<cc>.svg`), silhouettes
/// (`assets/silhouettes/<slug>.svg`), country & continent outlines (the same
/// `assets/country_paths/<cc>.json` / `assets/continent_paths/<name>.json` path
/// data the globe map bundles) and the real passport entry/exit stamps
/// (`assets/mobile_png/` + `assets/mobile_meta/`, see [BundledPassportStamps]) —
/// the artwork the Passport direction is built from.
AssetResolver createBundleAssetResolver() {
  final stamps = BundledPassportStamps();
  return SvgFlagResolver(
    (code) => rootBundle.loadString('assets/flags/svg/$code.svg'),
    silhouetteLookup:
        (slug) => rootBundle.loadString('assets/silhouettes/$slug.svg'),
    countryOutlineLookup:
        (code) => rootBundle.loadString('assets/country_paths/$code.json'),
    continentOutlineLookup:
        (name) => rootBundle.loadString('assets/continent_paths/$name.json'),
    passportStampLookup: stamps.png,
    passportMetaLookup: stamps.meta,
  );
}

/// Loads the bundled real passport-stamp artwork by renderer slug.
///
/// The renderer addresses stamps as `<cc>_<entry|exit>` (e.g. `au_entry`); the
/// app's bundle indexes them through `assets/mobile_meta/stamp_manifest.json`,
/// which maps `AU-entry` → a filename base (`australia-au-entry`). The base's
/// JSON carries the date-overlay spec AND the PNG's real filename (a few stamps
/// deliberately share one PNG), so the PNG is always resolved via the metadata
/// rather than assumed from the base. Manifest and metadata are cached, so a
/// batch render parses each at most once.
class BundledPassportStamps {
  BundledPassportStamps();

  static const _manifestPath = 'assets/mobile_meta/stamp_manifest.json';
  static const _metaDir = 'assets/mobile_meta/';
  static const _pngDir = 'assets/mobile_png/';

  Future<Map<String, String>>? _manifest;
  final Map<String, Future<String>> _metaCache = {};

  /// `au_entry` → `AU-entry`, the manifest key. Null for a malformed slug.
  static String? manifestKey(String slug) {
    final i = slug.lastIndexOf('_');
    if (i <= 0) return null;
    final dir = slug.substring(i + 1).toLowerCase();
    if (dir != 'entry' && dir != 'exit') return null;
    return '${slug.substring(0, i).toUpperCase()}-$dir';
  }

  Future<Map<String, String>> _loadManifest() =>
      _manifest ??= rootBundle
          .loadString(_manifestPath)
          .then((raw) => (jsonDecode(raw) as Map).cast<String, String>());

  /// The stamp's JSON metadata (date position/font + PNG filename).
  /// Throws when the bundle has no stamp for [slug].
  Future<String> meta(String slug) async {
    final key = manifestKey(slug);
    final base = key == null ? null : (await _loadManifest())[key];
    if (base == null) throw StateError('no bundled passport stamp for $slug');
    return _metaCache.putIfAbsent(
      base,
      () => rootBundle.loadString('$_metaDir$base.json'),
    );
  }

  /// The stamp's PNG bytes (ink on transparent).
  /// Throws when the bundle has no stamp for [slug].
  Future<Uint8List> png(String slug) async {
    final json = jsonDecode(await meta(slug)) as Map<String, dynamic>;
    final name = json['png_asset'] as String;
    final data = await rootBundle.load('$_pngDir$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
