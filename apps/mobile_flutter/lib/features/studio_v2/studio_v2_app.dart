import 'dart:async';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'commerce/garment_cart_request.dart';
import 'host/bundle_asset_resolver.dart';
import 'host/passport_stamp_inventory.g.dart';
import 'host/prefs_persistence.dart';
import 'host/silhouette_inventory.g.dart';
import 'host/studio_v2_trace.dart';
import 'host/travel_context.dart';
import 'studio_v2_screen.dart';

/// The bundled shape inventory keyed by [ClipShape], built once from the
/// generated manifests. Feeds the generator so the Detail step's Animals /
/// Plants / Landmarks pickers reach the full on-device inventory (159 animals,
/// 2 landmarks; plants require additional bundled art — see the manifest), and
/// so the **Passport** direction sees the bundled real entry/exit stamps —
/// without that inventory its subjects are unavailable and Passport degrades
/// into a plain flag design.
Map<ClipShape, List<String>> _bundledSilhouettesByShape() => {
  ClipShape.animalSilhouette: kStudioV2SilhouettesByKind['animal'] ?? const [],
  ClipShape.plantSilhouette: kStudioV2SilhouettesByKind['plant'] ?? const [],
  ClipShape.landmarkSilhouette:
      kStudioV2SilhouettesByKind['landmark'] ?? const [],
  ClipShape.passportStampOutline: kStudioV2PassportStampSlugs,
};

/// Builds a [StudioController] over a supplied [DesignContext], wired to the
/// mobile host adapters: the bundle [AssetResolver] (rootBundle) for rendering,
/// and `shared_preferences`-backed library + preference persistence. The shared
/// `design_studio` / `design_forge` stack is used as-is — nothing is duplicated.
StudioController buildStudioV2ControllerFor(
  DesignContext context, {
  DesignPreferences preferences = DesignPreferences.neutral,
  Set<String> unavailableGarments = const {},
  PersistentDesignLibrary? library,
}) {
  final generator = LabShowcaseGenerator(
    silhouettesByShape: _bundledSilhouettesByShape(),
    countryNames: const {},
  );
  final service = RenderService(createBundleAssetResolver());
  final prefsStore = PrefsPreferenceStore();
  // Building a controller stays pure: it creates the wardrobe but never reads
  // it. Reading is disk work with its own failure modes, and it belongs to
  // whoever owns the app lifecycle — [StudioV2App] hands in a library it has
  // already loaded (see [openDesignLibrary]).
  return StudioController(
    generator: generator,
    service: service,
    designContext: context,
    initialSeed: 1,
    preferences: preferences,
    unavailableGarments: unavailableGarments,
    library: library ?? PersistentDesignLibrary(PrefsDesignStore()),
    savePreferences:
        (p) => unawaited(_ignoringFailure(() => prefsStore.save(p))),
  );
}

/// The saved-designs wardrobe, read back off disk.
///
/// Nothing read it, so every restart quietly started from an empty wardrobe —
/// designs were being written to a file no one opened. A wardrobe that cannot
/// be read is an empty wardrobe, never a Studio that fails to open, so a
/// failed read is discarded rather than propagated.
Future<PersistentDesignLibrary> openDesignLibrary() async {
  final library = PersistentDesignLibrary(PrefsDesignStore());
  await _ignoringFailure(library.load);
  return library;
}

/// Runs [work], discarding any failure.
///
/// Persistence here is a convenience, never a precondition: a wardrobe that
/// cannot be read is an empty wardrobe and preferences that cannot be written
/// are preferences not learned — neither is a reason for the Studio to fail to
/// open. Unguarded, these surface as unhandled async errors that land on
/// whatever is running when the write fails, which in tests means an unrelated
/// case fails after it has already passed.
Future<void> _ignoringFailure(Future<void> Function() work) async {
  try {
    await work();
  } catch (_) {
    // Deliberately swallowed — see above.
  }
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
  const StudioV2App({
    super.key,
    this.onAddToCart,
    this.unavailableGarments = const {},
  });

  /// Garment colours the store cannot currently fulfil, supplied by the
  /// entrypoint (the only layer that may know both the Studio and commerce).
  /// The Studio shows them, marked unavailable, rather than pretending.
  final Set<String> unavailableGarments;

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
  PersistentDesignLibrary? _library;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  /// Everything persisted between sessions: what the Studio has learned, and
  /// the designs already saved. Both are read before the controller exists, so
  /// it opens with them rather than acquiring them later.
  Future<void> _loadSaved() async {
    final p = await PrefsPreferenceStore().load();
    final lib = await openDesignLibrary();
    if (mounted) {
      setState(() {
        _prefs = p;
        _library = lib;
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

    if (tripsAsync.hasError) {
      v2trace(
        'tripListProvider ERROR (using fallback context): '
        '${tripsAsync.error}',
      );
    }
    final ready = _prefsLoaded && !tripsAsync.isLoading;
    v2bump(
      'StudioV2App.build',
      detail:
          'ready=$ready ctrl=${_controller != null} '
          'tripsLoading=${tripsAsync.isLoading} tripsErr=${tripsAsync.hasError} '
          'trips=${trips?.length} visits=${visits?.length}',
    );

    if (ready && _controller == null) {
      final ctx = StudioV2TravelContext.build(
        trips: trips ?? const [],
        visitedCodes: [for (final v in (visits ?? const [])) v.countryCode],
      );
      v2trace(
        'creating controller: flagCodes=${ctx.flagCodes.length} '
        'trips=${ctx.trips.length} prefsSamples=${_prefs?.sampleCount ?? 0}',
      );
      _controller = buildStudioV2ControllerFor(
        ctx,
        preferences: _prefs ?? DesignPreferences.neutral,
        unavailableGarments: widget.unavailableGarments,
        library: _library,
      );
      v2trace(
        'controller ready: heroRecipeId=${_controller!.current.recipeId} '
        'family=${_controller!.current.composition.family.name} '
        'flagsInRecipe=${_controller!.current.content.flags.length}',
      );
    }

    const accent = Color(0xFFE84C22);
    final colourScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF0E0F12),
    ).copyWith(
      primary: accent,
      secondary: accent,
      surface: const Color(0xFF0E0F12),
    );

    return MaterialApp(
      title: 'Roavvy Studio V2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: colourScheme,
        scaffoldBackgroundColor: const Color(0xFF0E0F12),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E0F12),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accent,
          thumbColor: accent,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      ),
      home:
          _controller == null
              ? const Scaffold(
                backgroundColor: Color(0xFF0E0F12),
                body: Center(child: CircularProgressIndicator()),
              )
              : StudioV2Screen(
                controller: _controller!,
                onAddToCart: widget.onAddToCart,
              ),
    );
  }
}
