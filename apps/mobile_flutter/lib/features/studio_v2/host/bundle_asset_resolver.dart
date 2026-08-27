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
/// Supports the app's bundled flags (`assets/flags/svg/<cc>.svg`) and silhouettes
/// (`assets/silhouettes/<slug>.svg`). Country/continent outline + passport-stamp
/// resolution are deferred to a later milestone (not needed by the M1 shell's
/// flag-grid hero); those lookups are left unset so their masks resolve to null.
AssetResolver createBundleAssetResolver() => SvgFlagResolver(
      (code) => rootBundle.loadString('assets/flags/svg/$code.svg'),
      silhouetteLookup: (slug) =>
          rootBundle.loadString('assets/silhouettes/$slug.svg'),
    );
