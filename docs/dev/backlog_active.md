# Backlog — Active Milestones

> Upcoming work only. Completed milestones live in `docs/dev/backlog.md`.
> Mobile milestones take priority over web (see memory: feedback_mobile_first).

---

## Next up (mobile-first order)

### M89 — Hero Image Detection & Trip Labels
**Goal:** During photo scanning, select up to 5 metadata-scored candidates per trip; after scan completes, run on-device Vision framework labelling on candidates; persist a structured hero image record (labels + score + rank) in Drift. No photos leave the device. Scan performance unaffected.
**Phase:** 19 — Personalisation & Memory
**Scope in:** `packages/shared_models` (HeroImage model, HeroScoringEngine); Drift schema v11 (`hero_images` table); `HeroCandidateSelector`, `HeroImageRepository`, `HeroAnalysisService` (Dart); `HeroImageAnalyzer`, `LabelNormalizer` (Swift); MethodChannel bridge; Riverpod provider.
**Scope out:** Any UI displaying hero images; Firestore sync; landmark detection; web; Android.
**Depends on:** Existing scan pipeline (PhotoDateRecord + TripRecord + assetId in schema v9+)
**Full plan:** `docs/dev/milestones/m89-hero-image-detection.md`
**Status:** ✅ Complete (2026-04-29).

---

### M90 — Hero Image UI Surfaces
**Goal:** Surface M89 hero images in the three screens users already use: journal trip cards (full-bleed header), country detail sheet (cover image), and scan summary ("best shot" moment). Add hero override picker so users can swap their hero image from within each screen.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89
**Scope in:** `journal_screen.dart`, `country_detail_sheet.dart`, `scan_summary_screen.dart`; new `HeroImageView` widget; `ThumbnailPlugin.swift` (thumbnail MethodChannel).
**Full plan:** `docs/dev/milestones/m90-hero-image-ui.md`
**Status:** ✅ Complete (2026-04-30).

---

### M91 — Memory Pulse
**Goal:** On travel anniversaries, show an in-app memory card on the map screen and an optional local push notification with label-driven copy ("3 years ago today — Aegean sunrise in Greece 🌅"). Fully on-device; no server scheduling.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (labels), M90 (HeroImageView)
**Scope in:** New `memory_pulse_service.dart`, `memory_pulse_card.dart`; `notification_service.dart` extension; `map_screen.dart`; `providers.dart`.
**Full plan:** `docs/dev/milestones/m91-memory-pulse.md`
**Status:** In Progress (2026-04-30).

---

### M92 — Label-Powered Auto Titles
**Goal:** Enrich the existing rule-based title generator with scene and mood labels from hero images. "Greece 2024" becomes "Aegean Sunset". Graceful fallback to geography titles when no labels available.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89
**Scope in:** `rule_based_title_generator.dart`, `title_generation_models.dart`, `card_editor_screen.dart`.
**Full plan:** `docs/dev/milestones/m92-label-powered-titles.md`
**Status:** ✅ Complete (2026-04-30).

---

### M93 — Hero Image Share Card Background
**Goal:** Optional hero photo background layer in passport and grid card editors. User toggles "Photo background" to place their travel photo behind stamps/flags. Background composited at print resolution for sharing and merch.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89, M90
**Scope in:** `card_editor_screen.dart`, `card_templates.dart` (PassportStampsCard + GridCard), `card_image_renderer.dart`; new `CardBackgroundPicker`; `ThumbnailPlugin.swift` (full-res fetch).
**Full plan:** `docs/dev/milestones/m93-hero-share-card-background.md`
**Status:** Not started.

---

### M94 — Year in Review
**Goal:** Full-screen annual travel summary: timeline of hero images per trip, key stats, highlights ("most common scene: beach"), and a shareable 1080×1920 mosaic card. Triggered by New Year notification.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89, M90
**Scope in:** New `year_in_review_screen.dart`, `year_in_review_service.dart`; `map_screen.dart` (Dec/Jan entry chip); `card_image_renderer.dart` (YIR card render); `notification_service.dart` (New Year notification).
**Full plan:** `docs/dev/milestones/m94-year-in-review.md`
**Status:** Not started.

---

### M86 — Map Screen Enhancements
**Goal:** Globe auto-rotation (east→west, pauses on interaction), lighter ocean background, horizontal visited-country flag strip (globe mode, tap → snap to country), tappable stats strip (Countries → CountriesListScreen, Achievements → StatsScreen), tappable XP level bar → progression sheet.
**Phase:** 16 — Map UX Polish
**Scope in:** `globe_map_widget.dart`, `globe_painter.dart`, `map_screen.dart`, `stats_strip.dart`, `xp_level_bar.dart`, `core/providers.dart`.
**Scope out:** Flat map mode enhancements; Journal country map; new achievement screen; web.
**Status:** ✅ Complete (2026-04-27).

---

### M77 — Incremental Scan Redesign ← CURRENT
**Goal:** Globe pre-populated with known countries, country list shows existing visits from scan start, assetId-based dedup for robustness, instant visual feedback on auto-scan.
**Phase:** 16 — Scan UX
**Scope in:** `scan_screen.dart`, `visit_repository.dart` only.
**Scope out:** Firestore, web, card editor, merch, packages, map screen.
**Status:** In progress (2026-04-24).

---

### M85 — Order Confirmation Screen (Pre-Checkout) ⚠️ HIGH PRIORITY

**Goal:** Insert a mandatory full-screen confirmation step between the Printful mockup and Shopify
checkout. The user must explicitly review their size, colour, print positions, and design, then tick
a checkbox before the "Proceed to Checkout" button enables. Prevents incorrect purchases, reduces
refunds, and sets clear no-refund expectations.

**Phase:** 16 — Commerce UX Polish

**Scope in:** New `merch_order_confirmation_screen.dart`; one-line change in
`local_mockup_preview_screen.dart` (replace direct `_completeCheckout()` call with
`Navigator.push` to the confirmation screen).

**Scope out:** Printful API; Firestore schema; Cloud Functions; card editor; scan; map; web.

---

#### UX Flow

```
[ready state — mockup visible]
        ↓  user taps "Review & Checkout →"
[MerchOrderConfirmationScreen — full screen, no AppBar back shortcut]
        ├─ Shows: front mockup (large), back mockup (if present), order summary card
        ├─ Warning box: custom-product / no-refund notice
        ├─ Checkbox: "I have reviewed all details and they are correct"
        ├─ [Go Back]              → Navigator.pop() → returns to ready state
        └─ [Proceed to Checkout]  → enabled only when checkbox ticked
                                  → calls _completeCheckout (launches checkoutUrl)
```

---

#### Flutter Screen Structure

**File:** `lib/features/merch/merch_order_confirmation_screen.dart`

```
MerchOrderConfirmationScreen (StatefulWidget)
  ├── Constructor params (all required, immutable — frozen snapshot at confirm time):
  │     frontMockupUrl: String?
  │     backMockupUrl:  String?
  │     artworkBytes:   Uint8List          ← final generated design image
  │     size:           String             ← e.g. 'L'
  │     colour:         String             ← e.g. 'Black'
  │     frontPosition:  String             ← 'center' | 'left_chest' | 'right_chest' | 'none'
  │     backPosition:   String             ← 'center' | 'none'
  │     templateType:   CardTemplateType   ← 'passport' | 'grid' | 'heart'
  │     checkoutUrl:    String
  │
  └── State:
        _confirmed: bool = false           ← drives checkbox + button enabled

Layout (SingleChildScrollView → Column):
  1. _MockupSection        — PageView of front/back mockup images (large, fills ~55% height)
  2. _OrderSummaryCard     — Colour chip + size badge + front/back position labels + template name
  3. _WarningBox           — amber-bordered container with warning copy
  4. _ConfirmationCheckbox — Row(Checkbox, Expanded(Text(...)))
  5. _ActionRow            — [Go Back (TextButton)] [Proceed to Checkout (FilledButton, disabled until _confirmed)]
```

---

#### State Management

- Entirely local `StatefulWidget` state — no Riverpod needed.
- `_confirmed` bool toggles on checkbox tap → `setState`.
- Checkout URL passed in at construction; never re-fetched or mutated.
- No back-navigation lock needed (user may freely go back; nothing destructive happens).

---

#### Validation Logic

```dart
// Checkbox
Checkbox(
  value: _confirmed,
  onChanged: (v) => setState(() => _confirmed = v ?? false),
)

// Proceed button
FilledButton(
  onPressed: _confirmed ? _launchCheckout : null,
  child: const Text('Proceed to Checkout'),
)

// Launch
Future<void> _launchCheckout() async {
  final uri = Uri.parse(widget.checkoutUrl);
  if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
    // show snackbar
  }
}
```

---

#### Production Copy

**Screen title:** `Review Your Order`

**Section header (mockup):** `Your Design`

**Section header (details):** `Order Details`

**Detail labels:**
- Colour: `{colour}` (with matching filled circle swatch)
- Size: `{size}`
- Front print: `{frontPositionLabel}` — where center→`Centre`, left_chest→`Left Chest`,
  right_chest→`Right Chest`, none→`No Front Print`
- Back print: `{backPositionLabel}` — center→`Centre`, none→`No Back Print`
- Design: `{templateLabel}` — passport→`Passport Stamps`, grid→`Flag Grid`, heart→`Heart Flags`

**Warning box:**
```
⚠  Custom-Made Product

Please review every detail above carefully before continuing.

This item is made to order — once payment is completed,
we cannot offer refunds or exchanges for change of mind.

You can still cancel during checkout.
```

**Checkbox label:**
```
I confirm the size, colour, design, and print positions shown above are correct.
```

**Go Back button:** `← Go Back`
**Proceed button:** `Proceed to Checkout →`

---

#### Trigger Change in LocalMockupPreviewScreen

In `_buildBottomBar()`, replace:
```dart
// BEFORE
onPressed: _completeCheckout,
child: const Text('Complete order →'),

// AFTER
onPressed: () => Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => MerchOrderConfirmationScreen(
    frontMockupUrl: _mockupUrl,
    backMockupUrl:  _backMockupUrl,
    artworkBytes:   _artworkBytes!,
    size:           _tshirtSize,
    colour:         _colour,
    frontPosition:  _frontPosition,
    backPosition:   _backPosition,
    templateType:   _template,
    checkoutUrl:    _checkoutUrl!,
  ),
)),
child: const Text('Review & Checkout →'),
```

---

#### Edge Cases

| Case | Handling |
|---|---|
| `frontMockupUrl` is null (still generating) | Show `artworkBytes` rendered locally with a "Preview" label; do not block confirmation |
| Both mockup URLs null | Show local artwork preview for both sides |
| `checkoutUrl` is somehow null | Button disabled with label "Checkout unavailable — go back" |
| User taps back during checkout browser | Returns to ready state; confirmation screen is gone (popped on checkout launch) |
| Design changed after confirmation (impossible) | State is frozen at push time — no references to parent mutable state |

---

#### ADR

ADR-131: Mandatory pre-checkout confirmation screen (`MerchOrderConfirmationScreen`) inserted
between `_MockupState.ready` and Shopify checkout launch. All order data passed as immutable
constructor params at push time. No Firestore or API calls in the confirmation screen.
Checkbox gates the proceed button. "Go Back" returns to `ready` state with mockup intact.

---

**Dependencies:** None — sits on top of existing `ready` state output.
**Status:** ✅ Complete (2026-04-27).

---

### M75 — Inline T-Shirt Config UX (Remove "More" Tab)
**Goal:** Remove the "More" bottom sheet; bring all product configuration inline on the main
Design Your T-Shirt screen. No hidden navigation, no duplicate controls, premium Apple-quality UX.
**Phase:** 16 — Commerce UX Polish
**Scope in:** `local_mockup_preview_screen.dart` only — layout refactor + widget removal/addition.
**Scope out:** Printful API; card templates; card editor; web; scan; map.
**Status:** ✅ Complete (2026-04-22).

---

### M61 — Grid Card Upgrade
**Goal:** Replace emoji flags with real SVG flag images; adaptive tile sizing; portrait/landscape re-layout; shared editable title state across Grid/Passport/Heart.
**Phase:** 15 — Visual Design Upgrade
**Scope out:** Web card generator changes
**Status:** Not started. No tasks written.

---

### M66 — Heart Card Redesign (Flag-Based Layout)
**Goal:** Transparent heart filled with real flag SVGs; gapless edge-to-edge binary-search packing; 80% edge-flag visibility rule; no emoji fallback; print-ready transparent background.
**Phase:** 15 — Visual Design Upgrade
**Scope out:** Web card generator changes
**Status:** Not started. No tasks written.

---

---

### M79 — Personalised Packing Slip
**Goal:** Add Roavvy branding to every Printful packing slip: logo sticker, custom message, support email, store name override, and a Roavvy-friendly order reference instead of Printful's numeric ID.
**Phase:** 17 — Commerce Polish
**API:** `packing_slip` object on `POST /orders` (Printful v1). Fields: `logo_url`, `message`, `email`, `store_name`, `custom_order_id`.
**Scope in:** `shopifyOrderCreated` in `apps/functions/src/index.ts` only.
**Scope out:** Shopify checkout flow; mobile UI; web.
**Status:** Not started. No tasks written.

---

### M80 — Shipment Tracking In-App
**Goal:** When Printful ships an order, write the tracking URL + carrier to the user's `MerchConfig` in Firestore and send a push notification with a deep-link to the carrier tracking page.
**Phase:** 17 — Commerce Polish
**API:** `package_shipped` Printful webhook event (carrier, service, tracking_number, tracking_url).
**Scope in:** New `printfulWebhook` Cloud Function; Firestore `MerchConfig` (add `trackingUrl`, `trackingCarrier`); push notification trigger; mobile order status UI.
**Scope out:** Custom tracking UI; web order history.
**Status:** Not started. No tasks written.

---

### M81 — Gift Message at Checkout
**Goal:** Add a "This is a gift" toggle + message field to the merch checkout flow. Message is forwarded to Printful's `gift` object (subject + message, max 200 chars each) and printed on the packing slip.
**Phase:** 17 — Commerce Polish
**API:** `gift.subject` + `gift.message` on `POST /orders` (Printful v1).
**Scope in:** `local_mockup_preview_screen.dart` (gift toggle + field); `createMerchCart` request type; `shopifyOrderCreated` (pass gift to Printful).
**Scope out:** Shopify-level gift wrapping; web checkout.
**Status:** Not started. No tasks written.

---

### M82 — Order Failed Recovery
**Goal:** Handle the `order_failed` Printful webhook: update `designStatus=order_failed` in Firestore and send the user a push notification prompting them to contact support.
**Phase:** 17 — Commerce Polish
**API:** `order_failed` Printful webhook event.
**Scope in:** `printfulWebhook` Cloud Function (shared with M80); Firestore status update; push notification.
**Scope out:** Self-serve file resubmission; web.
**Status:** Not started. Depends on M80 (shared webhook handler).

---

### M83 — Shipping Speed Selection
**Goal:** Show 2–3 shipping options (Standard / Express / Priority) with live rates and estimated delivery dates at checkout. User pays the difference; selected method is forwarded to the Printful order.
**Phase:** 18 — Commerce Conversion
**API:** `POST /shipping/rates` (country_code + items); `shipping` field on `POST /orders`.
**Scope in:** `createMerchCart` (rate lookup, pass selected method); checkout UI shipping picker; `CreateMerchCartRequest` type.
**Scope out:** Shopify shipping settings; web checkout.
**Status:** Not started. No tasks written.

---

### M84 — Order Cost Preview
**Goal:** Show a live cost breakdown (item + print + shipping + tax) in the merch screen before the user taps "Checkout", using Printful's estimate endpoint.
**Phase:** 18 — Commerce Conversion
**API:** `POST /orders/estimate-costs` (Printful v1).
**Scope in:** New `estimateMerchCost` callable Cloud Function; cost breakdown widget in `local_mockup_preview_screen.dart`.
**Scope out:** Shopify price; web checkout.
**Status:** Not started. No tasks written.

---

### M28 — Web Commerce: Authenticated Checkout *(web — lower priority)*
**Goal:** Signed-in web user selects visited countries → `createMerchCart` → Shopify checkout.
**Depends on:** M27 ✅
**Scope in:** `/shop` country select grid; cart creation; redirect to `checkoutUrl`; post-checkout confirmation; error state
**Scope out:** Variant picker on web; mockup generation on web; order history on web
**Status:** Not started. No tasks written.

---

### M31 — Web Auth: Password Reset *(web — lower priority)*
**Goal:** `/forgot-password` route with `sendPasswordResetEmail`; "Forgot password?" link on `/sign-in`.
**Scope out:** Custom email template; mobile password reset
**Status:** Not started. No tasks written.
