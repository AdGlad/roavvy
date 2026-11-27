import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart'
    show EffectiveVisitedCountry, TripRecord;

import '../../../core/country_names.dart';
import '../../../core/providers.dart';
import '../../studio_v2/commerce/garment_cart_request.dart';
import '../../studio_v2/host/bundle_asset_resolver.dart';
import '../../studio_v2/host/travel_context.dart';
import '../studio_v2_cart_adapter.dart';

/// The Torn Flag tee: one ready-made shirt per visited country (M200).
///
/// The design is not generated here. It is the hero of the `torn_flag`
/// Signature pack (ADR-181) — the recipe the owner tuned and approves in the
/// Design Lab — resolved for a country by [SignatureResolver.hero]. This file
/// is the app's whole view of it: where the pack comes from, which recipe a
/// country gets, which shirts it can be ordered on, and how an order is
/// handed to the existing Studio V2 cart.
///
/// Every consumer sits behind the commerce seam (`CommerceEntry`), so none of
/// these providers is ever read in a commerce-off build.

/// The Signature pack id of the torn flag.
const String kTornFlagPackId = 'torn_flag';

/// The bundled Signature packs, or null when they cannot be read.
///
/// [SignatureCatalog.load] drops `draft` packs in release builds, so until the
/// owner approves torn_flag in the Lab a release build simply has no tee — and
/// every tee surface hides itself rather than showing a broken card.
final signatureCatalogProvider = FutureProvider<SignatureCatalog?>((ref) async {
  try {
    return await SignatureCatalog.load(rootBundle.loadString);
  } catch (_) {
    return null;
  }
});

/// The torn-flag pack, once loaded. Null while loading or when unavailable.
final tornFlagPackProvider = Provider<SignatureRecipe?>(
  (ref) =>
      ref.watch(signatureCatalogProvider).valueOrNull?.byId(kTornFlagPackId),
);

/// The torn-flag design for a country (any case ISO alpha-2), or null when
/// there is no pack or the pack cannot produce one.
final tornFlagRecipeProvider = Provider.family<DesignRecipe?, String>((
  ref,
  countryCode,
) {
  final pack = ref.watch(tornFlagPackProvider);
  if (pack == null || countryCode.length != 2) return null;
  try {
    return SignatureResolver.hero(pack, countryCode.toLowerCase());
  } catch (_) {
    return null;
  }
});

/// Renders tee previews. One for the whole app so every surface shares the
/// [RenderService] image cache — a country rendered on the celebration is not
/// rendered again on the country page.
///
/// Null disables rendering (tests): previews then show their placeholder.
final tornFlagRenderServiceProvider = Provider<RenderService?>(
  (ref) => RenderService(createBundleAssetResolver()),
);

/// The long side every tee preview is rendered at. One size, so the cache is
/// shared; the torn flag's rasteriser is CPU-bound, so it stays modest.
const int kTornFlagPreviewLongSide = 600;

/// The shirt colours a tee can actually be ordered in: the Studio's palette
/// minus the colours the store has no variant for.
List<(String, String)> get tornFlagGarments => [
  for (final g in StudioController.garments)
    if (StudioV2CartAdapter.v1ColourName(g.$2) != null) g,
];

/// Every visited country that has a tee, most recently first visited first.
/// Countries with no known first visit (added by hand) follow, by name.
final myTeesProvider = FutureProvider<List<String>>((ref) async {
  final pack = ref.watch(tornFlagPackProvider);
  final visits = await ref.watch(effectiveVisitsProvider.future);
  if (pack == null) return const [];
  return orderTees([
    for (final v in visits)
      if (v.countryCode.length == 2) v,
  ]);
});

/// [myTeesProvider]'s order, as a pure function.
List<String> orderTees(List<EffectiveVisitedCountry> visits) {
  String name(String cc) => kCountryNames[cc.toUpperCase()] ?? cc;
  final sorted = [...visits]..sort((a, b) {
    final fa = a.firstSeen, fb = b.firstSeen;
    if (fa != null && fb != null && fa != fb) return fb.compareTo(fa);
    if (fa != null && fb == null) return -1;
    if (fa == null && fb != null) return 1;
    return name(a.countryCode).compareTo(name(b.countryCode));
  });
  final seen = <String>{};
  return [
    for (final v in sorted)
      if (seen.add(v.countryCode.toUpperCase())) v.countryCode.toUpperCase(),
  ];
}

/// The cart hand-off for a torn-flag tee.
///
/// Built through [buildGarmentCartRequest] over a headless [StudioController]
/// rather than by filling in a [GarmentCartRequest] by hand: the cart service
/// renders the print files from the request's session ([renderPrintFiles]),
/// so a request needs a real session anyway, and going through the shared
/// builder keeps the tee on exactly the path every Studio order takes. The
/// session holds the torn flag as its back face, prints nothing on the front,
/// and is never shown or edited.
///
/// The recipe is passed through untouched — its `recipeId` is the one the Lab
/// approved — so the shirt colour rides beside it ([garment]) instead of being
/// written into its palette.
GarmentCartRequest buildTornFlagCartRequest({
  required RenderService service,
  required DesignRecipe recipe,
  required String countryCode,
  required (String, String) garment,
  List<TripRecord> trips = const [],
}) {
  final cc = countryCode.toLowerCase();
  final mine = [
    for (final t in trips)
      if (t.countryCode.toLowerCase() == cc)
        StudioV2TravelContext.tripFromRecord(t),
  ];
  final session =
      StudioController(
          generator: const LabShowcaseGenerator(),
          service: service,
          designContext:
              mine.isEmpty
                  ? DesignContext(flagCodes: [cc], scopeKey: 'torn_flag:$cc')
                  : DesignContext.fromTrips(mine, scopeKey: 'torn_flag:$cc'),
          unavailableGarments: StudioV2CartAdapter.unstockedColours,
        )
        ..setFrontFit(FrontFit.none)
        ..loadGarment(
          GarmentDesign(front: recipe, back: recipe, garmentColour: garment.$1),
        );
  return buildGarmentCartRequest(
    session,
    garmentColour: garment,
    title: kCountryNames[cc.toUpperCase()] ?? cc.toUpperCase(),
  );
}
