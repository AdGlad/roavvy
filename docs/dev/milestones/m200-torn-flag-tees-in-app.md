# M200 — Torn Flag tees in the app (country page, My tees, trip sheet, celebration)

**Phase:** v2 Signature T-shirts (M190–M199, follow-on)
**Depends on:** M190 (Signature Recipe engine), M191 (Lab workbench), M192 work on `feat/m192-torn-flag-signature` (rotation, outline)
**Status:** Done (branch `feat/m200-torn-flag-tees`)
**Primary target:** `apps/mobile_flutter`
**Size:** M

---

## 1. Why this exists

The torn flag is the first Signature design: one approved recipe that gives every country its own shirt. M190–M191 built it and the Lab tooling to tune and approve it, but nothing in the app showed it yet. This milestone puts a ready-made tee for every visited country where the traveller already is: on the country page, in a "My tees" collection, in the trip sheet, and in the new-country celebration right after a scan. One tap opens a plain product page (shirt, colour, size, price, Add to cart) that sends the order through the existing Studio V2 cart. The design itself can't be edited.

Commerce is off in v1.0 (ADR-180), so every surface is hidden, not just disabled, unless commerce is on.

## 2. Architecture

```
lib/features/studio_v2_commerce/torn_flag/      (commerce-owned: bridge layer)
  torn_flag_tees.dart        providers + pure helpers
    signatureCatalogProvider   FutureProvider<SignatureCatalog?>  (rootBundle; null on failure)
    tornFlagPackProvider       Provider<SignatureRecipe?>        (byId('torn_flag'))
    tornFlagRecipeProvider     Provider.family<DesignRecipe?, cc> (SignatureResolver.hero, lowercase)
    tornFlagRenderServiceProvider  one RenderService (shared cache) over the bundle resolver
    tornFlagGarments           StudioController.garments minus colours the store can't make
    myTeesProvider / orderTees visited countries, newest first visit first
    buildTornFlagCartRequest   headless StudioController → buildGarmentCartRequest
  torn_flag_tee_widgets.dart TornFlagTeeArt, TornFlagTeeCard, CelebrationTee, MyTeesCard
  torn_flag_tee_screen.dart  product page
  my_tees_screen.dart        collection

lib/features/commerce_entry/commerce_entry.dart  (the seam)
  openTornFlagTee(context, cc) · openMyTees(context)
  tornFlagTeeCard(cc, {onOpen}) · celebrationTee(cc) · myTeesCard()   — each wrapped in CommerceGate
```

Feature code (map, travel_timeline, stats) imports only `commerce_entry.dart`. Every widget the seam hands out is wrapped in `CommerceGate`, and every opener goes through `_push`, which does nothing when commerce is off. The tee widgets also hide themselves when there's no recipe for the country, so a missing or draft-filtered pack makes every surface disappear cleanly.

Rendering: `TornFlagTeeArt` → `ShirtPreview` (back face, `longSide` 600, transparent artwork on the tinted garment) through one shared `RenderService`, so a country rendered on the celebration isn't rendered again on the country page. It shows a quiet shirt-icon placeholder until the render arrives, and never blocks the UI.

## 3. Tasks

- **T1 Pack + recipe providers:** catalog (`SignatureCatalog.load(rootBundle.loadString)`), pack, per-country hero, shared render service.
- **T2 Product page:** shirt mockup, orderable colours only, sizes, live Shopify price, Add to cart → `StudioV2CartAdapter.addToCart`.
- **T3 Cart hand-off:** `buildTornFlagCartRequest` through the shared `buildGarmentCartRequest`; recipe passed through untouched.
- **T4 Seam:** `CommerceEntry.openTornFlagTee`, `openMyTees`, `tornFlagTeeCard`, `celebrationTee`, `myTeesCard`.
- **T5 Placements:** country page card, trip sheet card, celebration strip (single + carousel), Stats "My tees" card, My tees screen.
- **T6 Tests + architecture guard.**

## 4. Acceptance

- [x] Country page shows "Your torn flag tee" for a visited country when commerce is on; nothing when off.
- [x] Trip detail sheet shows the tee for the trip's country when on (tapping closes the sheet and opens the product page); nothing when off.
- [x] New-country celebration (single `DiscoveryOverlay` and multi `CountryCelebrationCarousel`) shows the tee with **Get this tee** when on; nothing when off; gives way on a screen too short for it (no overflow).
- [x] Stats shows a "My tees" card when on; My tees lists one tee per visited country, newest first visit first, with an empty state.
- [x] Product page lists only orderable colours (no Orange, no Royal); Add to cart is unavailable until a size is chosen; the `GarmentCartRequest` it sends has back recipe `recipeId == SignatureResolver.hero(pack, cc).recipeId`, the chosen colour, back `center`, no front print.
- [x] No pack (or draft dropped in release) → every tee surface hidden; the product page says "This tee isn't available yet."
- [x] Openers push nothing when commerce is off.
- [x] `commerce_boundary_test` green and extended; `v1_isolation_test` green.
- [x] `flutter analyze`: 0 errors (33 known warnings/infos); full suite green in both commerce modes (see As built).

## 5. As built (2026-11-27)

**Files**
- New: `lib/features/studio_v2_commerce/torn_flag/{torn_flag_tees,torn_flag_tee_widgets,torn_flag_tee_screen,my_tees_screen}.dart`; `test/features/studio_v2_commerce/torn_flag_tees_test.dart` (23 tests).
- Changed: `commerce_entry.dart` (5 seam members); `map/country_profile_screen.dart`, `travel_timeline/trip_detail_sheet.dart`, `map/discovery_overlay.dart`, `map/country_celebration_carousel.dart`, `stats/stats_screen.dart` (one gated call each); `studio_v2/commerce/garment_cart_request.dart`, `studio_v2/widgets/shirt_preview.dart`, `studio_v2_commerce/studio_v2_cart_adapter.dart` (small optional parameters, below); `test/architecture/commerce_boundary_test.dart`.
- No changes in `packages/`, `features/merch/` or `features/cards/`.

**Decisions**
- **Where the code lives.** In `features/studio_v2_commerce/torn_flag/`, the bridge layer that may know both the Studio and the store. It's covered by the existing `isCommerceOwner` rule (`features/studio_v2[a-z_]*/`), its `*_screen.dart` files are commerce routes under the existing rule, and a new architecture test stops feature code importing the tee widgets directly (they aren't screens, so the old rule wouldn't have caught an ungated card).
- **How the cart request is built.** With a headless `StudioController`: a context of just that country (plus its trips, when known), `setFrontFit(FrontFit.none)`, `loadGarment(GarmentDesign(front: torn, back: torn))`, then the shared `buildGarmentCartRequest`. There's no second hand-rolled request, as that builder's doc asks. And a session is needed anyway, because `StudioV2CartService` renders the print files from `request.session` (`renderPrintFiles`). The session's own front recipe isn't printed, because FrontFit.none means no front file is produced.
- **The recipe is never modified.** `StudioController.setGarment` writes the shirt colour (and `garmentAware`) into the palette, which changes the `recipeId`, the identity the Lab locks on approval. So `buildGarmentCartRequest` gained optional `garmentColour: (hex, name)` and `title` overrides that travel beside the recipe. Existing callers are unchanged. Similarly, `ShirtPreview` gained an optional `garmentColour` so the mockup can show any colour without re-rendering the artwork. When the recipe draws an outline (`outlineWidth > 0`), the artwork is drawn against the chosen shirt so the automatic outline colour stays correct.
- **Size on the page, not in a sheet.** The owner asked for size on the product page. `StudioV2CartAdapter.addToCart` gained an optional `options` parameter: when it's valid, the size sheet isn't shown a second time. The Studio still passes nothing and gets the sheet as before. Retry reuses the same options.
- **My tees entry point: the Stats screen**, as a card right after Merch Moments. The Shop tab body is V1 `MerchShopScreen` (`features/merch/`, frozen), and Stats is where the traveller already looks at what their countries add up to. The card appears only once there's at least one tee.
- **Default colour** is the first orderable Studio colour (Black), matching the Studio's own default.
- **Order:** most recent first visit first. Countries added by hand, with no dates, go last, sorted by name.
- **Celebration layout:** the strip replaces the `Spacer` above the primary button as an `Expanded`, and hides itself when less than 84 px is left, so small phones keep the existing layout and never overflow.

**Deviations / follow-ups**
- **Pack approval required for release.** `torn_flag` is still `draft`. `SignatureCatalog.load` drops drafts in release builds, so a release build shows no tee anywhere until the owner approves the pack in the Design Lab (Signatures → Approve). Debug/profile and commerce-on dev builds show it.
- **Outline on the print file (flagged, not changed: package code).** The production print renderer (`design_studio/production_render.dart`) renders on a transparent background, and `Keyline.autoFor(transparent)` picks the *light* outline. If the pack later turns on `outlineWidth` with `outlineColour: auto`, a white or grey shirt's print file would get a light outline while the preview shows a dark one. Today the pack's `outlineWidth` is 0, so nothing is affected. When the outline is enabled, the production renderer needs the shirt colour (or the pack should pin a fixed outline colour).
- **Garment identity.** The headless session's `GarmentDesign` carries no colour, because the hero's palette has none, so `garmentId` is the same across shirt colours. The cart's `configId` adds a timestamp, and the colour is recorded on the cart item, so orders stay distinct.
- **Fulfilment gate unchanged.** Orders still stop at "Print files ready" while `studioV2FulfilmentEnabledProvider` is closed (M26.1).
