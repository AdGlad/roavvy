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

/// Opens ONE Studio session from a [StudioContext].
///
/// The single entry point across the boundary: production hands in real Roavvy
/// travel, the standalone entrypoints hand in fixtures, and from here on there
/// is one Studio. Hosts call this once per session — a session is expensive
/// (it generates the opening designs) and re-creating one silently throws away
/// whatever the customer has done.
StudioController openStudioSession(
  StudioContext studio, {
  DesignPreferences preferences = DesignPreferences.neutral,
  Set<String> unavailableGarments = const {},
  PersistentDesignLibrary? library,
}) {
  final c = buildStudioV2ControllerFor(
    studio.toDesignContext(),
    preferences: preferences,
    unavailableGarments: unavailableGarments,
    library: library,
  );
  // A session opens on everything travelled unless the host says otherwise.
  if (studio.initialSelection.isNotEmpty) {
    c.setSelectedCountries(studio.initialSelection);
  }
  return c;
}

/// Test/dev convenience: a controller over the fixed demo context (no Riverpod).
/// The real app path goes through [StudioV2App], which sources its context from
/// live Roavvy travel data — but both arrive here through [StudioContext].
StudioController buildStudioV2Controller() =>
    openStudioSession(demoStudioContext);

/// The stand-in travel history for dev and test runs.
///
/// The trips are DATED, and deliberately so: a simulator has no photo library
/// to scan, so without them the Studio falls back to an undated country list —
/// and every part of the app that depends on when someone travelled, the year
/// range above all, silently disappears. A dev build that cannot show half the
/// screen is not much of a test bed.
///
/// Marked [StudioTravelSource.fixture] so nothing can mistake it for a real
/// traveller's history: production never falls back to this.
final StudioContext demoStudioContext = StudioContext(
  trips: [
    for (final (cc, year) in const [
      ('us', 2016),
      ('fr', 2017),
      ('it', 2018),
      ('gr', 2019),
      ('jp', 2021),
      ('th', 2022),
      ('au', 2023),
      ('br', 2024),
    ])
      Trip(
        countryCode: cc,
        startedOn: DateTime(year, 6, 1),
        endedOn: DateTime(year, 6, 12),
        photoCount: 40,
      ),
  ],
  countryCodes: const ['us', 'fr', 'it', 'gr', 'jp', 'th', 'au', 'br'],
  scopeKey: 'studio_v2:demo',
  source: StudioTravelSource.fixture,
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
    this.priceLabel,
    this.studioContext,
    this.embedded = false,
  });

  /// The travel this session is built on. Null means "ask the app" — the
  /// production path, which maps live Roavvy travel through
  /// [StudioV2TravelContext.fromRoavvy]. Supplying one is how the standalone
  /// entrypoints and the tests run the SAME Studio on fixtures.
  final StudioContext? studioContext;

  /// True when the Studio is pushed as a route inside the running Roavvy app
  /// rather than being the app.
  ///
  /// It then must NOT wrap itself in a second [MaterialApp]: a nested one
  /// installs its own root Navigator, and the Studio's way out — the close
  /// button on Instant, which appears only when the navigator it is standing
  /// on can pop — disappears, stranding the customer in the Studio. Embedded,
  /// it styles itself with a [Theme] and leaves navigation to the host.
  final bool embedded;

  /// The store's price for a tee, from the host's own pricing source. The
  /// Studio may not import the merch feature, so this arrives the same way the
  /// cart callback does. Null means the store has not said, and Review says so
  /// rather than inventing a number.

  /// Garment colours the store cannot currently fulfil, supplied by the
  /// entrypoint (the only layer that may know both the Studio and commerce).
  /// The Studio shows them, marked unavailable, rather than pretending.
  final Set<String> unavailableGarments;

  /// Host-injected bridge to the existing merch cart/checkout flow (Review →
  /// Add to cart). Passed straight through to [StudioV2Screen]; the App itself
  /// stays isolated from `features/merch` — only the top-level entrypoint knows
  /// the concrete adapter. Null-safe: dev builds without it simply have no cart.
  final AddToCartCallback? onAddToCart;

  final String? priceLabel;

  @override
  ConsumerState<StudioV2App> createState() => _StudioV2AppState();
}

class _StudioV2AppState extends ConsumerState<StudioV2App> {
  StudioController? _controller;
  StudioContext? _studio;

  /// True when the app could not read its own travel at all — a different
  /// thing from a traveller who has not been anywhere yet.
  bool _travelUnavailable = false;
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

  /// The travel this session opens on: whatever the host injected, or the live
  /// app's own. Watching the providers is skipped entirely for an injected
  /// context, so a standalone or test host needs no Roavvy data at all.
  StudioContext? _resolveContext() {
    final injected = widget.studioContext;
    if (injected != null) return injected;

    final tripsAsync = ref.watch(tripListProvider);
    final visitsAsync = ref.watch(effectiveVisitsProvider);
    if (tripsAsync.isLoading || visitsAsync.isLoading) return null;
    if (tripsAsync.hasError || visitsAsync.hasError) {
      v2trace(
        'travel read FAILED: ${tripsAsync.error ?? visitsAsync.error}',
      );
      // A failed read is not an empty history, and must not be reported as
      // one: "you have not travelled" is a different sentence from "we could
      // not look".
      _travelUnavailable =
          tripsAsync.valueOrNull == null && visitsAsync.valueOrNull == null;
    }
    return StudioV2TravelContext.fromRoavvy(
      trips: tripsAsync.valueOrNull ?? const [],
      visits: visitsAsync.valueOrNull ?? const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final studio = _studio ?? _resolveContext();
    final ready = _prefsLoaded && studio != null;
    v2bump(
      'StudioV2App.build',
      detail:
          'ready=$ready ctrl=${_controller != null} '
          'source=${studio?.source.name} dated=${studio?.isDated} '
          'countries=${studio?.countryCodes.length}',
    );

    if (ready && _studio == null) _studio = studio;
    if (ready && _controller == null && studio.hasTravel) {
      v2trace(
        'opening session: countries=${studio.countryCodes.length} '
        'trips=${studio.trips.length} years=${studio.yearRange} '
        'prefsSamples=${_prefs?.sampleCount ?? 0}',
      );
      _controller = openStudioSession(
        studio,
        preferences: _prefs ?? DesignPreferences.neutral,
        unavailableGarments: widget.unavailableGarments,
        library: _library,
      );
      v2trace(
        'session ready: heroRecipeId=${_controller!.current.recipeId} '
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

    final theme = ThemeData.dark(useMaterial3: true).copyWith(
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
    );

    final Widget home;
    if (_controller != null) {
      home = StudioV2Screen(
        controller: _controller!,
        onAddToCart: widget.onAddToCart,
        priceLabel: widget.priceLabel,
      );
    } else if (ready && !studio.hasTravel) {
      // Nothing travelled. The Studio has nothing to make a shirt out of, and
      // the one thing it must not do is fill the gap with countries somebody
      // has never been to — every design here is a claim about where its
      // wearer has been.
      home = _NothingTravelledYet(couldNotRead: _travelUnavailable);
    } else {
      home = const Scaffold(
        backgroundColor: Color(0xFF0E0F12),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Embedded, the host already owns the MaterialApp — and its Navigator is
    // what the Studio's exit pops back onto.
    return widget.embedded
        ? Theme(data: theme, child: home)
        : MaterialApp(
          title: 'Roavvy Studio V2',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: home,
        );
  }
}

/// Shown when the traveller has no discovered travel at all.
///
/// Not an error: the Studio works, there is simply nothing to put on a shirt
/// yet. It says so and points back at the thing that fixes it, rather than
/// opening on invented countries.
class _NothingTravelledYet extends StatelessWidget {
  const _NothingTravelledYet({this.couldNotRead = false});

  /// True when the travel read itself failed, rather than coming back empty.
  final bool couldNotRead;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              key: const Key('v2-no-travel'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  couldNotRead
                      ? Icons.cloud_off_outlined
                      : Icons.travel_explore_outlined,
                  size: 48,
                  color: Colors.white38,
                ),
                const SizedBox(height: 20),
                Text(
                  couldNotRead ? 'Travels unavailable' : 'No travels yet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  couldNotRead
                      ? "Roavvy couldn't read your travel history just now. "
                          'Head back and open the Studio again in a moment.'
                      : 'Scan your photos to find the countries you have been '
                          'to, and the Studio will design a shirt out of them.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                if (canPop) ...[
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('v2-no-travel-close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back to Roavvy'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
