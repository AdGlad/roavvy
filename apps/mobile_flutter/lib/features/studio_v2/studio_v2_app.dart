import 'dart:async';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'commerce/garment_cart_request.dart';
import 'host/bundle_asset_resolver.dart';
import 'host/prefs_persistence.dart';
import 'host/silhouette_inventory.g.dart';
import 'host/studio_v2_trace.dart';
import 'host/travel_context.dart';
import 'studio_v2_screen.dart';

/// The bundled silhouette inventory keyed by [ClipShape], built once from the
/// generated kind manifest. Feeds the generator so the Detail step's Animals /
/// Plants / Landmarks pickers reach the full on-device inventory (159 animals,
/// 2 landmarks; plants require additional bundled art — see the manifest).
Map<ClipShape, List<String>> _bundledSilhouettesByShape() => {
      ClipShape.animalSilhouette:
          kStudioV2SilhouettesByKind['animal'] ?? const [],
      ClipShape.plantSilhouette:
          kStudioV2SilhouettesByKind['plant'] ?? const [],
      ClipShape.landmarkSilhouette:
          kStudioV2SilhouettesByKind['landmark'] ?? const [],
    };

/// Builds a [StudioController] over a supplied [DesignContext], wired to the
/// mobile host adapters: the bundle [AssetResolver] (rootBundle) for rendering,
/// and `shared_preferences`-backed library + preference persistence. The shared
/// `design_studio` / `design_forge` stack is used as-is — nothing is duplicated.
StudioController buildStudioV2ControllerFor(
  DesignContext context, {
  DesignPreferences preferences = DesignPreferences.neutral,
}) {
  final generator = LabShowcaseGenerator(
    silhouettesByShape: _bundledSilhouettesByShape(),
    countryNames: const {},
  );
  final service = RenderService(createBundleAssetResolver());
  final prefsStore = PrefsPreferenceStore();
  return StudioController(
    generator: generator,
    service: service,
    designContext: context,
    initialSeed: 1,
    preferences: preferences,
    library: PersistentDesignLibrary(PrefsDesignStore()),
    savePreferences: (p) => unawaited(prefsStore.save(p)),
  );
}

/// Test/dev convenience: a controller over a fixed demo context (no Riverpod).
/// The real app path uses [StudioV2App], which sources the context from live
/// Roavvy travel data.
StudioController buildStudioV2Controller() => buildStudioV2ControllerFor(
      const DesignContext(
        flagCodes: ['us', 'fr', 'jp', 'br', 'au', 'it', 'gr', 'th'],
        scopeKey: 'studio_v2:demo',
      ),
    );

/// The developer-only V2 app root. Launched independently of production V1 via
/// `--dart-define=STUDIO_V2=true` (see `main.dart`) or the dedicated entrypoint
/// `lib/main_studio_v2.dart`, always under a [ProviderScope]. It never touches
/// the V1 flow.
///
/// M2: the controller is built once from REAL Roavvy travel data ([tripListProvider]
/// → [Trip] → [DesignContext.fromTrips], with the flat visited-country list as the
/// no-dated-trips fallback), and saved Studio preferences are loaded on open.
class StudioV2App extends ConsumerStatefulWidget {
  const StudioV2App({super.key, this.onAddToCart});

  /// Host-injected bridge to the existing merch cart/checkout flow (Review →
  /// Add to cart). Passed straight through to [StudioV2Screen]; the App itself
  /// stays isolated from `features/merch` — only the top-level entrypoint knows
  /// the concrete adapter. Null-safe: dev builds without it simply have no cart.
  final AddToCartCallback? onAddToCart;

  @override
  ConsumerState<StudioV2App> createState() => _StudioV2AppState();
}

class _StudioV2AppState extends ConsumerState<StudioV2App> {
  StudioController? _controller;
  DesignPreferences? _prefs;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await PrefsPreferenceStore().load();
    if (mounted) {
      setState(() {
        _prefs = p;
        _prefsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripListProvider);
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    final trips = tripsAsync.valueOrNull;
    final visits = visitsAsync.valueOrNull;

    // The studio must OPEN even when travel data is unavailable — e.g. a dev
    // entrypoint launched without the `roavvyDatabaseProvider` override, where
    // `tripListProvider` throws and `.valueOrNull` silently yields null. Waiting
    // for `trips != null` in that case hangs forever on a blank spinner (with no
    // visible exception, because the error was swallowed). Instead, once prefs
    // are loaded, treat a SETTLED trips provider — data OR error — as ready and
    // fall back to visited/demo codes; only a still-loading provider waits.
    if (tripsAsync.hasError) {
      v2trace('tripListProvider ERROR (using fallback context): '
          '${tripsAsync.error}');
    }
    final ready = _prefsLoaded && !tripsAsync.isLoading;
    v2bump('StudioV2App.build',
        detail: 'ready=$ready ctrl=${_controller != null} '
            'tripsLoading=${tripsAsync.isLoading} tripsErr=${tripsAsync.hasError} '
            'trips=${trips?.length} visits=${visits?.length}');

    if (ready && _controller == null) {
      final ctx = StudioV2TravelContext.build(
        trips: trips ?? const [],
        visitedCodes: [for (final v in (visits ?? const [])) v.countryCode],
      );
      v2trace('creating controller: flagCodes=${ctx.flagCodes.length} '
          'trips=${ctx.trips.length} prefsSamples=${_prefs?.sampleCount ?? 0}');
      _controller = buildStudioV2ControllerFor(
        ctx,
        preferences: _prefs ?? DesignPreferences.neutral,
      );
      v2trace('controller ready: heroRecipeId=${_controller!.current.recipeId} '
          'family=${_controller!.current.composition.family.name} '
          'flagsInRecipe=${_controller!.current.content.flags.length}');
    }

    return MaterialApp(
      title: 'Roavvy Studio V2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _controller == null
          ? const Scaffold(
              backgroundColor: Color(0xFF0E0F12),
              body: Center(child: CircularProgressIndicator()),
            )
          : StudioV2Screen(
              controller: _controller!, onAddToCart: widget.onAddToCart),
    );
  }
}
