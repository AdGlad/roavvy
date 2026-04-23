<!-- Recent ADRs (ADR-100 to ADR-127). Load when introducing new patterns. -->

## ADR-127 — M75 Inline T-Shirt Config Panel: Remove "More" Modal

**Status:** Accepted

**Context:**
`LocalMockupPreviewScreen` split product configuration across two surfaces:
1. `_buildCompactStrip` — compact strip below the mockup showing colour swatches + Flip + "More" button.
2. `_showOptionsSheet` — a `DraggableScrollableSheet` modal opened by "More", containing: Product,
   Card design, Colour (duplicate of strip), Size, Front design, Back design, Ribbon mode.

This caused three UX problems: (a) users must navigate away to configure core options; (b) Colour
appears twice (strip and modal), creating confusion; (c) the experience feels fragmented and
non-premium compared to an Apple Store-quality product page.

**Decision:**
1. **Delete `_buildCompactStrip` and `_showOptionsSheet`** entirely. No references remain.
2. **Add `_buildInlineConfigPanel`** — a `ConstrainedBox(maxHeight: 280)` + `SingleChildScrollView`
   containing a `Column` of labelled sections. Always visible below the mockup. Never hidden.
3. **Section order (t-shirt only):** Colour row (with Flip button in header) → Size →
   Front design → Back design → Ribbon mode (conditional) → Stamp colour (conditional,
   passport template only).
4. **No Product type section. No Card design section. No poster path changes.** The panel is
   t-shirt configuration only; poster and card design remain outside scope of this milestone.
5. **Flip button** moves from `_buildCompactStrip` into the Colour section header row (right-aligned).
   Colour is the most-changed option so grouping Flip there is natural.
6. **Passport stamp colour picker** (`_buildStampColorPicker`) moves from `_buildCompactStrip`
   into the inline panel, shown conditionally when `_template == CardTemplateType.passport && _isTshirt`.
7. **Existing components reused unchanged:** `_ColourSwatchRow`, `_SegmentedPicker`, `_SectionLabel`,
   `_buildStampColorPicker`. Only layout/wiring changes.
8. **Body layout** becomes:
   ```dart
   Column(children: [
     Expanded(child: _buildMockupArea(theme)),          // mockup fills available space
     if (_templateChanged && ...) _InlineReconfirmationBanner(),
     if (_state != _MockupState.ready) _buildInlineConfigPanel(theme),
   ])
   ```
9. **`_hiddenPanel` pattern not used** — a `DraggableScrollableSheet` with a minimum snap would
   recreate the same "hidden navigation" problem. The panel is always fully visible.

**Consequences:**
- Single source of truth for every config option — no duplication possible.
- Panel height is capped at 280 logical pixels; on small devices sections below the fold are
  reachable by scrolling the panel (not navigating away).
- `_buildCompactStrip` callers in tests must be updated to assert the new panel structure.
- Poster path is unchanged — poster users still use whatever options remain after the strip
  removal. Poster-specific config is out of scope for this milestone.
- The `_showOptionsSheet` → `Navigator.of(ctx).pop()` calls that dismissed the sheet before
  applying option changes are removed; options apply immediately via `setState` (live preview).

---

## ADR-126 — M72 Country Celebration Carousel: Single-Route Multi-Country Flow

**Status:** Accepted

**Context:**
`ScanSummaryScreen._pushDiscoveryOverlays()` (ADR-084, ADR-108) pushed one `DiscoveryOverlay` route per new country using a `for` loop with `await Navigator.push(...)`. This produced three bugs:
1. **Double-pop blank screen** — `DiscoveryOverlay._handleSkipAll()` called both `widget.onSkipAll()` (which called `Navigator.pop()`) and then `Navigator.pop()` again, removing `ScanSummaryScreen` from the stack.
2. **Scan-summary flicker** — The 300ms `kCelebrationGapMs` delay between pushes left `ScanSummaryScreen` visible momentarily between each country, causing visible flicker.
3. **N-deep navigation stack** — 13 countries = 13 `MaterialPageRoute`s; back gesture would unwind through all of them.

**Decision:**
1. **`CountryCelebrationCarousel`** — a new single-route widget that hosts all country celebrations inside a `PageView.builder`. One push, one pop, no intermediate Navigator involvement per country.
2. **Single-country path unchanged** — `DiscoveryOverlay` is retained for single-discovery scans.
3. **Skip All fixed** — In `CountryCelebrationCarousel`, "Skip all" calls `widget.onDone()` directly (which pops the carousel route). In the retained `DiscoveryOverlay`, `_handleSkipAll` no longer calls `Navigator.pop()` — that responsibility belongs solely to the `onSkipAll` callback supplied by the caller.
4. **Globe animation simplified** — Phase 1 reduced from 1.5 rotations (540°) to 1/3 rotation (120°) eastward using `easeOut`. Phase 2 uses `Curves.easeInOutCubic` for premium deceleration. Total duration 2800ms (was 3000ms). Target longitude always normalised to travel eastward from the spin-end.
5. **Dot progress indicator** — For ≤10 countries: animated pill dots with the active dot stretching to 16px. For >10: "N of M" text.

**Consequences:**
- The `kCelebrationGapMs` constant in `discovery_overlay.dart` is no longer used in the multi-country path but is retained for documentation.
- Navigation history for multi-country celebrations is now flat: only the carousel route is in the stack.
- Per-page globe animation restarts when the user swipes back to a previous page (globe settles immediately; no re-trigger). Acceptable for the use case.
- `ScanSummaryScreen` no longer needs `firstVisited` values to be non-null — `firstVisitedByCode` is `Map<String, DateTime?>`.

---

## ADR-123 — M69 Celebration Globe: Animated Globe Inside DiscoveryOverlay

**Status:** Accepted

**Context:**
`DiscoveryOverlay` (ADR-084, ADR-108) was a static amber-gradient screen with a flag emoji, country name, XP, first-visited date, and CTA buttons. The M69 milestone spec requires a premium 5-second celebration that includes a 3D globe animating toward the discovered country and national-colour confetti.

**Decision:**
1. **Reuse `GlobeProjection` + `GlobePainter`** (ADR-116) inside a new `CelebrationGlobeWidget` rather than introducing a third-party 3D library. The existing projection math is fully capable of the required animation.
2. **`CelebrationGlobeWidget`** is a `ConsumerStatefulWidget` with two `AnimationController`s: a 3-second main controller split into three phases (fast spin → travel to centroid → hold), and an 800ms repeating pulse controller. Works inside `MaterialPageRoute` because `ProviderScope` is at the app root.
3. **`GlobePainter`** gains two optional params (`highlightedCode`, `pulseValue`) that draw a white halo on the highlighted country's centroid. Backwards compatible — existing callsites pass neither param.
4. **`DiscoveryOverlay`** becomes a `ConsumerStatefulWidget`. Layout: globe (260px) → flag emoji + country name + XP → first-visited → CTA. Confetti fires 2.2s after mount (after globe settles) using flag colours from `lib/core/flag_colours.dart`.
5. **`lib/core/flag_colours.dart`** — the private `_flagColours()` function is extracted from `scan_summary_screen.dart` into a shared public utility so both the summary screen and `DiscoveryOverlay` can load SVG flag colours.
6. **`lib/features/map/country_centroids.dart`** — `const Map<String, (double, double)>` of ISO code → approximate centroid (lat, lng). No network calls.

**Consequences:**
- No new third-party packages required.
- `DiscoveryOverlay` is now a `ConsumerWidget`; it reads `polygonsProvider`, `countryVisualStatesProvider`, `countryTripCountsProvider`.
- Reduce-motion: `CelebrationGlobeWidget` jumps to final state; confetti still fires.
- Countries with no centroid entry show pulse at the default globe orientation.
- `GlobePainter` `shouldRepaint` is slightly more expensive (two extra comparisons).

---

## ADR-122 — M65 Printful Dual-Mockup Client: Store and Display Both Placement URLs

**Status:** Accepted

**Context:**
The Cloud Function `generateDualPlacementMockups()` already requests both `front` and `back` Printful placements, polls until both are ready, and returns `{ frontMockupUrl, backMockupUrl }` in the callable response. `LocalMockupPreviewScreen` discards `backMockupUrl` — it only stores `_frontMockupUrl`. When the user toggles to Back, the code unconditionally falls through to the local mockup painter, silently mixing a Printful-rendered front with a local back even after generation completes.

**Decision:**
1. `LocalMockupPreviewScreen` stores both `String? _frontMockupUrl` and `String? _backMockupUrl` as screen state.
2. After `createMerchCart` resolves, both fields are populated from the callable response.
3. `_buildMockupArea()` selects the Printful URL for whichever face is active (`_showingFront` → `_frontMockupUrl`; back → `_backMockupUrl`) and shows it when non-null.
4. A new `_PrintfulMockupFace` enum (`frontReady`, `backReady`, `bothReady`, `frontOnly`, `backOnly`, `neither`) drives explicit status display — no silent mixing.
5. If one URL is null after generation, a visible inline banner ("Front mockup unavailable" / "Back mockup unavailable") replaces the local fallback for that face. The local mockup is only shown pre-generation.
6. Pre-generation local mockups remain unchanged — they are acceptable previews before Printful results arrive.

**Consequences:**
- User sees both Printful-rendered mockups before purchase — matching the actual print result.
- Failure on one side is surfaced explicitly, not hidden behind a local image.
- No Cloud Function changes required — all changes are in `local_mockup_preview_screen.dart`.
- The deprecated `mockupUrl` field from the Cloud Function response can continue to be ignored.

---


## ADR-100 — ArtworkConfirmation: user-scoped Firestore subcollection, SHA-256 image hash, optional cart linkage (M48)

**Status:** Accepted

**Context:** M48 establishes the data foundation for the Print Confidence series (M48–M54). The feature requires:
1. An `ArtworkConfirmation` record that proves the user explicitly approved a specific rendered image before purchase.
2. A deterministic image hash so the approval is tied to the exact pixels, not just the parameters.
3. A linkage from `MerchConfig` → `ArtworkConfirmation` so after purchase the `ArtworkConfirmation` status updates to `purchase_linked`.

Three structural decisions are needed: where to store the record, how to compute the hash, and how to add the linkage non-breakingly.

**Decision:**

**1. Storage: `users/{uid}/artwork_confirmations/{confirmationId}` subcollection**
Confirmed and pre-existing Firestore rule `match /users/{userId}/{document=**}` already covers all subcollections at any depth — no new rules are needed for `artwork_confirmations` or `mockup_approvals`. The `{document=**}` wildcard covers `users/{uid}/artwork_confirmations/{id}/mockup_approvals/{id}`.

**2. Hash: SHA-256 hex of the PNG bytes from `CardImageRenderer.render()`**
`CardImageRenderer.render()` is changed to return `CardRenderResult({Uint8List bytes, String imageHash})` instead of `Uint8List`. The hash is computed in Dart using `package:crypto` (already in pubspec) so it is deterministic for identical inputs within the same render session. The `renderSchemaVersion` field (`"v1"`) documents the rendering parameters so future re-renders can be verified.

**3. `artworkConfirmationId` on `MerchConfig`: optional, null for legacy orders**
`CreateMerchCartRequest` gains `artworkConfirmationId?: string`. `MerchConfig` gains `artworkConfirmationId: string | null`. The `shopifyOrderCreated` webhook: when `artworkConfirmationId` is non-null, updates the `ArtworkConfirmation` document status to `purchase_linked` + stores `orderId`. Legacy orders (null `artworkConfirmationId`) are unaffected.

**Consequences:**
- `CardImageRenderer.render()` return type changes — only one call site (`merch_variant_screen.dart`) must be updated to `.bytes`.
- `CardRenderResult` is a plain value type in `card_image_renderer.dart` — not in `shared_models` (no network/persistence boundary; Flutter-only type).
- `MerchConfig` schema gains `artworkConfirmationId: string | null` — backward-compatible (old docs missing the field read as null).
- The `shopifyOrderCreated` webhook gains a Firestore write to the confirmation doc — non-breaking side-effect; fails gracefully if doc not found.
- No new Firestore security rules needed — existing wildcard covers the new subcollections.

---

## ADR-101 — Branding Layer: `CardBrandingFooter` Widget, dateLabel pass-through, Heart canvas-to-Widget migration (M49)

**Status:** Accepted

**Context:** M49 requires all three card templates (Grid, Heart, Passport) to show a consistent branding footer — Roavvy wordmark + country count + date range label — as part of the captured PNG artwork.

Three structural decisions:

1. **Widget vs. canvas for branding**: The Grid and Passport templates are `StatelessWidget`/`Stack` layouts; adding a footer widget is straightforward. The Heart template currently draws the ROAVVY label directly in `_HeartPainter.paint()` as a `TextPainter` canvas call.

2. **Where to compute the date label**: Date range depends on which trips are in scope, not on the card template. Templates should receive a pre-computed string, not trip records they must re-process.

3. **`CardImageRenderer` parameter surface**: Adding `dateLabel` to `render()` now is premature — M51 (Artwork Confirmation Screen) is the first caller that will have a meaningful date range from the UI. Changing the signature now would require updating M48-era tests with no actual benefit.

**Decision:**

**1. `CardBrandingFooter` is a `StatelessWidget`** in `lib/features/cards/card_branding_footer.dart`. All three card templates use it as a Widget positioned at the bottom of their layout — consistent approach, no canvas drawing for branding text.

**2. Heart template: replace canvas brand label with `Positioned` Widget overlay**. `_HeartPainter._drawBrandLabel()` is removed. The Heart card's `LayoutBuilder` → `CustomPaint` is wrapped in a `Stack`; `CardBrandingFooter` is `Positioned(bottom: 0)`. Dark navy background beneath the branding strip is inherent to the canvas; `CardBrandingFooter` uses a semi-transparent `Color(0xFF0D2137)` background to stay readable regardless of what heart tiles are drawn below.

**3. `dateLabel: String = ''` added to all three card templates**. Empty string = date label omitted from footer (only ROAVVY + count shown). This is backward-compatible: all existing call sites compile without changes. `CardGeneratorScreen._buildTemplate()` computes the label from `filteredTrips` and passes it. `CardImageRenderer.render()` is NOT changed — its rendered output will show ROAVVY + count (satisfying M49 acceptance criteria) with an empty date label, which is correct behaviour for a programmatic render without UI date selection context.

**4. Date label format**: single-year → `"2024"`, multi-year → `"2018\u20132024"` (en-dash, not hyphen). Empty string when no trip data. Computed by a pure helper `_computeDateLabel(List<TripRecord>)` local to `card_generator_screen.dart`.

**Consequences:**
- `GridFlagsCard`: top-level ROAVVY text header removed; bottom Row (count + "countries visited") replaced by `CardBrandingFooter`. Visual change: ROAVVY moves from top to footer.
- `HeartFlagsCard`: `_drawBrandLabel` removed from `_HeartPainter`. Branding now Widget-level; `shouldRepaint` gains `dateLabel` comparison.
- `PassportStampsCard`: `Positioned` ROAVVY watermark replaced by `Positioned` `CardBrandingFooter`. Passport-specific amber text colour (`Color(0xFF8B6914)`) preserved via `textColor` parameter.
- Existing template tests that checked for `find.text('countries visited')` must be updated (text changes to `'{N} countries'`).
- All card templates remain backward-compatible: `dateLabel` defaults to `''`.

---

## ADR-102 — M50 Layout Quality: Grid Adaptive Tile Size and Passport Print-Safe Mode

**Status:** Accepted

**Context:** M50 corrects two layout deficiencies before M51 (Artwork Confirmation) asks users to confirm print-ready artwork:

1. **Grid adaptive fill**: `GridFlagsCard` uses a fixed `fontSize: 18` regardless of country count. For N=1 this wastes most card area; for N=50+ the tiles become small and uniform.
2. **Passport print-safe mode**: `PassportLayoutEngine` uses 8% margins and randomly edge-clips ~8% of stamps. For print output, clipped stamps are unacceptable and all stamp centres must remain within a 3% safe zone.

**Decision:**

**M50-C1 — Grid adaptive fill**: A `gridTileSize(double canvasArea, int n)` pure function implements `clamp(floor(sqrt(canvasArea / n) * 0.85), 28, 90)`. `GridFlagsCard` wraps its tile area in a `LayoutBuilder`; the result drives the emoji `fontSize`. Minimum tile: 28 logical pixels; maximum: 90. The function is exposed with `@visibleForTesting` for unit testing without widget infrastructure.

**M50-C2 — Passport print-safe mode**: `PassportLayoutEngine.layout()` gains `forPrint: bool = false` and now returns `PassportLayoutResult({stamps: List<StampData>, wasForced: bool})` instead of bare `List<StampData>`.

When `forPrint = true`:
- Safe-zone margin: 3% each edge (was 8%).
- No edge clipping: `edgeClip` is always `null`.
- Uniform adaptive base radius: `unclamped = safeArea.shortSide / (2.5 × ceil(sqrt(N)))`, clamped to [20, 38]. Stamp scale is derived: `scale = clampedRadius / 38.0`.
- If `unclamped < 20` and caller did not already set `entryOnly`: force `entryOnly = true`, set `wasForced = true` on the result.

`PassportStampsCard` gains `forPrint: bool = false`, which it passes to `_PassportPagePainter`. `_PassportPagePainterState` stores `_wasForced: bool` for future surfacing by M51.

**Consequences:**
- Existing `PassportLayoutEngine.layout()` callers must access `.stamps` on the returned `PassportLayoutResult`; all existing tests updated accordingly.
- `gridTileSize()` is a top-level `@visibleForTesting` function in `card_templates.dart`.
- N=1 on a square canvas: tile fills ~85% of canvas width.
- N≥100 on typical card canvas: tile clamped to 28 px minimum.
- `wasForced` stored in `_PassportPagePainterState`; M51 will surface it to callers.

---

## ADR-103 — M51 Artwork Confirmation Flow: Screen, Navigation, and Re-Confirmation

**Status:** Accepted

**Context:** M51 requires users to explicitly confirm the exact rendered artwork before entering the product selection / purchase flow (M51-E1), with correct forward/back navigation (M51-E2) and re-confirmation when artwork parameters change (M51-E3).

Three structural decisions:

1. **How to surface `wasForced` from `_PassportPagePainterState` to `CardImageRenderer.render()`**: The renderer creates a widget, inserts it into an `OverlayEntry`, and captures it after one frame. The layout engine's `wasForced` result is set during `_PassportPagePainterState.initState()`, which runs synchronously during the first frame build — before `addPostFrameCallback` fires. An `onWasForced: ValueChanged<bool>?` callback on `PassportStampsCard` (called in `_applyLayoutResult()`) is therefore sufficient to capture the value before image capture.

2. **Navigation stack for the confirmation flow**: The M51-E2 requirement "Back from Product Browser returns to Card Generator (not Artwork Confirmation)" requires the Artwork Confirmation screen to be absent from the route stack when Product Browser is live. The cleanest approach: `ArtworkConfirmationScreen` pops with an `ArtworkConfirmResult({confirmationId, bytes})` return value; `CardGeneratorScreen` awaits the push, then (on non-null result) stores `_lastConfirmedParams` + `_artworkConfirmationId` + `_artworkImageBytes`, and pushes `MerchProductBrowserScreen`. Stack: Card Generator → Product Browser. ✓

3. **Re-confirmation comparison**: `CardGeneratorScreen` stores a `_CardParams` snapshot (templateType, countryCodes, aspectRatio, entryOnly, yearStart?, yearEnd?). On each "Print your card" press: if `currentParams == _lastConfirmedParams && _artworkConfirmationId != null`, navigate directly to Product Browser (skip confirmation). Otherwise, navigate through `ArtworkConfirmationScreen` (with `showUpdatedBanner: true` when a prior confirmation exists).

**Decision:**

- `PassportStampsCard` gains `onWasForced: ValueChanged<bool>?`; `_PassportPagePainterState._applyLayoutResult()` calls it after applying the layout result.
- `CardRenderResult` gains `wasForced: bool = false`.
- `CardImageRenderer.render()` gains `forPrint: bool = false`; when rendering passport with `forPrint=true`, wires up `onWasForced` to capture the flag.
- `ArtworkConfirmationScreen` (`lib/features/cards/artwork_confirmation_screen.dart`) is a `ConsumerStatefulWidget` receiving `(templateType, countryCodes, filteredTrips, dateRangeStart?, dateRangeEnd?, aspectRatio, entryOnly, showUpdatedBanner)`. On init it renders the card; on confirm it creates an `ArtworkConfirmation` and pops with `ArtworkConfirmResult`.
- `CardGeneratorScreen` stores `_lastConfirmedParams: _CardParams?`, `_artworkConfirmationId: String?`, `_artworkImageBytes: Uint8List?`. `_onPrint()` checks for same-params shortcut or routes through confirmation.
- `MerchProductBrowserScreen` gains `artworkConfirmationId: String?` and `artworkImageBytes: Uint8List?`; shows a rendered preview thumbnail at the top of the screen when bytes are present; threads `artworkConfirmationId` to `MerchVariantScreen`.
- `MerchVariantScreen` gains `artworkConfirmationId: String?`; passes it in the `createMerchCart` callable payload.

**Consequences:**
- `CardImageRenderer.render()` callers that already check `.bytes` and `.imageHash` are unaffected by the new `wasForced` field (default `false`).
- The `onWasForced` callback is only set for passport + `forPrint=true`; all other templates/modes are unaffected.
- `ArtworkConfirmationScreen` handles Firestore write internally via `ArtworkConfirmationService(FirebaseFirestore.instance)` — no new Riverpod provider needed.
- Re-confirmation banner copy: "Your artwork has been updated — please confirm the new version." (positive/factual, not legalistic).

---

## ADR-104 — M52 Timeline Card Template: Layout Engine, Widget, and Enum Extension

**Status:** Accepted

**Context:** M52 adds a fourth card template — "Timeline" — which renders a user's trips as a dated travel log. Three decisions need to be locked before building:

1. **Where `TimelineLayoutEngine` lives**: It uses `TripRecord` (from `shared_models`) and `Size` (from `dart:ui`). `dart:ui` is a Flutter/Dart runtime import, not a platform API, so it is available in pure Dart unit tests. However, the package boundary rule is that `shared_models` contains no business logic. The layout engine IS business logic. Therefore `TimelineLayoutEngine` lives in `lib/features/cards/timeline_layout_engine.dart` inside the mobile app, not in `shared_models`.

2. **`CardTemplateType.timeline` enum extension**: Adding `timeline` to the Dart enum in `shared_models` is a backwards-compatible change (new enum variant). All Dart exhaustive switch statements over `CardTemplateType` will fail to compile if they omit the new case — the compiler enforces completeness. The TypeScript type in `ts/` is not updated in this milestone (TypeScript-side update is deferred; `artworkConfirmationId` flow in Functions does not switch over template type).

3. **Font strategy for monospaced dates**: iOS provides `Courier` (serif monospaced) and `Courier New` natively. Rather than bundling a font, use `fontFamily: 'CourierNew'` with `fontFamilyFallback: ['Courier', 'monospace']`. For the rendered PNG (via `CardImageRenderer`) this is acceptable — the font will resolve correctly on the test/rendering device. Date columns use a fixed `TextStyle` width via `SizedBox` wrappers to prevent layout shifts regardless of font metrics.

**Decision:**

- `CardTemplateType.timeline` added to the Dart enum in `packages/shared_models/lib/src/travel_card.dart`. TypeScript `ts/` not updated this milestone.
- `TimelineLayoutEngine` and `TimelineEntry` / `TimelineLayoutResult` in `lib/features/cards/timeline_layout_engine.dart` (mobile app, features layer). Pure static methods; `Size` from `dart:ui` is the only non-domain import.
- `TimelineCard` is a `StatelessWidget` in `lib/features/cards/timeline_card.dart`. Parchment background `Color(0xFFF5F0E8)`, dark ink `Color(0xFF2C1810)`, amber year dividers `Color(0xFFD4A017)`. Monospaced date column uses `fontFamily: 'CourierNew'` with Courier fallback.
- `TimelineCard` calls `TimelineLayoutEngine.layout()` inside `build()` via `LayoutBuilder` to obtain the canvas size. This keeps the widget stateless and avoids a `CustomPainter` for text-heavy content.
- `CardImageRenderer._cardWidget()` gains a `timeline` case. No `forPrint` special mode needed — no stamps, no edge clipping.
- `ArtworkConfirmationScreen` needs no change: it renders via `CardImageRenderer.render()` which already dispatches to `_cardWidget()`.
- `MerchVariantScreen` template picker gains a "Timeline" segment.

**Consequences:**
- All `switch (templateType)` statements in `card_generator_screen.dart`, `card_image_renderer.dart`, `merch_variant_screen.dart` must add a `timeline` case — Dart compiler enforces this exhaustively.
- `TimelineLayoutEngine.layout()` takes `Size` as a parameter; tests can pass a literal `Size(600, 400)` without needing widget infrastructure.
- `PassportStampsCard`'s `forPrint` complexity does not apply to Timeline — the layout engine is simpler.
- TypeScript Functions code is unaffected: `createMerchCart` accepts `templateType` as an opaque string stored on `MerchConfig`; no server-side switch over template type exists.

---

## ADR-105 — M53 Mockup Approval: Screen Placement, `artworkImageBytes` Threading, and Approval-Before-Cart Ordering

**Status:** Accepted

**Context:** M53 inserts an explicit user-approval step into the commerce flow before checkout is initiated. Three structural decisions must be made before building begins:

1. **When in the flow to request approval** — the approval screen can be shown either (a) before `createMerchCart` is called, (b) after the cart is created but before the checkout URL is launched, or (c) as part of the Printful mockup review step. The product intent is to capture consent before any server-side cart is created, ensuring that `mockupApprovalId` can be included in the `createMerchCart` payload as evidence of explicit user approval at order time.

2. **Where `artworkImageBytes` is available in the commerce stack** — `artworkImageBytes: Uint8List?` is currently a constructor parameter on `MerchProductBrowserScreen` (threaded from `CardGeneratorScreen` via `ArtworkConfirmResult`) but is NOT passed to `MerchVariantScreen`. The approval screen needs to show the card artwork for the user to confirm it is correct.

3. **What the `variantId` type is at the call site** — `_resolvedVariantGid` in `MerchVariantScreen` is already a `String`. The `MockupApproval` model stores it as `String`. No type conversion is needed.

**Decision:**

1. **Approval before cart creation.** `MockupApprovalScreen` is shown when the user taps the "Approve & buy" button (replacing the current "Preview my design" label on the `initial` state button). After approval, `_generatePreview(mockupApprovalId: result.mockupApprovalId)` is called, which includes `mockupApprovalId` in the `createMerchCart` payload. The Printful product mockup is then shown in the existing `ready` state. The existing two-stage flow (`initial → loading → ready → "Complete checkout →"`) is preserved; the approval screen is inserted before the `initial → loading` transition.

2. **Thread `artworkImageBytes` into `MerchVariantScreen`.** `MerchVariantScreen` gains `artworkImageBytes: Uint8List?` as an optional constructor parameter. `MerchProductBrowserScreen` passes it when navigating to `MerchVariantScreen` (it already holds the bytes). `MerchVariantScreen` passes `artworkImageBytes` to `MockupApprovalScreen`. The screen gracefully handles null bytes with a "Preview unavailable" placeholder.

3. **`MockupApproval` model in `shared_models`; `MockupApprovalService` in mobile features layer.** Consistent with `ArtworkConfirmation` / `ArtworkConfirmationService` pattern (ADR-100 / ADR-103). The model is a pure data class exported from the shared barrel; the service contains Firestore write logic and lives in `lib/features/merch/`. The Functions side adds `mockupApprovalId?: string` to `CreateMerchCartRequest` and `MerchConfig`.

4. **`MockupApprovalScreen` is a push route, not a bottom sheet.** The screen performs an async Firestore write before popping — this warrants full-screen treatment to prevent accidental dismissal. It pops with `MockupApprovalResult(mockupApprovalId: String)` on approval; pops null on back navigation. Consistent with `ArtworkConfirmationScreen` (ADR-103).

5. **Placement checkbox is conditional.** The screen shows 3 checkboxes for t-shirts (design, colour, placement) and 2 for posters (design, colour — placement omitted when `placementType == null`). This is safe because `MerchVariantScreen` does not include `placement` in the `createMerchCart` payload for posters.

**Consequences:**
- `MerchVariantScreen` gains one new optional constructor parameter: `artworkImageBytes: Uint8List?`. `MerchProductBrowserScreen` must be updated to pass this when navigating.
- The "Preview my design" button label in `MerchVariantScreen` state `initial` changes to "Approve & buy". Any widget tests asserting on the old label text must be updated.
- `_generatePreview()` gains a `mockupApprovalId: String` required parameter (or is split into `_navigateToApproval()` + `_generatePreview(String mockupApprovalId)`); the `initial` state button no longer calls `_generatePreview()` directly.
- Firestore `mockup_approvals` subcollection is already covered by the wildcard security rule `match /users/{userId}/{document=**}` (confirmed ADR-100). No Firestore rules changes needed.
- `MockupApproval.variantId` is a `String` — no coercion from int. Consistent with BUG-001 resolution (ADR-099) where all variant IDs are treated as opaque strings.

---

## ADR-106 — M54 Gap Closure: Artwork Bytes Reuse, Confirmation Archival, and UID-Null UX

**Status:** Accepted

**Context:** Three concrete gaps identified after M53 completion:

1. **Timeline card renders empty in `MerchVariantScreen`**: `CardImageRenderer.render()` accepts `List<TripRecord> trips = const []` as a default. When `MerchVariantScreen._generatePreview()` calls it, no trips are threaded in, so the Timeline template renders an empty card. The confirmed artwork bytes (in `widget.artworkImageBytes`) already have trips baked in from the `ArtworkConfirmationScreen` render — reusing them is both correct and avoids a needless re-render.

2. **Orphaned `ArtworkConfirmation` documents**: `ArtworkConfirmationService.archive()` was implemented and tested in M48/M50 but is never called. Each time a user re-confirms with changed params in `CardGeneratorScreen`, the old `_artworkConfirmationId` is silently overwritten, leaving an unarchived document in Firestore.

3. **Silent UID-null failures**: Both `ArtworkConfirmationScreen._onConfirm()` and `MockupApprovalScreen._onApprove()` silently return when `currentUidProvider` is null. The loading spinner stays visible and no feedback is shown — the user has no way to know what happened.

**Decision:**

1. **Reuse `artworkImageBytes` as `clientCardBase64` when template unchanged.** In `MerchVariantScreen._generatePreview()`, if `widget.artworkImageBytes != null` AND `_selectedTemplate == widget.initialTemplate`, set `cardBase64 = base64Encode(widget.artworkImageBytes!)` and skip the `CardImageRenderer.render()` call. The confirmed artwork is the source of truth — it is pixel-identical to what the user approved. If the user changes template, the re-render path proceeds normally. This is a conditional bypass, not a removal of the renderer.

2. **Archive superseded confirmation fire-and-forget.** In `CardGeneratorScreen._goToProductBrowser()`, before overwriting `_artworkConfirmationId` with `result.confirmationId`, check if a prior ID exists and differs. If so, call `ArtworkConfirmationService(FirebaseFirestore.instance).archive(uid, _artworkConfirmationId!)` via `unawaited()` (fire-and-forget). Exceptions are swallowed. Archive failure must not block checkout navigation — it is a housekeeping concern, not a correctness concern.

3. **SnackBar + loading reset on UID null.** Both approval screens replace `if (uid == null || !mounted) return;` with an explicit branch: show `SnackBar('Please sign in to continue')`, reset the loading state flag, and return. This makes the failure visible without requiring a restart or nav action from the user.

**Consequences:**
- `MerchVariantScreen` must import `dart:convert` for `base64Encode`; it already has `widget.artworkImageBytes` and `widget.initialTemplate` in scope (M53).
- `CardGeneratorScreen` must have access to `currentUidProvider` (already used, M51) and `ArtworkConfirmationService` (already imported, M51). If `dart:async` is not already imported, `unawaited` requires it — alternatively `.ignore()` may be used.
- Both approval screens already import `ScaffoldMessenger` via their widget tree; no new dependencies needed.
- The `artworkImageBytes` reuse path produces identical bytes to what was shown in `ArtworkConfirmationScreen` — the confirmed artwork is the product print source of truth.

---

## ADR-107 — M55 Local Product Mockup: Screen Architecture, Inline Re-confirmation, Deferred Printful Mockup, and Poster Handling

**Status:** Accepted

**Context:** The existing commerce navigation sequence (`MerchProductBrowserScreen` → `MerchVariantScreen` → `MockupApprovalScreen`) has four structural problems:

1. **Product image is never shown before checkout.** `MockupApprovalScreen` shows the flat card art, not the card on the product. The user cannot see how their design looks on a t-shirt or poster until after they leave the app to Shopify.
2. **Printful mockup API called too early.** `MerchVariantScreen._generatePreview()` calls `createMerchCart` immediately when the screen loads, triggering a Printful API call before the user has made any product choices. This wastes credits and creates latency before confirmation.
3. **Colour/variant changes restart the full flow.** Any product option change requires popping back through multiple screens.
4. **`artworkImageBytes` threading gap.** `MerchVariantScreen` needed `artworkImageBytes` threaded through two screens (`MerchProductBrowserScreen` → `MerchVariantScreen`) to avoid Timeline re-render emptiness — a brittle prop-drilling pattern across unrelated screens.

**Decision:**

1. **Introduce `LocalMockupPreviewScreen` as a single unified screen** replacing `MerchProductBrowserScreen`, `MerchVariantScreen`, and `MockupApprovalScreen`. All product configuration, mockup preview, and approval happen on one screen. `CardGeneratorScreen._goToProductBrowser()` pushes `LocalMockupPreviewScreen` directly.

2. **On-device compositing with `LocalMockupPainter`.** Bundled product mockup images (PNG) are loaded from the asset bundle by `LocalMockupImageCache` (LRU, 6 entries). `LocalMockupPainter` (`CustomPainter`) composites `ui.Image` (product) + `ui.Image` (artwork bytes) using `spec.printAreaNorm: Rect` (normalised 0.0–1.0 coordinates). No network call is made during configuration. This is entirely local rendering.

3. **Inline re-confirmation when template changes.** When the user changes card template inside `LocalMockupPreviewScreen`, show an amber inline banner ("Design changed — please confirm again") and change the CTA to "Confirm updated design". Do not force navigation back to `ArtworkConfirmationScreen`. Instead, `_onApprove()` creates a new `ArtworkConfirmation` inline (with `archive()` fire-and-forget on the prior ID) before writing `MockupApproval`. Colour, size, and placement changes do NOT invalidate the artwork confirmation.

4. **Printful mockup deferred to `ready` state only.** `createMerchCart` (which triggers the Printful API call) is called exactly once: when the user explicitly taps "Approve this order". The `ready` state then shows `Image.network(mockupUrl)` as the photorealistic preview. The local `CustomPaint` is the `loadingBuilder` fallback — the user always sees something while the network image loads. The remote mockup is not optional; it is always shown in `ready` state before "Complete order →".

5. **Poster: `productImage = null` → edge-to-edge artwork.** For poster products, `LocalMockupPainter` is constructed with `productImage: null`. When `productImage` is null, the painter fills the canvas with a white background and draws the artwork at `spec.printAreaNorm = Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)` (full canvas). No frame or room mockup is rendered for MVP.

6. **Variant GID lookup tables extracted to `lib/features/merch/merch_variant_lookup.dart`.** Both `MerchVariantScreen` and `LocalMockupPreviewScreen` require the same `(MerchProduct, colour, size, placement) → variantGid` mapping. Extract to a single shared file to avoid divergence. `MerchVariantScreen` (deprecated) may delegate to this file or keep its own copy until M56 deletion.

7. **`_lastConfirmedTrips` added to `_CardGeneratorScreenState`.** `filteredTrips` is computed inside `_navigateToPrint()` and currently not persisted to state. Add `List<TripRecord>? _lastConfirmedTrips` and capture the value alongside `_artworkImageBytes` when an `ArtworkConfirmResult` is received. Thread to `LocalMockupPreviewScreen` as `trips:` so template re-renders within the screen use the trip list that corresponds to the confirmed artwork.

**Consequences:**
- `MerchProductBrowserScreen`, `MerchVariantScreen`, and `MockupApprovalScreen` are deprecated (not deleted); deletion is scheduled for M56.
- `LocalMockupPreviewScreen` must implement `WidgetsBindingObserver` for the app-resume poll (same pattern as `MerchVariantScreen`).
- Bundled mockup PNG assets (~11 files, ≤200 KB each) must be registered in `pubspec.yaml`.
- `ProductMockupSpec.printAreaNorm` values must be calibrated against actual image dimensions at native size; a `kDebugMockup` flag should draw a visible debug border during development.
- `LocalMockupImageCache.dispose()` is called from `LocalMockupPreviewScreen.dispose()` to release `ui.Image` objects and avoid memory leaks.
- The `_MockupState` enum (`configuring | rerendering | approving | ready`) is internal to `LocalMockupPreviewScreen` and not persisted to Firestore.

---

## ADR-108 — M56 Celebration Queue: Sequential Navigation via Async Loop

**Status:** Proposed

**Context:** M56-03 requires that when multiple countries are discovered in a single scan, celebrations do not overlap. M56-06 reports that pressing Next can navigate prematurely to the main map before all countries in the queue are shown. M56-07 reports that Skip All does not reliably navigate to the correct destination.

Examining the existing implementation in `scan_summary_screen.dart`: `_pushDiscoveryOverlays()` already drives a sequential loop using `await Navigator.of(context).push(...)` inside a `for` loop, with a `skipped` boolean flag to break early on Skip All. However, three bugs exist:

1. **Early exit bug (M56-06)**: `_pushDiscoveryOverlays()` is capped at `_kMaxOverlays = 5`. The loop `codes = widget.newCodes.take(_kMaxOverlays).toList()` processes at most 5 overlays, but `widget.onDone()` is called after only those 5 complete — causing navigation to the map while remaining countries in the queue are unshown.

2. **Skip All navigation bug (M56-07)**: `onSkipAll` on the final overlay in the 5-cap batch is set to `null`, meaning the last visible overlay has no Skip All button. When Skip All is tapped on a non-final overlay, `skipped = true` breaks the loop and calls `widget.onDone()`, but the `Navigator.of(context).pop()` inside `_handleSkipAll()` pops the overlay before the loop's `await` resumes — this path works correctly. The actual navigation destination failure is a separate issue: `widget.onDone()` at the call site must navigate to the Main Map, not simply return.

3. **No inter-celebration gap**: There is no configurable pause between sequential overlays.

**Decision:**

The existing async `for`-loop + `await push` pattern is the correct structural approach and must not be replaced with a separate queue object or `StreamController`. The pattern is clean, respects `mounted` checks, and avoids shared mutable state across rebuilds.

The three bugs are fixed surgically:

1. **Remove the `_kMaxOverlays = 5` cap.** All countries in `widget.newCodes` are iterated. The `take(5)` guard was a conservative UI decision made in ADR-084 that is now overridden by M56 requirements.

2. **Skip All destination.** The `onSkipAll` callback on every overlay (except the last) clears the queue by setting `skipped = true` and popping. After the loop, `widget.onDone()` is called unconditionally. The caller (`ReviewScreen` / `ScanSummaryScreen`) is responsible for routing `onDone` to the Main Map — this is already the contract. No navigation change is needed inside `_pushDiscoveryOverlays()`.

3. **Inter-celebration gap.** A `Future.delayed(const Duration(milliseconds: 300))` is inserted after each `await push` call within the loop body (before the next iteration), gated by `if (!mounted || skipped) break`. The delay duration is extracted to a top-level constant `kCelebrationGapMs = 300` in `discovery_overlay.dart` so it can be overridden in tests.

No new class, provider, or state object is introduced. The fix is local to `_pushDiscoveryOverlays()` in `scan_summary_screen.dart` and the constant in `discovery_overlay.dart`.

**Consequences:**
- For a user with 15 newly discovered countries, all 15 overlays are shown sequentially; total wait time is approximately 15 × (overlay duration + 300 ms).
- Tests for `_pushDiscoveryOverlays()` must be updated to remove the 5-overlay cap expectation and to verify that all N overlays are shown.
- M56-04 (audio) attaches to `DiscoveryOverlay.initState()` — the sequential loop guarantees only one overlay is mounted at a time, so audio cannot overlap by construction.
- M56-05 (first-visited date) is additive to `DiscoveryOverlay` and does not affect the queue logic.

---

## ADR-109 — M56 Celebration Audio: `audioplayers` Package, App-Layer Only

**Status:** Proposed

**Context:** M56-04 requires a short audio effect to play when a country celebration (`DiscoveryOverlay`) is shown. No audio package currently exists in the project. The mute requirement states that audio must be silent when the device is muted (iOS silent switch / Android volume 0).

Three candidate packages exist for Flutter audio:

- `just_audio`: full-featured streaming player. Appropriate for music playback; has native background audio capabilities. Overkill for a single short SFX clip.
- `audioplayers`: lightweight single-clip playback. Suitable for SFX. Respects the iOS `AVAudioSession` ambient category by default (plays through the mute switch? — no: ambient mode is silenced by the silent switch on iOS). Actively maintained.
- `soundpool`: low-latency pool for short clips. Less widely adopted; API is less ergonomic for single-clip use.

The mute constraint is the deciding factor. On iOS, `AVAudioSession.Category.ambient` is silenced by the hardware mute/silent switch — the correct behaviour for an in-app celebration sound. `audioplayers` defaults to ambient mode on iOS, satisfying the requirement without additional configuration.

**Decision:**

Add `audioplayers: ^6.0.0` (or latest stable at build time) to `apps/mobile_flutter/pubspec.yaml` under `dependencies`. Do not add it to any package — audio is an app-layer concern.

A single bundled audio asset (`assets/audio/celebration.mp3`, ≤ 100 KB, duration < 2 s) is registered in `pubspec.yaml`. The file must be a short positive chime or pop; the specific clip is a Builder decision.

`DiscoveryOverlay._DiscoveryOverlayState.initState()` creates an `AudioPlayer`, calls `player.play(AssetSource('audio/celebration.mp3'))`, and disposes the player in `dispose()`. No provider, no singleton, no shared player state. Each overlay instance owns its own short-lived player. Because ADR-108 guarantees that only one `DiscoveryOverlay` is mounted at a time, concurrent audio playback cannot occur by construction.

No mute-detection code is written. `audioplayers` ambient mode on iOS and the system volume on Android provide the correct mute behaviour automatically.

**Consequences:**
- `audioplayers` adds a native dependency (iOS: AVFoundation; Android: MediaPlayer). The iOS `Podfile.lock` will update.
- `DiscoveryOverlay` gains an `AudioPlayer` field — it must remain `StatefulWidget` (already is).
- Widget tests for `DiscoveryOverlay` that run on the host (non-device) test environment must stub or ignore `AudioPlayer` initialisation. Tests should set `AudioPlayer.global.setLogLevel(LogLevel.none)` and wrap the play call in a try/catch to avoid `MissingPluginException` in host tests.
- The Builder must verify the asset path is consistent in both `pubspec.yaml` and the `AssetSource` call.

---

## ADR-110 — M56 Incremental Scan State: `lastScanAt` is the Boundary Marker

**Status:** Proposed

**Context:** M56-13 requires that after the first full scan, subsequent scans process only newly added images. M56-14 adds a UI control for incremental vs full scan. M56-15 auto-triggers an incremental scan on app open.

The scan pipeline already has partial infrastructure for this:

- `ScanMetadata.lastScanAt` (nullable TEXT, ISO 8601) is stored in the Drift `scan_metadata` table (schema v8). It is written by `scan_screen.dart` after a scan completes.
- `startPhotoScan({DateTime? sinceDate})` in `photo_scan_channel.dart` passes `sinceDate` to the Swift PhotoKit bridge, which filters `PHAsset.creationDate > sinceDate`. This is the incremental boundary (ADR-012).
- The `photo_date_records` Drift table stores `assetId` per scanned photo (added in a prior migration), providing an alternative deduplication mechanism.

**Decision:**

`lastScanAt` in `ScanMetadata` is the sole scan boundary marker for incremental scans. Its semantics are:

- `null` → no full scan has ever completed; incremental scan must not be offered or auto-triggered.
- Non-null ISO 8601 string → the UTC timestamp at which the most recent scan (full or incremental) completed. The next incremental scan passes this value as `sinceDate` to `startPhotoScan`.

**What constitutes "scanned"**: a photo is considered scanned if its `capturedAt` date is ≤ `lastScanAt` at the time the scan was initiated. Photos added to the library after `lastScanAt` are "new" and will be included in the next incremental scan. The PhotoKit `sinceDate` predicate uses asset `creationDate`; this matches `capturedAt` (which is derived from `PHAsset.creationDate`).

**Persistence**: `lastScanAt` is updated in `ScanMetadata` at the end of every successful scan (full or incremental), to the UTC `DateTime.now()` captured immediately before the scan starts (pre-scan timestamp, not post-scan, to avoid a race where photos taken during the scan are silently skipped on the next incremental pass).

**Full scan trigger**: when a full scan is requested (M56-14 or first-time scan), `sinceDate` is omitted from `startPhotoScan`. On completion, `lastScanAt` is written as normal. No additional state is needed to distinguish "full scan completed" from "incremental scan completed" — both update `lastScanAt`.

**Duplicate detection**: because `sinceDate` filters on `PHAsset.creationDate`, and `lastScanAt` is set to the pre-scan timestamp, any photo processed in the prior scan cannot appear in the next incremental scan. The `assetId` deduplication in `photo_date_records` remains as a defence-in-depth guard against clock skew or edge cases.

**Auto-trigger (M56-15)**: `AppLifecycleListener.onResume` (or `WidgetsBindingObserver.didChangeAppLifecycleState`) in `scan_screen.dart` checks `lastScanAt != null` and, if true, calls the incremental scan path. A boolean `_scanInProgress` guard prevents duplicate launches.

**Consequences:**
- No Drift schema migration is required — `lastScanAt` and `assetId` already exist.
- `ScanMetadata` must expose a `hasCompletedFirstScan` getter: `lastScanAt != null`. This is used by M56-15 auto-trigger and M56-14 UI.
- The Builder must verify that the pre-scan timestamp is captured before `startPhotoScan()` is awaited, not after.
- `sinceDate` already flows through the Swift bridge; no native code changes are needed for the incremental path.
- A full scan triggered from M56-14 clears no existing visit data — it re-processes all photos and merges results. Duplicate country detections are suppressed by the existing `upsert` semantics in `VisitRepository` and `TripRepository`.

---

## ADR-111 — M56 Pastel Region Colour Palette: Static Ordered List, Index-Mod Assignment

**Status:** Proposed

**Context:** M56-11 requires that regions in `CountryRegionMapScreen` are filled using a pastel colour palette with at least 12 distinct colours, cycling if a country has more than 12 regions, and with adjacent regions visually distinguishable where practical.

The current implementation uses two hardcoded colours: amber `_kVisitedFill` for visited regions and dark navy `_kUnvisitedFill` for unvisited regions. The task replaces the visited-region fill with a per-region pastel colour.

**Decision:**

A static constant list `kRegionPastelPalette` of exactly 12 `Color` values is defined in `lib/features/map/country_region_map_screen.dart`. The colours are desaturated mid-tones chosen to:

- Remain legible against the dark navy `_kOceanBackground`.
- Avoid conflict with the amber brand colour used for the app's "visited" highlight state.
- Be perceptually distinct from each other at typical map zoom levels.

The 12 colours are assigned to regions by index: `kRegionPastelPalette[regionIndex % 12]`. `regionIndex` is the 0-based position of the region in the sorted list returned by `RegionRepository.loadByCountry(countryCode)`. Sorting is alphabetical by `regionCode` (ISO 3166-2), which is deterministic and stable across rebuilds.

No graph-colouring algorithm is applied. Index-mod assignment does not guarantee that spatially adjacent regions receive different colours, but with 12 colours and typical region counts (≤ 30 for most countries), adjacent conflicts are rare and acceptable for an MVP pastel map.

The exact 12 colour values are a Builder decision. The constraint is: each colour must have HSL lightness ≥ 0.60 (pastel range) and saturation ≤ 0.55, and all 12 must be visually distinct when rendered at ≥ 30×30 px.

Unvisited regions retain the existing `_kUnvisitedFill` (dark navy). Only visited region fills change.

**Consequences:**
- `CountryRegionMapScreen` is the only file that changes for this task. No new file, no new provider.
- `kRegionPastelPalette` is a top-level constant, accessible with `@visibleForTesting` for the widget test that verifies 12+ region countries produce 12 distinct fill colours.
- If `RegionRepository.loadByCountry` returns regions in a non-deterministic order, the palette assignment will be unstable across rebuilds. The sort-by-`regionCode` step is therefore load-bearing and must be explicit in the implementation.
- Selection state (tapped region label) must remain visually distinct from the pastel fills — the existing amber `MarkerLayer` label is unaffected.
- The ADR does not define the 12 colour values — this is a Builder decision, constrained by the HSL bounds above.

---

## ADR-112 — M56 Card Design Image Consistency: Single Pre-Render and Deterministic Param Threading

**Status:** Accepted

**Context:** When a user selects and configures a card design in `CardGeneratorScreen` (template, orientation, year filter, entryOnly, heart order), tapping "Print your card" previously navigated to `ArtworkConfirmationScreen`, which triggered a fresh `CardImageRenderer.render()` call. For non-deterministic templates (Heart/randomized flag order, Passport with stamp scatter/rotation) and for templates with explicit user-controlled params (`entryOnly`, `aspectRatio`), this produced a different image than the one the user had been viewing and configuring. The user was confirming — and potentially purchasing — something different from what they selected.

Additionally, `CardImageRenderer._cardWidget()` ignored `entryOnly`, `aspectRatio`, `heartOrder`, and `dateLabel` entirely, so every call to the renderer used defaults regardless of what was configured.

**Decision:**

1. **Extend `CardImageRenderer.render()` and `_cardWidget()`** to accept and thread `entryOnly`, `cardAspectRatio`, `heartOrder`, and `dateLabel` to all template widgets. This makes every render call parametrically deterministic for a given set of inputs.

2. **Pre-render in `CardGeneratorScreen`**: when the user taps "Print your card", `_navigateToPrint()` calls `CardImageRenderer.render()` with the exact current state (`entryOnly`, `_aspectRatio`, `_heartOrder`, `dateLabel`) before pushing `ArtworkConfirmationScreen`. The `_printing` flag prevents double-taps and disables both action buttons during the render. On render failure, `preRender` is `null` and the flow falls back to in-screen rendering.

3. **`ArtworkConfirmationScreen` accepts `preRenderedResult: CardRenderResult?`**: if non-null, the screen sets `_result` and `_rendering = false` in `initState` without calling `_startRender()`. The user sees and confirms exactly the image that was pre-rendered. If null (fallback path), `_startRender()` is called as before, now passing `entryOnly` and `cardAspectRatio` for correctness.

4. **`LocalMockupPreviewScreen` receives `confirmedAspectRatio` and `confirmedEntryOnly`** from `CardGeneratorScreen`. When the user changes template inside the mockup screen, `_onTemplateChanged()` re-renders with `forPrint: true` for passport, `cardAspectRatio: widget.confirmedAspectRatio`, and `entryOnly: false` (template change resets to entry+exit).

5. **`_CardParams` includes `heartOrder`** so the same-params re-confirmation shortcut (ADR-103) correctly detects when the heart order has changed and requires re-confirmation.

**Consequences:**

- The pre-render adds a brief loading delay when "Print your card" is tapped (spinner shown inside the button). For typical stamp counts on target devices this is sub-second.
- Heart/randomized layouts are now deterministic within a single print flow: the pre-rendered layout is what gets confirmed. The user cannot see the "live" randomized layout and a "different" confirmation layout simultaneously.
- `CardImageRenderer` public API gains four optional named parameters with sensible defaults; all existing call sites without these params continue to compile and produce equivalent output (defaults match prior implicit behaviour for grid).
- Passport template re-renders inside `LocalMockupPreviewScreen` now correctly include print-safe margins.
- The fallback path (pre-render throws) preserves the prior behaviour for robustness; no user-visible failure mode is introduced.

---

## ADR-113 — M57 Passport Stamp Density and Preview Consistency

**Status:** Accepted

**Context:** `PassportLayoutEngine` capped stamp output at 20, producing one stamp per trip with alternating entry/exit labels. Users with 50+ trips expected a distinct entry stamp and exit stamp per trip. Additionally, the live card preview in `CardGeneratorScreen` used `forPrint=false` and was unconstrained in width, while `CardImageRenderer` renders at exactly 340 logical pixels with `forPrint=true` — producing visually different stamp sizes, margins, and positions in the preview and confirmation screens.

**Decision:**

1. **Two stamps per trip (entry + exit):** `PassportLayoutEngine._buildEntries()` now emits two `_StampEntry` records per `TripRecord` when `entryOnly=false`: entry (date = `startedOn`) then exit (date = `endedOn`). `StampData.fromTrip()` gains an optional `stampDate` parameter to support this. When `entryOnly=true`, only the entry stamp is emitted (unchanged).

2. **Cap raised to 200:** `_kMaxStamps` increased from 20 to 200. With 50 trips × 2, total stamps = 100 — well within the new cap.

3. **Dynamic stamp radius:** `baseRadius = 38 × √(min(1, 20/n))` clamped to `[6, 38]` px. For ≤ 20 stamps this equals 38 px (unchanged). Beyond 20 the radius scales down smoothly so stamps remain individually visible while fitting the canvas. Per-stamp ±10% size variety is preserved in non-print mode.

4. **Dynamic grid:** `gridCols` and `gridRows` scale with stamp count and canvas aspect ratio so cells distribute evenly across both landscape and portrait canvases.

5. **Relaxed collision threshold:** Minimum placement distance lowered from 80% to 50% of combined radii, allowing organic overlapping at high stamp counts. Best-effort fallback is unchanged.

6. **`wasForced` threshold lowered to 8 px** (consistent with the new 6 px minimum radius).

7. **Preview consistency:** `CardGeneratorScreen._buildTemplate()` passes `forPrint=true` to `PassportStampsCard` so margin and radius logic match the renderer. The preview `InteractiveViewer` is wrapped in `ConstrainedBox(maxWidth: 340)` so `PassportLayoutEngine` receives the same canvas width as `CardImageRenderer`.

**Consequences:**

- Users with many trips now see all stamps — at visually smaller but readable sizes — rather than a silent 20-stamp cap.
- Entry and exit stamps for the same trip show distinct dates (`startedOn` vs `endedOn`), making the passport metaphor more accurate.
- The live preview and the "Confirm your artwork" image are now pixel-consistent for passport cards.
- For cards with ≤ 20 trips, stamp size is unchanged (38 px); the visual difference is only apparent at higher trip counts.
- The `_buildEntries` extraction makes the layout loop cleaner and removes the interleaved `tripIdx`/`codeIdx` coupling.

---

## ADR-114 — M58 2.5D T-Shirt Mockup: Asset Format, Flip Animation, and Screen Layout

**Status:** Accepted

**Context:** `LocalMockupPreviewScreen` uses ten 600×800 RGB PNG placeholder images for all shirt mockups. The mockup area shares screen space equally with an options panel, leaving insufficient room for the user to appreciate the design. Switching front/back requires tapping a text chip; there is no swipe gesture or flip animation; there is no zoom.

**Decision:**

1. **Asset format — RGBA PNG at 1200×1600.** Replace all ten `assets/mockups/tshirt_*.png` files with 1200×1600 RGBA (transparent alpha channel) images with a proper shirt silhouette shape. Transparent background allows the canvas background colour to show through the shirt edges without a rectangular cut-off artefact. The same aspect ratio (3:4) is preserved so `LocalMockupPainter`'s existing `BoxFit.cover` logic continues to work. `printAreaNorm` coordinates are recalibrated to the new layout.

2. **Full-screen layout.** `LocalMockupPreviewScreen`'s body switches to a `Column` where the mockup `Expanded` widget takes all available space minus a fixed-height bottom bar (≈ 80 px) and the action button. Options are moved into a `DraggableScrollableSheet` anchored below the compact strip. The compact strip shows only the colour swatch row and a "More options" drag handle. This gives the mockup ~80% of the visible viewport. The `Approve / Complete` button remains outside the sheet so it is always reachable.

3. **`_ShirtFlipView` StatefulWidget.** Extracted to own the `AnimationController` (duration 350 ms, `Curves.easeInOut`), `GestureDetector` (horizontal drag), and `Transform` widget. It accepts `frontShirt`, `backShirt`, `frontSpec`, `backSpec`, `frontArtwork`, `backArtwork`, `showFront`, and `onFlipped`. The perspective transform uses `Matrix4.rotationY(angle)` with `matrix.setEntry(3, 2, 0.001)`. At the 90° midpoint (`controller.value >= 0.5`) the displayed face swaps, so the correct shirt image appears as the card "comes around." `LocalMockupPreviewScreen` listens to `onFlipped` and updates `_placement` to keep `_resolvedVariantGid` (checkout) in sync.

4. **Colour swatch picker.** The Colour `ChoiceChip` row is replaced with 32 px diameter filled `InkWell` circles. Selected swatch has a 2 px `colorScheme.primary` outline. The five hard-coded colour values (Black, White, Navy, Heather Grey, Red) are defined as constants in the screen file. Tapping a swatch calls the existing `_onVariantOptionChanged`.

5. **Zoom + pan.** The mockup canvas inside `_ShirtFlipView` is wrapped in `InteractiveViewer` (`minScale: 1.0, maxScale: 4.0`). A `TransformationController` is owned by `_ShirtFlipView`; double-tap resets it to identity. The controller is reset (`_transformationController.value = Matrix4.identity()`) whenever `onFlipped` fires or the parent notifies a colour change via a `key` change.

**Consequences:**

- `LocalMockupPainter` is unchanged; the compositing logic works the same at any asset size because it normalises coordinates via `printAreaNorm`.
- `ProductMockupSpecs.printAreaNorm` values must be re-calibrated for the new shirt layout; the debug overlay (`debugPrintArea: true`) can be used to verify calibration visually.
- The `_ShirtFlipView` widget is private to `local_mockup_preview_screen.dart`; no new public API.
- `MockupApprovalScreen` and `createMerchCart` are unchanged.
- The `InteractiveViewer` reset-on-flip ensures users cannot get lost at high zoom when switching sides.

---

## ADR-115 — M59 Photoreal Shirt Mockup: Split-Image Source Cropping and 3-Layer Fabric Compositing

**Status:** Accepted

**Context:**
M58 replaced 600×800 RGB placeholder images with programmatically generated 1200×1600 RGBA shirt silhouettes. While correctly shaped, these silhouettes lack photorealism — no fabric texture, no folds, no wrinkles. A single photoreal asset (`shirt-mockup-final.jpg`, 1600×1066) has been provided, with the front view on the left half and the back view on the right half.

Two decisions are needed: (1) how to address front/back from a single source image, and (2) how to composite artwork so it looks embedded rather than pasted on top.

**Decision 1 — Source cropping via `srcRectNorm` on `ProductMockupSpec`:**
Add an optional `Rect? srcRectNorm` field to `ProductMockupSpec`. When set, `LocalMockupPainter` uses only that normalised sub-rectangle of the source image when drawing the shirt background. Front specs use `Rect.fromLTWH(0.0, 0.0, 0.5, 1.0)` (left half); back specs use `Rect.fromLTWH(0.5, 0.0, 0.5, 1.0)` (right half). Null means use the full image (backward compatible with the poster spec).

This avoids splitting the image at load time (no extra `ui.Image` allocation) and keeps the entire cropping policy declarative in the spec.

**Decision 2 — 3-layer fabric-embedding compositing in `LocalMockupPainter`:**
Replace the single artwork layer + inner shadow with three layers:
1. Shirt background (cropped via `srcRectNorm`, BoxFit.cover).
2. Artwork at 0.92 opacity (BoxFit.contain inside print area), clipped to print area.
3. Shirt shading overlay: the same shirt image drawn again, cropped to print area, at 0.25 opacity with `BlendMode.multiply`. This reapplies the fabric folds and shadows over the artwork, creating the "embedded" effect.

The inner shadow from M58 is removed — the shading overlay subsumes it and looks more natural.

**Decision 3 — Single JPG shared for all colour variants:**
All five colour variants (Black, White, Navy, Heather Grey, Red) reference `shirt-mockup-final.jpg`. The colour swatch picker continues to function (it controls the Printful order colour), but the in-app preview shows the same photoreal shirt for all swatches. Per-colour photo assets are deferred to a future milestone.

**Consequences:**
- `ProductMockupSpec` gains one nullable field; all call sites are backward compatible.
- `LocalMockupPainter.paint()` gains one additional `drawImageRect` call (the shading overlay); performance impact is negligible for a single `CustomPaint`.
- The screen loads one image (the JPG) instead of two (front + back PNGs), halving asset load time.
- The preview colour will not match the swatch selection until per-colour photo assets are added. This is a known limitation accepted for M59.

---

## ADR-117 — M61 Passport Card Refinement: Safe Zones, Color Customization, and Rendering Consistency

**Status:** Accepted

**Context:**
Milestone 61 addresses design inconsistencies and layout issues in the Passport-style card. Key issues include:
1. Stamps overlapping text areas or leaving too much blank space on some screens.
2. Background appearing with a green tint instead of pure white/transparent.
3. Text rendering artifacts (underlines) and inconsistency between preview and confirmation screens.
4. Lack of user customization for stamp/date colors.
5. Inconsistent layout density between the generator screen and checkout flow.

**Decisions:**

**1. Explicit Safe Zones in `PassportLayoutEngine`:**
The layout engine will now enforce two safe zones where no stamps can be placed:
- **Title Safe Zone (Top):** The top 18% of the card height. This area is reserved for the centered title.
- **Branding Safe Zone (Bottom-Left):** A 110x40 logical pixel area (scaled by DPI) at the bottom-left corner. This area is reserved for the "Roavvy" wordmark and country count.
Stamps that intersect these zones will be rejected during the layout pass, ensuring zero overlap with text.

**2. Unified Layout Parameters & Scaling:**
To guarantee identical layout across all screens:
- All screens (Generator, Confirmation, Mockup) MUST use the exact same `Uint8List` bytes generated by the initial `CardImageRenderer.render()` call.
- The `CardGeneratorScreen` preview will be constrained to the same aspect ratio and logical width (340px) as the final print renderer to ensure the `PassportLayoutEngine` produces identical results.
- No re-rendering is allowed in `ArtworkConfirmationScreen` or `MerchVariantScreen` unless the user explicitly changes a design parameter (template, color, text).

**3. User-Configurable Stamp and Date Colors:**
`CardGeneratorScreen` will provide UI controls for:
- `stampColor`: A choice of 6 ink families or a "Multi-color" (randomized) mode.
- `dateColor`: Option to match the stamp color or use a fixed secondary ink.
These preferences are passed to `PassportStampsCard` and used by `StampPainter`.

**4. Pure White / Transparent Background:**
`PaperTexturePainter` is updated to remove the warm parchment tint (`0xFFF5ECD7`) when `transparentBackground` is true. For mobile display, the background will default to the app's surface color (pure white). The generated PNG for print will have a fully transparent alpha channel.

**5. Integrated Text Rendering (No Overlays):**
All text (Title and Branding) will be drawn directly onto the `Canvas` within the `PassportStampsCard`'s `CustomPainter` pass. This eliminates "underline" artifacts caused by Flutter's default `Text` widget inheritance in some `Material` contexts and ensures text is part of the flattened image.

**6. Editable Title Text:**
The auto-generated title (e.g., "12 Countries · 2024") can be overridden by the user in `CardGeneratorScreen`. The custom string is passed to the layout engine to calculate centered positioning within the top safe zone.

**Consequences:**
- `PassportLayoutEngine` signature changes to include safe zone definitions.
- `CardGeneratorScreen` state expanded to include `titleOverride`, `stampColor`, and `dateColor`.
- `PassportStampsCard` gains `CustomPainter` logic for Title and Branding.
- Visual density will be high and consistent because the same image is scaled rather than re-laid out.
- Underline artifacts will be eliminated as standard `Text` widgets are replaced by `TextPainter.paint()` calls.

---

## ADR-118 — M61 Grid Card Upgrade: Shared Title State and SVG Layout Engine

**Status:** Accepted

**Context:**
Milestone 61 replaces the emoji-based `GridFlagsCard` with a product-quality SVG flag layout. It must support landscape/portrait resizing, reactive updates when filters change, and allow the user to override the auto-generated title. The title override must apply to all card templates (Grid, Passport, Heart).

**Decisions:**

**1. Shared Title State in `TravelCard`:**
The `TravelCard` domain model will gain a `String? titleOverride` property. This allows `CardGeneratorScreen` to present a unified `TextField` that updates the state. All card templates (`GridFlagsCard`, `PassportStampsCard`, `HeartFlagsCard`) will consume this overridden title instead of their own generated text when it is present.

**2. Grid Math & Layout Engine:**
The grid will dynamically calculate rows and columns to perfectly pack `N` flag images of aspect ratio 4:3 into the given bounding box `(W, H)`. It will minimize wasted space and gracefully handle varying aspect ratios (e.g. portrait vs. landscape constraints). Emojis and `LayoutBuilder` text sizing will be fully removed in favor of this geometric solver.

**3. SVG Rendering via `FlagImageCache`:**
The new `GridFlagsCard` will use the `FlagTileRenderer` and `FlagImageCache` developed in M46 for the Heart Card. This ensures high-performance, pixel-perfect SVG rendering for export.

**Consequences:**
- The `TravelCard` model schema must be updated (backward compatible serialization).
- Existing `GridFlagsCard` tests will break as it moves from text rendering to custom image rendering.
- Re-layout happens instantly when the container bounds change or when the country list is altered via the timeline filter.

---

## ADR-119 — M62 Front Chest Ribbon Design: Dual-Sided Merch Architecture

**Status:** Accepted

**Context:**
Milestone 62 introduces a new standalone design specifically for the front chest of t-shirts: the "Front Chest Ribbon Design". It resembles a military medal ribbon, displaying Roavvy branding, exactly 8 flags per row, and the user's traveler status. Previously, the merch mockups showed the same card design (Grid, Heart, Passport, Timeline) on both sides or only supported one card layout.

**Decisions:**

**1. Dual-Image Mockup Architecture:**
The `LocalMockupPreviewScreen` will now distinguish between the front and back artwork. 
- The `backArtwork` will be the user's selected `TravelCard` (rendered as `_artworkImage`).
- The `frontArtwork` will be a dynamically generated image of `CardTemplateType.frontRibbon`.
- `CardImageRenderer` will be used to generate this front image asynchronously when the mockup screen initializes, applying the correct text color to contrast with the selected t-shirt color.

**2. `FrontRibbonCard` Component & Layout Math:**
A new `FrontRibbonCard` widget (and underlying `CustomPainter`) will be created. The layout engine for this design will strictly enforce exactly 8 flags per row, automatically scaling the flag tiles so the 8 tiles perfectly fill the 4-inch (conceptual) width. The background will be `Colors.transparent`.

**3. Dynamic Text Color via Parent State:**
The ribbon requires white text on dark shirts and black text on white shirts. The `LocalMockupPreviewScreen` will pass a `textColor` parameter (computed from the active `_colour` swatch) down to the `CardImageRenderer`, which passes it to the `FrontRibbonCard`.

**4. Data Model Augmentation:**
`CardTemplateType` gains `frontRibbon`. However, `frontRibbon` is not intended to be a standalone `TravelCard` saved to the database in the same way; rather, it is an automatic complement to t-shirt merch. The rendering parameters (e.g., `travelerLevel`) will be injected at render-time using the user's computed `XpState`.

**Consequences:**
- The print area for the front t-shirt mockup (`_kTshirtFrontPrintArea`) in `ProductMockupSpecs` must be recalibrated to reflect a small left-chest placement instead of a large center-chest placement.
- Changing the shirt color triggers a re-render of the front ribbon to recalculate text contrast, adding slight latency during color swaps.
- The `TravelCard` model does not need schema changes for this milestone beyond adding the enum value, as the ribbon configuration is derived at render-time.

---

## ADR-119 — M62 Create Card UX Redesign: Two-Stage Flow, Carousel Picker, and Standardised Editor

**Status:** Accepted

**Context:**
`CardGeneratorScreen` stacks template chips, multiple option-chip rows, a title editor, passport colour pickers, orientation chips, and a year slider above a small constrained card preview. The visual hierarchy is flat, controls have equal weight, and the live preview is too small. Amber/gold text and underline styles that are appropriate inside the rendered card bleed into the editor UI, creating an inconsistent aesthetic. There is no "choose a style first" mental model.

**Decision:**

Split `CardGeneratorScreen` into two focused screens:

**1. `CardTypePickerScreen`** — a full-screen horizontal carousel of card-type tiles. Each tile shows a live scaled-down preview of that card type using the user's actual data, plus the type name and a tagline. One tap navigates to `CardEditorScreen` with that type pre-selected. All existing entry points (`StatsScreen`, `LevelUpSheet`, `ScanSummaryScreen`, `MapScreen`, `MilestoneCardSheet`) push `CardTypePickerScreen` instead of `CardGeneratorScreen`.

**2. `CardEditorScreen`** — receives `CardTemplateType` as a constructor parameter and hosts:
- A compact control strip (inline title `TextField` + orientation `IconButton.outlined`).
- An Entry/Exit segmented toggle (Passport only, shown below the strip).
- A template-specific option row: Grid and Heart show a 4-option sort picker (Shuffle / By Date / A→Z / By Region); Passport shows a 3-option stamp-colour picker (Multicolor / Black / White).
- A conditional year range slider (when trips span multiple years).
- A maximally large live card preview in an `InteractiveViewer` (`Expanded`).
- Share and Print action buttons fixed at the bottom.

**Sort order for Grid:** `HeartLayoutEngine._sortCodes` is promoted to `HeartLayoutEngine.sortCodes` (public static). Grid applies this function to the displayed codes list before passing to `GridFlagsCard`, so the template widget remains stateless with respect to ordering.

**Passport stamp colour modes (`PassportColorMode` enum, 3 values):**
- `multicolor` → existing default (`stampColor = null`, parchment background).
- `black` → `stampColor = Color(0xFF1A1A1A)`, `dateColor = Color(0xFF1A1A1A)`, parchment background.
- `white` → `stampColor = Colors.white`, `dateColor = Colors.white`, `transparentBackground = true`; the editor wraps the preview in `ColoredBox(color: Colors.black)` so white stamps are visible. The print-time render also uses `transparentBackground = true` (white ink on transparent — reuses ADR-117 flag).

**Typography:** No `TextDecoration.underline` and no amber/gold text appear anywhere on either editor screen. The amber accent is used only for a subtle selected-state border/fill on the sort-order and colour-mode chips.

`CardGeneratorScreen` and its private widget classes remain in file but are no longer referenced from any navigation callsite. `ArtworkConfirmationScreen` and `LocalMockupPreviewScreen` are untouched; `CardEditorScreen` passes them the same pre-rendered bytes via the same `_CardParams` + `CardImageRenderer.render()` contract as `CardGeneratorScreen` did.

**Consequences:**
- Entry into the card flow is two taps minimum (picker → editor → action). This is intentional — the picker showcases templates and sets the "choose a style first" mental model.
- `HeartFlagOrder` is now shared between Heart and Grid ordering — no new enum required.
- `PassportColorMode` is a new enum scoped to `card_editor_screen.dart`; it is not added to `shared_models` because it is a pure UI concept.
- Existing widget tests for `CardGeneratorScreen` are migrated to test `CardEditorScreen` directly; the `card_generator_heart_order_test.dart` file is replaced by a `card_editor_screen_test.dart` file.

---

## ADR-120 — M63 Dual-Placement T-Shirt: Multi-File Print and Mockup Architecture

**Status:** Accepted

**Context:**
M62 built a dual-image local mockup preview — front chest ribbon + back travel card — but the backend pipeline (`createMerchCart`, `shopifyOrderCreated`) still handles a single print file and single mockup URL. Specifically:

1. `_onApprove()` sends only `clientCardBase64` (the back artwork); the front ribbon image is never uploaded.
2. `createMerchCart` generates one print file and calls `generatePrintfulMockup` for one placement.
3. `shopifyOrderCreated` submits one file with `type: 'default'` to Printful, discarding the back design.
4. The mobile ready-state shows a single `mockupUrl` regardless of which side is displayed.

This milestone extends the pipeline to handle both placements end-to-end.

**Decisions:**

**1. Dual print file storage: two files per order**

`MerchConfig` gains `frontPrintFileStoragePath`, `frontPrintFileSignedUrl`, `frontPrintFileExpiresAt`, `backPrintFileStoragePath`, `backPrintFileSignedUrl`, `backPrintFileExpiresAt`, `frontMockupUrl`, `backMockupUrl`. The deprecated single-file fields (`printFileStoragePath`, `printFileSignedUrl`, `printFileExpiresAt`, `mockupUrl`, `placement`) are kept as optional fields for backward compatibility with existing Firestore documents. New orders always use the dual-file fields.

**2. Request shape: `frontCardBase64` + `backCardBase64`**

`CreateMerchCartRequest` gains `frontCardBase64?: string` (front ribbon PNG, base64) and `backCardBase64?: string` (back card PNG, base64). The existing `clientCardBase64` field is accepted as an alias for `backCardBase64` to avoid breaking any callers not yet updated. Both are subject to the existing 5.5M character guard.

**3. Front ribbon canvas pre-composition (Option A)**

Printful's DTG front placement covers the full print area (nominally ~12×16 inches). There is no native "chest-left" placement type in the Gildan 64000 catalog. To produce a small left-chest print:

- The `createMerchCart` function receives the ribbon PNG (small, transparent background).
- Using `sharp`, the function composites the ribbon onto a transparent `4500×5400` canvas at a defined left-chest offset (`_kRibbonOffsetLeft = 750, _kRibbonOffsetTop = 900`, equivalent to ~5 in from left, ~6 in from top at 150 DPI).
- The ribbon is scaled to `_kRibbonWidthPx = 600` (4 in at 150 DPI) before compositing.
- The composite is uploaded as `print_files/{configId}_front.png`.
- These offset constants are exported as named values so they can be updated after test-order calibration without restructuring the code.

Option B (Printful positioning parameters in file submission) was considered and rejected: the v2 orders API does not expose arbitrary file placement coordinates for DTG orders; placement is controlled by print area, not per-file offsets.

**4. Single dual-placement Printful mockup task**

`generatePrintfulMockup` is replaced by `generateDualPlacementMockups(variantId, frontUrl, backUrl)`. A single `POST /v2/mockup-tasks` request specifies both placements:
```json
"placements": [
  { "placement": "front", "technique": "dtg", "layers": [{ "type": "file", "url": frontUrl }] },
  { "placement": "back",  "technique": "dtg", "layers": [{ "type": "file", "url": backUrl  }] }
]
```
The poll response includes mockups for both placements in `catalog_variant_mockups[].mockups`. Both are extracted and returned as `{ frontMockupUrl, backMockupUrl }`. This avoids two round-trip API calls and stays within the existing 20s polling window.

**5. Printful order: explicit placement file types**

`shopifyOrderCreated` submits:
```json
"files": [
  { "url": "...", "type": "front" },
  { "url": "...", "type": "back" }
]
```
`type: 'default'` is no longer used for new orders. For legacy `MerchConfig` documents where `frontPrintFileStoragePath` is null, the function falls back to the prior single-file behavior (`type: 'default'` with `config.printFileStoragePath`). This ensures historical orders are not broken.

**6. Mobile: `_frontRibbonBytes` stored alongside `_frontRibbonImage`**

`LocalMockupPreviewScreen` stores `Uint8List? _frontRibbonBytes` from `CardRenderResult.bytes` when `_loadFrontRibbonImage()` runs. This avoids a redundant PNG re-encode from the decoded `ui.Image`. `_onApprove()` sends both `frontCardBase64` (from `_frontRibbonBytes`) and `backCardBase64` (from `_artworkBytes`). The `placement` field is removed from the callable payload (placement is now always both).

**7. Ready-state flip-tracking**

`LocalMockupPreviewScreen` adds `_frontMockupUrl`, `_backMockupUrl`, and `_showingFront`. `_onFlipped(bool showFront)` (previously a no-op) now calls `setState(() => _showingFront = showFront)`. The ready-state mockup image renders `_showingFront ? _frontMockupUrl : _backMockupUrl`, falling back to the local mockup when the URL is null.

**Consequences:**
- Storage cost doubles for t-shirt orders (two print files vs one). At current scale this is negligible.
- `createMerchCart` Cloud Function timeout is unchanged (300s); dual print generation adds ~1s; dual mockup polling uses one task not two.
- Old Firestore documents remain valid; `shopifyOrderCreated` backward compat guard is required indefinitely (documents are never rewritten).
- `MockupApproval.placementType` is deprecated — new approvals omit it; existing records are unaffected.
- Test-order calibration of `_kRibbonOffsetLeft` / `_kRibbonOffsetTop` is required after deployment; initial values are an informed estimate.


---

## ADR-121 — M64 Stamp Color Selection Moved to T-Shirt Design Stage

**Status:** Accepted

**Context:**
`CardEditorScreen` showed a `_PassportColorPicker` (multicolor / black / white) before the user had chosen a shirt color. The user then confirmed artwork at `ArtworkConfirmationScreen` before entering the t-shirt designer. This sequence made bad combinations (white stamps on white shirt; parchment patch on black shirt) possible and meant the approval was given before the full design context was visible.

**Decisions:**

**1. Remove `_PassportColorPicker` from `CardEditorScreen`**
The stamp color picker is removed from the card creation stage entirely. `CardEditorScreen` renders passport cards with `stampColor: null` (multicolor default). The `passportColorMode` field is removed from `_CardParams`. Layout-affecting fields (entry/exit, title, year range) remain unchanged.

**2. Skip `ArtworkConfirmationScreen` in the passport→merch path**
`CardEditorScreen._onPrint()` navigates directly to `LocalMockupPreviewScreen` with `artworkConfirmationId: null`. The `ArtworkConfirmation` Firestore record is created inline inside `_onApprove()` — this path already exists and is already tested. The `ArtworkConfirmation` will now carry the correct final `stampColor`/`dateColor`/`transparentBackground` values rather than a premature upfront choice.

**3. `PassportColorMode` moves to `lib/features/merch/merch_stamp_color.dart`**
The enum and its extension (`stampColor`, `dateColor`, `transparentBackground`) are moved to a file shared between `card_editor_screen.dart` (if it still needs the type for any reason) and `local_mockup_preview_screen.dart`. This avoids a dependency from `merch` on `cards`.

**4. Stamp color selection added to `LocalMockupPreviewScreen` (passport + t-shirt only)**
A `PassportColorMode _passportColorMode` field is added to screen state. A `_PassportStampColorPicker` chip row appears below the shirt colour swatches when `_isTshirt && _template == CardTemplateType.passport`. The picker is hidden for all other templates and for poster products.

**5. Auto-suggest and hard-disable rules**

Suggest (applied whenever shirt color changes):
- Black → white stamps
- White → black stamps
- Navy → white stamps
- Heather Grey → black stamps
- Red → white stamps

Hard-disabled combos (chip greyed, non-tappable):
- Black shirt: black stamps, multicolor disabled
- White shirt: white stamps disabled
- Navy shirt: black stamps, multicolor disabled
- Red shirt: multicolor disabled
- Heather Grey: nothing disabled

Rationale: `multicolor` uses a parchment background — a rectangular patch that looks bad on dark shirts. `white` stamps on a white shirt are invisible. `black` stamps on black/navy are near-invisible.

**6. `_passportColorMode` wires to `_artworkVariantIndex`**
The existing `_artworkVariants[3]` mechanism is reused:
- `multicolor → index 0` (initial multicolor render from `widget.artworkImageBytes`)
- `black → index 1` (re-rendered with `stampColor: Color(0xFF1A1A1A), transparentBackground: true`)
- `white → index 2` (re-rendered with `stampColor: Colors.white, transparentBackground: true`)

Layout is deterministic (same seed = same stamp positions), so re-rendering with a different color produces identical stamp placement — only the ink color changes.

**7. Vertical swipe variant cycling removed**
The hidden vertical swipe gesture that previously cycled through stamp color variants is removed. The explicit picker UI replaces it.

**Consequences:**
- The passport card creation stage is simpler (no color decision required there).
- `ArtworkConfirmation` is always created with the correct final stamp color.
- White-on-white and other visually invalid combos are prevented at the UI level.
- Non-passport templates and poster products are unaffected.
- `_CardParams` loses `passportColorMode`; existing re-confirmation shortcut logic is unaffected (field simply not compared).
- `ArtworkConfirmationScreen` class is retained but no longer reachable via the passport→merch path. It may still be used by other potential entry points in future.

---

## ADR-116 — M60 Globe Map Orthographic Projection and Gesture Navigation

**Status:** Accepted

**Context:**
The app provides a flat 2D country/region map, but we introduced a 3D orthographic globe view (`GlobeMapWidget`) for M60 to enhance visual delight. The interaction mechanics of panning a 3D globe using a 2D screen coordinate system need to feel intuitive.

**Decisions:**

**1. Pure-Dart Orthographic Projection**
- We use a pure-Dart `GlobeProjection` class that mathematically transforms lat/lng pairs to screen `Offset`s based on a rotation matrix (`rotLat`, `rotLng`) and scale.
- We do not use WebGL or heavy 3D rendering engines; `CustomPainter` draws projected polygons natively.

**2. Gesture Mapping (Pan / Spin Direction)**
- A standard map pan feels like "dragging the paper under your finger." A 3D object spin feels like "pushing the surface."
- **Up / Down (Latitude):** Moving the finger *up* the screen pushes the globe *up* (tilting the north pole away), effectively scrolling the view South. This means `rotLat` subtracts the vertical delta (`- delta.dy`).
- **Left / Right (Longitude):** Moving the finger *left* on the screen drags the globe *left* (spinning it East-to-West), effectively moving the view East. To achieve this, `rotLng` adds the horizontal delta (`+ delta.dx`).
- This mixed polarity (`- delta.dy` for latitude, `+ delta.dx` for longitude) creates the most natural, expected physical interaction for the user when spinning the globe.
- **Do not reverse these directions.** They have been explicitly tuned and approved by the user.

**3. Antimeridian Handling**
- Rings that cross the antimeridian (±180° longitude) are detected and split mathematically by the projection layer to prevent polygon rendering anomalies (where a country stretching from 179° to -179° would draw across the entire globe face).

**Consequences:**
- Zero dependency on heavy mapping SDKs.
- Polygons and styling exactly match the 2D flat map because they consume the same Riverpod data models.
- Gestures feel like spinning a physical globe rather than dragging a 2D map.


## ADR-125 — M70 Passport Stamp UX: Portrait Lock, Shuffle Seed, Year-Free Titles

**Status:** Accepted

**Context:**
The passport stamp card editor had three UX problems:
1. The landscape/portrait orientation toggle applied to all card templates including passport, adding unnecessary complexity with little value — passport stamps read naturally in portrait only.
2. Users had no way to explore different stamp arrangements; the layout was always deterministic (hash of country codes), making it feel static.
3. Title generation — both AI and rule-based fallback — included year information in the output, duplicating the date label that already appears on the card.

**Decisions:**

**1. Passport card fixed to portrait**
The orientation `IconButton` in `_ControlStrip` is conditionally hidden when `templateType == CardTemplateType.passport`. `initState` forces `_portrait = true` when the template is passport, preventing landscape state being inherited from a previous session. The orientation toggle remains fully functional for Grid, Heart, Timeline, and FrontRibbon templates.

**2. Stamp shuffle via nullable seed**
`PassportStampsCard` gains a nullable `int? seed` parameter (constructor remains `const`). The seed threads through `_PassportPagePainter` → `PassportLayoutEngine.layout(seed:)`, which already supported this via `effectiveSeed = seed ?? countryCodes.join().hashCode`. `_CardEditorScreenState` holds `_stampLayoutSeed` (initially `null` = deterministic default). A `Icons.shuffle_rounded` `IconButton.outlined` in `_ControlStrip` — visible only for passport template — fires `setState(() => _stampLayoutSeed = Random().nextInt(0x7FFFFFFF))`. The seed is session-persistent: navigating away and back resets it only if `initState` is called again (i.e. the screen is fully removed from the tree).

**3. Year removed from title generation**
- `_generateTitle()` in `CardEditorScreen` no longer computes `startYear`/`endYear` or passes them to `TitleGenerationRequest`. The year computation block is deleted.
- `ios_title_channel.dart` no longer sends `startYear` / `endYear` in the method channel args map.
- `AiTitlePlugin.swift` no longer reads `startYear`/`endYear`. The prompt is rewritten to: request 2–4 words, explicitly forbid years and colons, and provide region context instead. System instructions reinforce playful/human tone. Post-processing strips `"`, `'`, `:` and collapses whitespace.
- `RuleBasedTitleGenerator` removes `_yearSuffix()` entirely. Sub-region clusters expanded from 4 to 16 (Nordic Wander, Baltic Loop, British Isles, Iberian Road, Alpine Escape, Benelux, Mediterranean Escape, Southern Europe, Balkan Trail, East Asia, Southeast Asia, Indian Subcontinent, Indian Ocean, Pacific Islands, Central America, Caribbean Hop). Continent labels updated to more evocative alternatives (Euro Wander, Asian Escape, etc.).

**Consequences:**
- Portrait-only passport reduces test surface and eliminates a class of layout bugs.
- Shuffle is fast (pure Dart, synchronous seed change → `setState`); layouts are visually distinct across the `0x7FFFFFFF` seed space.
- Titles never include years; the card's date label (e.g. "2018–2024") is the sole year reference.
- `TitleGenerationRequest.startYear` / `.endYear` fields are retained on the model for potential future use but are no longer populated at the call site.
- Post-processing in Swift is additive (strip-only); it cannot introduce regressions in the AI path.
