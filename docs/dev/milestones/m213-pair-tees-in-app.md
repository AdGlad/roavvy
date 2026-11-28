# M213 — Pair tees in the app

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M206; the first approved pair pack (M209)
**Status:** Todo
**Size:** M

---

## 1. Scope

- **Choosing the pair** (needs the owner's decision; this is the default):
  1. **Suggested pairs** from the user's data: countries visited on the same trip, and the two most-visited countries. The app has no home country, so "home + destination" pairs need a home-country setting first. That is out of scope unless the owner wants it.
  2. **Pick any two** visited countries, with ⇄ swap to change the order.
- **Pair tee page:** the signature tee page (`studio_v2_commerce/signature_tees/`) takes a pair. It has the same TeeSidesPreview, print layout controls, colour backdrop, sizes and cart. Cart and print files go through the existing `renderPrintFiles` path unchanged, since the art is still one recipe.
- **Entry points:** a "Two countries" row on the signature tee list, and the trip detail page for trips with two or more countries. Everything sits behind CommerceGate.
- **Title:** "Greece & Italy" in cart and order lines.

## 2. Definition of done

- [ ] Widget tests: pick a pair, swap, add to cart (both commerce modes).
- [ ] The full suite is green with `ROAVVY_COMMERCE=true` and `false`.
- [ ] Only approved pair packs show in release builds (drafts only in debug).

---

## As built (2026-11-28)

**Status:** built; goes live once a pair pack is approved in the Lab. No pair pack ships yet (M209 adds `curtain_split`). The catalog drops drafts in release builds, so in release every pair surface stays hidden until approval. In debug, draft pair packs show.

- **Model** (`signature_tees/signature_tees.dart`):
  - `TeePair` (`a` prints left), `teePair`, `pairTitle` ("Greece & Italy").
  - `pairPacksProvider` lists packs with `isPair`. `teesForPair` resolves through `SignatureResolver.heroPair`.
  - `signaturePairTeesProvider` / `signaturePairTeeProvider` hold the pair's designs and the selected one.
  - `teesFor` now skips pair packs explicitly, so one-country surfaces never show them.
- **Suggestions** (`pairSuggestions`, pure):
  1. **Journeys:** trips in date order chain into one journey while each starts no more than `kJourneyGapDays` (2) after the journey so far ends. Every consecutive pair of countries in a multi-country journey is suggested, most recent journey first, in travel order.
  2. **Most visited:** the two countries with the most trips (ties broken by photos, then name). Without trips, the two most recently discovered.
  - A pair is never repeated in the other order. At most 8.
  - `journeyPairFor(trips, trip)` gives a trip's country with the journey country reached just before it (for the first leg, just after it).
  - `pairCountriesProvider` and `pairTeesAvailableProvider` gate the surfaces: a pair pack must exist and the traveller must have two or more countries.
- **Chooser:** `PairTeesScreen` ("Two countries").
  - Suggested pairs show as shirts.
  - "Pick any two" chips are numbered in pick order; a third pick replaces the oldest. A swap reverses the order, and "See tees" opens the pair.
- **Product page:** `SignatureTeeScreen(countryCode: a, pairWith: b)` is the same page with the pair's designs.
  - A `_PairHeader` shows A ⇄ B with a swap; swapping reverses the order and changes the design (ADR-185).
  - The app bar and the "<design> · Greece & Italy" line show the pair title.
  - The print layout, backdrop, colours, sizes and cart are unchanged.
- **Cart:** `buildSignatureTeeCartRequest(pairWith:)`.
  - Title "Greece & Italy · <design>"; the design context has both flags, and both countries' trips ride along.
  - It is one `DesignRecipe`, so the print path is unchanged.
- **Entry points:**
  - **My tees:** a "Two countries" row (`PairTeesCard`) at the top, through `CommerceEntry.openMyTees` → `openPairTees`.
  - **Trip sheet:** `CommerceEntry.tripPairTeeCard` (`TripPairTeeCard`, "One tee, two countries") for trips whose journey has two or more countries. It closes the sheet and then opens the pair through `CommerceEntry.openPairTee`.
  - All of them sit behind `CommerceGate` / `_push`.
- **Tests:** `test/features/studio_v2_commerce/pair_tees_test.dart` (20 tests) uses a test-only pair pack built from the torn-flag recipe. It covers:
  - the model: pair/single separation, order matters, titles, journeys, `journeyPairFor`, suggestions, availability;
  - the chooser: pick, swap, open, suggestions, the one-country message;
  - the page: title, swap, cart request;
  - the My tees row: shown or hidden;
  - the trip sheet: pair, no pair, commerce off.

**Open:**
- The country page has no pair entry (the spec only asked for the tee list and trip detail).
- The `kJourneyGapDays` = 2 heuristic should be checked against real libraries.
