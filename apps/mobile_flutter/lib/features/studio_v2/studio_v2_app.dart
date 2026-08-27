import 'dart:async';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'host/bundle_asset_resolver.dart';
import 'host/prefs_persistence.dart';
import 'studio_v2_screen.dart';

/// Builds a [StudioController] wired to the mobile host adapters: the bundle
/// [AssetResolver] (rootBundle) for rendering, and `shared_preferences`-backed
/// library + preference persistence. The shared `design_studio` / `design_forge`
/// stack is used as-is — nothing is duplicated here.
///
/// M1 seeds a demo travel context so a REAL design renders immediately; live
/// travel selection is M2.
StudioController buildStudioV2Controller() {
  final generator = LabShowcaseGenerator(
    silhouettesByShape: {for (final s in ClipShape.values) s: const <String>[]},
    countryNames: const {},
  );
  final service = RenderService(createBundleAssetResolver());
  const context = DesignContext(
    flagCodes: ['us', 'fr', 'jp', 'br', 'au', 'it', 'gr', 'th'],
    scopeKey: 'studio_v2:demo',
  );
  final prefs = PrefsPreferenceStore();
  return StudioController(
    generator: generator,
    service: service,
    designContext: context,
    initialSeed: 1,
    library: PersistentDesignLibrary(PrefsDesignStore()),
    savePreferences: (p) => unawaited(prefs.save(p)),
  );
}

/// The developer-only V2 app root. Launched independently of production V1 via
/// `--dart-define=STUDIO_V2=true` (see `main.dart`) or the dedicated entrypoint
/// `lib/main_studio_v2.dart`. It never touches the V1 flow.
class StudioV2App extends StatefulWidget {
  const StudioV2App({super.key});

  @override
  State<StudioV2App> createState() => _StudioV2AppState();
}

class _StudioV2AppState extends State<StudioV2App> {
  late final StudioController _controller = buildStudioV2Controller();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roavvy Studio V2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: StudioV2Screen(controller: _controller),
    );
  }
}
