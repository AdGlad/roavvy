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

/// Signature tees: ready-made shirts for every visited country, one per
/// Signature design (M200, generalised from the torn flag).
///
/// The designs are not generated here. Each is the hero of a bundled
/// Signature pack (ADR-181) — a recipe the owner tuned and approves in the
/// Design Lab — resolved for a country by [SignatureResolver.hero]. This file
/// is the app's whole view of them: where the packs come from, which designs
/// a country gets, which shirts they can be ordered on, and how an order is
/// handed to the existing Studio V2 cart.
///
/// Every consumer sits behind the commerce seam (`CommerceEntry`), so none of
/// these providers is ever read in a commerce-off build.

/// One design a country can be ordered in: the pack it comes from and the
/// recipe that pack resolves to for that country.
typedef SignatureTee = ({SignatureRecipe pack, DesignRecipe recipe});

/// Identifies one tee: a country (ISO alpha-2, any case) and a pack id.
/// A null [packId] means the country's first (default) design.
typedef TeeKey = ({String countryCode, String? packId});

/// The bundled Signature packs, or null when they cannot be read.
///
/// [SignatureCatalog.load] drops `draft` packs in release builds, so a pack
/// reaches a release build only once the owner approves it in the Lab; until
/// then that design simply isn't offered, and with no packs at all every tee
/// surface hides itself rather than showing a broken card.
final signatureCatalogProvider = FutureProvider<SignatureCatalog?>((ref) async {
  try {
    return await SignatureCatalog.load(rootBundle.loadString);
  } catch (_) {
    return null;
  }
});

/// The bundled packs in feed order (`index.json`). Empty while loading or
/// when unavailable.
final signaturePacksProvider = Provider<List<SignatureRecipe>>(
  (ref) =>
      ref.watch(signatureCatalogProvider).valueOrNull?.packs ?? const [],
);

/// Tokens a pack fills from a trip rather than from the country. A pack
/// using any of them is only offered when the traveller has a dated trip to
/// the country: its built-in defaults are sample dates, never real ones.
const Set<String> kTripTokens = {'entry', 'exit'};

/// The trip tokens for [trip]: arrival and departure as `12 MAR 24`.
Map<String, String> tripTokens(TripRecord trip) => {
  'entry': stampDate(trip.startedOn),
  'exit': stampDate(trip.endedOn),
};

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// A passport-stamp date: `12 MAR 24`.
String stampDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} '
    '${(d.year % 100).toString().padLeft(2, '0')}';

/// The most recent trip to [countryCode] in [trips], or null.
TripRecord? latestTrip(List<TripRecord> trips, String countryCode) {
  final cc = countryCode.toLowerCase();
  TripRecord? best;
  for (final t in trips) {
    if (t.countryCode.toLowerCase() != cc) continue;
    if (best == null || t.startedOn.isAfter(best.startedOn)) best = t;
  }
  return best;
}

/// The designs [packs] give [countryCode], in pack order, as a pure function.
///
/// A pack that uses trip tokens is filled from [trip] and left out without
/// one; a pack that cannot resolve for the country is left out.
List<SignatureTee> teesFor(
  List<SignatureRecipe> packs,
  String countryCode, {
  TripRecord? trip,
}) {
  if (countryCode.length != 2) return const [];
  final cc = countryCode.toLowerCase();
  final out = <SignatureTee>[];
  for (final pack in packs) {
    final needsTrip = pack.tokens.keys.any(kTripTokens.contains);
    if (needsTrip && trip == null) continue;
    try {
      out.add((
        pack: pack,
        recipe: SignatureResolver.hero(
          pack,
          cc,
          tokens: needsTrip ? tripTokens(trip!) : const {},
        ),
      ));
    } catch (_) {
      // A pack that can't resolve for this country is simply not offered.
    }
  }
  return out;
}

/// Every design a country can be ordered in (any case ISO alpha-2), in pack
/// order. Empty when there are no packs.
final signatureTeesProvider = Provider.family<List<SignatureTee>, String>((
  ref,
  countryCode,
) {
  final packs = ref.watch(signaturePacksProvider);
  if (packs.isEmpty) return const [];
  final trips = ref.watch(tripListProvider).valueOrNull ?? const [];
  return teesFor(packs, countryCode, trip: latestTrip(trips, countryCode));
});

/// One tee: the design [TeeKey.packId] gives the country, or the country's
/// default (first) design when packId is null. Null when unavailable.
final signatureTeeProvider = Provider.family<SignatureTee?, TeeKey>((ref, key) {
  final tees = ref.watch(signatureTeesProvider(key.countryCode.toUpperCase()));
  if (tees.isEmpty) return null;
  if (key.packId == null) return tees.first;
  for (final t in tees) {
    if (t.pack.id == key.packId) return t;
  }
  return null;
});

/// Whether [recipe]'s ink adapts to the shirt: a garment-aware design whose
/// ink is not the flag (Passport Stamp in black ink), or one with captions
/// (I ♥ Country). Its ink is chosen against the shirt colour — never black on
/// a black tee or red on a red one — so the shirt colour is part of the
/// design.
bool inkFollowsShirt(DesignRecipe recipe) =>
    (recipe.palette?.strategy == ColourStrategy.garmentAware &&
        recipe.inkIsAdaptive) ||
    // Captions (I ♥ Country) keep their colour only while it contrasts with
    // the shirt, so they too must know it.
    recipe.captions != null;

/// The recipe that prints [tee] on the shirt [garmentHex] (`#RRGGBB`).
///
/// Unchanged for almost every design: the shirt colour rides beside the
/// recipe so its `recipeId` stays the one the Lab approved. Only a design
/// whose ink follows the shirt ([inkFollowsShirt]) gets the shirt written into
/// its palette, so the preview AND the print file pick the legible ink — the
/// print renderer has no other way to know the shirt.
DesignRecipe teeRecipe(SignatureTee tee, String garmentHex) {
  final r = tee.recipe;
  if (!inkFollowsShirt(r)) return r;
  final palette = r.palette ?? const Palette();
  return r.copyWith(palette: palette.copyWith(garmentColour: garmentHex));
}

/// Renders tee previews. One for the whole app so every surface shares the
/// [RenderService] image cache — a design rendered on the celebration is not
/// rendered again on the country page.
///
/// Null disables rendering (tests): previews then show their placeholder.
final signatureTeeRenderServiceProvider = Provider<RenderService?>(
  (ref) => RenderService(createBundleAssetResolver()),
);

/// The long side every tee preview is rendered at. One size, so the cache is
/// shared; the raster effects are CPU-bound, so it stays modest.
const int kTeePreviewLongSide = 600;

/// The shirt colours a tee can actually be ordered in: the Studio's palette
/// minus the colours the store has no variant for.
List<(String, String)> get teeGarments => [
  for (final g in StudioController.garments)
    if (StudioV2CartAdapter.v1ColourName(g.$2) != null) g,
];

/// Every visited country that has a tee, most recently first visited first.
/// Countries with no known first visit (added by hand) follow, by name.
final myTeesProvider = FutureProvider<List<String>>((ref) async {
  final packs = ref.watch(signaturePacksProvider);
  final visits = await ref.watch(effectiveVisitsProvider.future);
  if (packs.isEmpty) return const [];
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

/// The cart hand-off for a signature tee.
///
/// Built through [buildGarmentCartRequest] over a headless [StudioController]
/// rather than by filling in a [GarmentCartRequest] by hand: the cart service
/// renders the print files from the request's session ([renderPrintFiles]),
/// so a request needs a real session anyway, and going through the shared
/// builder keeps the tee on exactly the path every Studio order takes. The
/// session holds the design as its back face, prints nothing on the front,
/// and is never shown or edited.
///
/// The recipe is passed through untouched — for an untokenised pack its
/// `recipeId` is the one the Lab approved — so the shirt colour rides beside
/// it ([garment]) instead of being written into its palette. The exception is
/// a design whose ink follows the shirt ([teeRecipe]).
GarmentCartRequest buildSignatureTeeCartRequest({
  required RenderService service,
  required SignatureTee tee,
  required String countryCode,
  required (String, String) garment,
  List<TripRecord> trips = const [],
}) {
  final cc = countryCode.toLowerCase();
  final scope = '${tee.pack.id}:$cc';
  final recipe = teeRecipe(tee, garment.$1);
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
                  ? DesignContext(flagCodes: [cc], scopeKey: scope)
                  : DesignContext.fromTrips(mine, scopeKey: scope),
          unavailableGarments: StudioV2CartAdapter.unstockedColours,
        )
        ..setFrontFit(FrontFit.none)
        ..loadGarment(
          GarmentDesign(
            front: recipe,
            back: recipe,
            garmentColour: garment.$1,
          ),
        );
  final name = kCountryNames[cc.toUpperCase()] ?? cc.toUpperCase();
  return buildGarmentCartRequest(
    session,
    garmentColour: garment,
    title: '$name · ${tee.pack.title}',
  );
}
