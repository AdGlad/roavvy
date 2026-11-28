import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:design_studio/garment_mockup.dart' show inkFollowsShirt;
export 'package:design_studio/garment_mockup.dart' show inkFollowsShirt;
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
  (ref) => ref.watch(signatureCatalogProvider).valueOrNull?.packs ?? const [],
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
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
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
    // Two-country packs make pair tees ([teesForPair]), never a single
    // country's.
    if (pack.isPair) continue;
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

// ── Two-country (pair) tees, M213 ───────────────────────────────────────────

/// Two countries on one shirt, in order: [a] prints on the left (or top),
/// [b] on the right. Both upper-case ISO alpha-2. (a, b) and (b, a) are
/// different designs (ADR-185), so a pair is never sorted.
typedef TeePair = ({String a, String b});

/// [a] and [b] as a [TeePair], upper-cased.
TeePair teePair(String a, String b) => (a: a.toUpperCase(), b: b.toUpperCase());

/// Identifies one pair tee: the pair and a pack id (null: the pair's first
/// design).
typedef PairTeeKey = ({TeePair pair, String? packId});

/// "Greece & Italy".
String pairTitle(TeePair p) =>
    '${kCountryNames[p.a] ?? p.a} & ${kCountryNames[p.b] ?? p.b}';

/// The bundled two-country packs, in feed order. Empty when there are none —
/// and in a release build until one is approved in the Lab.
final pairPacksProvider = Provider<List<SignatureRecipe>>(
  (ref) => [
    for (final p in ref.watch(signaturePacksProvider))
      if (p.isPair) p,
  ],
);

/// The designs [packs] give the pair, in pack order, as a pure function.
/// Single-country packs and packs that cannot resolve the pair are left out.
List<SignatureTee> teesForPair(List<SignatureRecipe> packs, TeePair pair) {
  if (pair.a.length != 2 || pair.b.length != 2) return const [];
  if (pair.a == pair.b) return const [];
  final out = <SignatureTee>[];
  for (final pack in packs) {
    if (!pack.isPair) continue;
    try {
      out.add((
        pack: pack,
        recipe: SignatureResolver.heroPair(
          pack,
          pair.a.toLowerCase(),
          pair.b.toLowerCase(),
        ),
      ));
    } catch (_) {
      // Not offered for this pair.
    }
  }
  return out;
}

/// Every design a pair can be ordered in.
final signaturePairTeesProvider = Provider.family<List<SignatureTee>, TeePair>(
  (ref, pair) => teesForPair(ref.watch(pairPacksProvider), pair),
);

/// One pair tee: the design [PairTeeKey.packId], or the pair's first design
/// when packId is null. Null when unavailable.
final signaturePairTeeProvider = Provider.family<SignatureTee?, PairTeeKey>((
  ref,
  key,
) {
  final tees = ref.watch(signaturePairTeesProvider(key.pair));
  if (tees.isEmpty) return null;
  if (key.packId == null) return tees.first;
  for (final t in tees) {
    if (t.pack.id == key.packId) return t;
  }
  return null;
});

/// Trips closer than this (days between one leg's end and the next leg's
/// start) are one journey: "countries visited on the same trip".
const int kJourneyGapDays = 2;

/// One journey: its countries in the order first reached (upper-case, no
/// repeats) and the ids of the trips in it.
typedef _Journey = ({List<String> countries, Set<String> tripIds});

/// [trips] grouped into journeys, oldest first: runs of trips in date order,
/// each starting no more than [gapDays] after the run so far ends.
List<_Journey> _journeys(List<TripRecord> trips, int gapDays) {
  final sorted = [...trips]..sort((x, y) => x.startedOn.compareTo(y.startedOn));
  final out = <_Journey>[];
  DateTime? end;
  for (final t in sorted) {
    final cc = t.countryCode.toUpperCase();
    if (cc.length != 2) continue;
    final joins =
        end != null && !t.startedOn.isAfter(end.add(Duration(days: gapDays)));
    if (!joins) {
      out.add((countries: <String>[], tripIds: <String>{}));
      end = t.endedOn;
    } else if (t.endedOn.isAfter(end)) {
      end = t.endedOn;
    }
    final j = out.last;
    if (!j.countries.contains(cc)) j.countries.add(cc);
    j.tripIds.add(t.id);
  }
  return out;
}

/// The traveller's journeys (see [kJourneyGapDays]), most recent first, each
/// as its countries in the order first reached.
List<List<String>> journeysFrom(
  List<TripRecord> trips, {
  int gapDays = kJourneyGapDays,
}) => [for (final j in _journeys(trips, gapDays).reversed) j.countries];

/// The pair [trip]'s journey suggests: the trip's country with the journey
/// country reached just before it (for the first leg, just after it), in
/// travel order. Null when the journey has one country.
TeePair? journeyPairFor(List<TripRecord> trips, TripRecord trip) {
  for (final j in _journeys(trips, kJourneyGapDays)) {
    if (!j.tripIds.contains(trip.id)) continue;
    final c = j.countries;
    if (c.length < 2) return null;
    final i = c.indexOf(trip.countryCode.toUpperCase());
    if (i < 0) return null;
    return i == 0 ? teePair(c[0], c[1]) : teePair(c[i - 1], c[i]);
  }
  return null;
}

/// Suggested pairs, best first, as a pure function:
///  1. consecutive countries of each multi-country journey, most recent
///     journey first, in travel order;
///  2. the two most-visited countries (most trips; ties by photos, then by
///     name) — or, without trips, the two most recently discovered.
/// A pair is suggested once, in whichever order comes first. At most [max].
List<TeePair> pairSuggestions({
  required List<TripRecord> trips,
  required List<EffectiveVisitedCountry> visits,
  int max = 8,
}) {
  final out = <TeePair>[];
  final seen = <String>{};
  void add(String a, String b) {
    if (a == b || out.length >= max) return;
    final k = ([a, b]..sort()).join('+');
    if (seen.add(k)) out.add(teePair(a, b));
  }

  for (final j in journeysFrom(trips)) {
    for (var i = 0; i + 1 < j.length; i++) {
      add(j[i], j[i + 1]);
    }
  }

  final tripCount = <String, int>{};
  final photos = <String, int>{};
  for (final t in trips) {
    final cc = t.countryCode.toUpperCase();
    if (cc.length != 2) continue;
    tripCount[cc] = (tripCount[cc] ?? 0) + 1;
    photos[cc] = (photos[cc] ?? 0) + t.photoCount;
  }
  final top =
      tripCount.keys.toList()..sort((x, y) {
        final c = tripCount[y]!.compareTo(tripCount[x]!);
        if (c != 0) return c;
        final p = photos[y]!.compareTo(photos[x]!);
        if (p != 0) return p;
        return (kCountryNames[x] ?? x).compareTo(kCountryNames[y] ?? y);
      });
  if (top.length >= 2) {
    add(top[0], top[1]);
  } else {
    final recent = orderTees(visits);
    if (recent.length >= 2) add(recent[0], recent[1]);
  }
  return out;
}

/// The visited countries a pair can be picked from, most recently
/// discovered first.
final pairCountriesProvider = Provider<List<String>>((ref) {
  final visits = ref.watch(effectiveVisitsProvider).valueOrNull ?? const [];
  return orderTees([
    for (final v in visits)
      if (v.countryCode.length == 2) v,
  ]);
});

/// True when pair tees can be offered: a pair pack exists and the traveller
/// has at least two countries.
final pairTeesAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(pairPacksProvider).isNotEmpty &&
      ref.watch(pairCountriesProvider).length >= 2,
);

/// The traveller's suggested pairs ([pairSuggestions]).
final pairSuggestionsProvider = Provider<List<TeePair>>(
  (ref) => pairSuggestions(
    trips: ref.watch(tripListProvider).valueOrNull ?? const [],
    visits: ref.watch(effectiveVisitsProvider).valueOrNull ?? const [],
  ),
);

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

/// Where [tee] prints by default: the layout its pack was approved with in
/// the Lab, else a full back print.
PrintLayout teeLayout(SignatureTee tee) =>
    PrintLayout.fromJson(tee.pack.layout);

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
/// session holds the design on both faces and is never shown or edited;
/// [layout] (default: the pack's own, [teeLayout]) decides where it prints.
///
/// The recipe is passed through untouched — for an untokenised pack its
/// `recipeId` is the one the Lab approved — so the shirt colour rides beside
/// it ([garment]) instead of being written into its palette. The exception is
/// a design whose ink follows the shirt ([teeRecipe]).
///
/// A pair tee (M213) passes the second country as [pairWith]: the title
/// becomes "Greece & Italy · (design title)" and both countries' trips ride along.
GarmentCartRequest buildSignatureTeeCartRequest({
  required RenderService service,
  required SignatureTee tee,
  required String countryCode,
  required (String, String) garment,
  List<TripRecord> trips = const [],
  PrintLayout? layout,
  String? pairWith,
}) {
  final cc = countryCode.toLowerCase();
  final other = pairWith?.toLowerCase();
  final codes = [cc, if (other != null) other];
  final scope = '${tee.pack.id}:${codes.join('+')}';
  final recipe = teeRecipe(tee, garment.$1);
  final mine = [
    for (final t in trips)
      if (codes.contains(t.countryCode.toLowerCase()))
        StudioV2TravelContext.tripFromRecord(t),
  ];
  final session =
      StudioController(
          generator: const LabShowcaseGenerator(),
          service: service,
          designContext:
              mine.isEmpty
                  ? DesignContext(flagCodes: codes, scopeKey: scope)
                  : DesignContext.fromTrips(mine, scopeKey: scope),
          unavailableGarments: StudioV2CartAdapter.unstockedColours,
        )
        ..setFrontFit(FrontFit.none)
        ..loadGarment(
          GarmentDesign(front: recipe, back: recipe, garmentColour: garment.$1),
        );
  final name =
      other == null
          ? kCountryNames[cc.toUpperCase()] ?? cc.toUpperCase()
          : pairTitle(teePair(cc, other));
  return buildGarmentCartRequest(
    session,
    garmentColour: garment,
    title: '$name · ${tee.pack.title}',
    layout: layout ?? teeLayout(tee),
  );
}
