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
/// (`assets/silhouettes/<slug>.svg`) and — for the Flags · Map / World Details —
/// country & continent outlines (the same `assets/country_paths/<cc>.json` /
/// `assets/continent_paths/<name>.json` path data the globe map bundles; the Lab
/// feeds `SvgFlagResolver` these exact JSON files). Passport-stamp resolution is
/// still deferred (Passport's default design does not require it), so that lookup
/// is left unset and its mask resolves to null.
AssetResolver createBundleAssetResolver() => SvgFlagResolver(
      (code) => rootBundle.loadString('assets/flags/svg/$code.svg'),
      silhouetteLookup: (slug) =>
          rootBundle.loadString('assets/silhouettes/$slug.svg'),
      countryOutlineLookup: (code) =>
          rootBundle.loadString('assets/country_paths/$code.json'),
      continentOutlineLookup: (name) =>
          rootBundle.loadString('assets/continent_paths/$name.json'),
    );
