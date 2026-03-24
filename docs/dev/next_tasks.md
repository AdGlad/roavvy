# M37 — Travel Card Generator

**Milestone:** 37
**Phase:** Phase 13 — Identity Commerce
**Status:** Not started

**Goal:** A user can open a card generator screen, pick a template (Grid · Heart · Passport), preview a travel card built from their visited countries, share it, and have the card saved to Firestore as a `TravelCard` entity ready for a future print flow.

---

## Scope

**Included:**
- `TravelCard` Dart domain model in `shared_models` (templateType, countryCodes, countryCount, createdAt)
- Firestore `travel_cards/{cardId}` collection + security rules
- `CardGeneratorScreen` — template selector + live preview + Share CTA
- 3 preview template widgets: Grid Flags · Heart Flags · Passport Stamps
- Save `TravelCard` to Firestore on share (or on explicit "Save" action)
- 2 entry points: Stats screen "Create card" action + Map "⋮" menu "Create card"

**Excluded:**
- "Print" CTA from card (M38)
- `previewImageUrl` upload to Firebase Storage (card is previewed on-device; URL storage deferred to M38 when needed for print)
- Cards tab / nav restructure (M41+)
- Country picker within the generator (always uses all visited countries in M37; selection in M38)
- Web card generator

---

## Tasks

### Task 130 — `TravelCard` domain model + Firestore schema

**Deliverable:**
- `packages/shared_models/lib/src/travel_card.dart` — `TravelCard` class + `CardTemplateType` enum
- `TravelCard` exported from `shared_models` barrel
- Firestore document shape documented in `TravelCard`'s doc comment
- `TravelCardService` (`lib/features/cards/travel_card_service.dart`) — `create(TravelCard)` writes to `users/{uid}/travel_cards/{cardId}` (subcollection under user, not top-level collection, matching existing data model)
- Firestore security rule: `allow read, write: if request.auth.uid == userId` on `users/{uid}/travel_cards/{cardId}`

**Acceptance criteria:**
- [ ] `TravelCard` compiles in `shared_models`; exported from barrel
- [ ] `TravelCardService.create()` writes to Firestore without error (tested manually; unit test of create is covered by existing Firestore mock pattern)
- [ ] `flutter analyze` zero issues

**Notes:**
- Use `users/{uid}/travel_cards/{cardId}` (subcollection) not `travel_cards/{cardId}` (top-level) — consistent with `users/{uid}/inferred_visits` etc. (ADR-029)
- `cardId`: UUID generated client-side (`package:uuid` already in pubspec)
- No `previewImageUrl` field in M37 — add in M38 when Firebase Storage upload is needed
- `CardTemplateType` enum values: `grid`, `heart`, `passport`

---

### Task 131 — 3 template preview widgets

**Deliverable:** `lib/features/cards/card_templates.dart` — three `StatelessWidget`s:

1. **`GridFlagsCard`** — Dark navy background; flag emojis for each visited country in a flowing `Wrap`; country count + "countries" label at bottom. Reuses the app's dark navy (`Color(0xFF0D2137)`) and amber accent.

2. **`HeartFlagsCard`** — Same flag emojis as Grid but tinted background with a warm amber/rose gradient; emojis arranged in the same `Wrap` layout but with a heart-shaped container mask overlay (simple `ClipPath` with a heart `Path`). If the heart mask proves too complex, ship as a rounded card with a heart emoji watermark — document the simplification.

3. **`PassportStampsCard`** — Dark leather-brown background (`Color(0xFF3E2010)`); each country rendered as a `_StampWidget` (rounded rectangle with country flag + ISO code + name, slightly rotated 0–5° per stamp deterministically from the country code). Up to 12 stamps visible; overflow shows "+N more".

All three accept `List<String> countryCodes` as a constructor parameter. All are `AspectRatio(aspectRatio: 3/2)` matching the existing `TravelCardWidget`.

**Acceptance criteria:**
- [ ] All three widgets render without overflow or error for 1–50+ country codes
- [ ] `flutter analyze` zero issues
- [ ] Widget tests for each: renders with 0 countries, renders with 5 countries, no overflow with 50+ countries

---

### Task 132 — `CardGeneratorScreen`

**Deliverable:** `lib/features/cards/card_generator_screen.dart`

Full-screen `ConsumerWidget`. Layout:

1. **Template picker row** — 3 tappable tiles (Grid · Heart · Passport) at top; selected tile has amber border; tapping switches the live preview below.

2. **Live preview area** — `RepaintBoundary` wrapping the selected template widget (same `GlobalKey` approach as existing `travel_card_share.dart`). Updates immediately when template changes.

3. **Action bar** (bottom):
   - "Share" button — captures preview to PNG using existing `captureCard()` helper pattern from `travel_card_share.dart`; calls `TravelCardService.create()` to persist the card; then opens system share sheet via `share_plus`.
   - Future "Print" button stub — `OutlinedButton` labelled "Print your card" shown disabled with tooltip "Coming soon" (wires up in M38).

Country codes come from `effectiveVisitsProvider` (all visited countries, sorted alphabetically by ISO code).

**Acceptance criteria:**
- [ ] Template switching updates the preview with no flicker
- [ ] "Share" button captures the visible preview and opens the share sheet
- [ ] `TravelCardService.create()` is called before sharing (card persisted)
- [ ] Empty state: if 0 countries visited, show "Scan your photos to generate a card" message instead of preview
- [ ] `flutter analyze` zero issues

---

### Task 133 — Entry points

**Deliverable:** Two entry points to `CardGeneratorScreen`:

1. **Stats screen** — Add a "Create card" `TextButton` or `OutlinedButton` below the stats panel (above the continent breakdown tiles), visible when `countryCount > 0`. Pushes `CardGeneratorScreen` via `Navigator.push(MaterialPageRoute(...))`.

2. **Map "⋮" menu** — Add "Create card" `PopupMenuItem` between "Share travel card" and "Get a poster"; visible when `hasVisits`. Pushes `CardGeneratorScreen`.

**Acceptance criteria:**
- [ ] "Create card" entry point appears in Stats screen when visits > 0
- [ ] "Create card" entry point appears in Map menu when visits > 0
- [ ] Both navigate to `CardGeneratorScreen` and return correctly on back
- [ ] `flutter analyze` zero issues

---

## Dependencies

```
Task 130 (TravelCard model + service)
    └─ Task 131 (template widgets — no model dependency, but logically first)
        └─ Task 132 (CardGeneratorScreen — uses all three)
            └─ Task 133 (entry points — needs screen to exist)
```

Tasks 130 and 131 are independent and can be built in parallel within a session.

---

## Risks / Open Questions

| Risk | Mitigation |
|---|---|
| Heart `ClipPath` mask complex on small screen | Ship rounded card + heart emoji watermark if mask takes > 30 min; document simplification |
| `uuid` package: confirm already in pubspec | Check before Task 130; add if missing |
| `TravelCardService` calls Firestore — needs user to be signed in | Guard with `authStateProvider` check; show snack if auth fails; anonymous users can generate but not persist (acceptable) |
| Stamp rotation in PassportStampsCard may cause `Overflow` | Use `OverflowBox` or `ClipRect` around each stamp |
