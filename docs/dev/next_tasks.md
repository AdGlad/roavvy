# M40 — Scan & Map Commerce Triggers

**Goal:** After discovering new countries, users are nudged to create a travel card. The map menu copy aligns with Phase 13b strategy ("Create a poster" not "Get a poster").

---

## Scope

**Included:**
- "Create a travel card →" `TextButton` in `ScanSummaryScreen` State A — shown in `_NewDiscoveriesState` between existing content and "Get a poster" button; navigates to `CardGeneratorScreen`
- Map menu "Get a poster" renamed → "Create a poster" (Phase 13b copy alignment; navigation unchanged → `MerchCountrySelectionScreen`)

**Excluded:**
- Replacing the "Get a poster" navigation with a card-first flow — deferred to M41 (Shop De-emphasis)
- Changes to State B (nothing new) — no nudge on caught-up scan
- Web changes
- Any new Firestore, Firebase Function, or SharedPreferences state

---

## Tasks

### Task 140 — "Create a travel card" nudge in ScanSummaryScreen State A

**Deliverable:**
- In `_NewDiscoveriesStateState.build()` (inside `_NewDiscoveriesState`), add a `TextButton` "Create a travel card →" above the existing "Get a poster" TextButton
- On tap: `Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardGeneratorScreen()))`
- Follows the same layout pattern as the existing "Get a poster" button (same padding `fromLTRB(16, 0, 16, 0)`)

**Acceptance criteria:**
- "Create a travel card →" button visible in State A (new countries found)
- Tapping it navigates to `CardGeneratorScreen`
- "Get a poster with your new discoveries →" button still present below it
- "Explore your map" primary button still present and functional
- Widget test: button renders in State A; tapping it pushes `CardGeneratorScreen`
- `flutter analyze` zero issues

---

### Task 141 — Rename "Get a poster" → "Create a poster" in MapScreen menu

**Deliverable:**
- In `map_screen.dart`, change the `PopupMenuItem` title text: `'Get a poster'` → `'Create a poster'`
- No navigation change — still pushes `MerchCountrySelectionScreen()`
- No enum rename needed (`_MapMenuAction.shop` stays as-is)

**Acceptance criteria:**
- Map overflow menu shows "Create a poster" (not "Get a poster")
- Tapping "Create a poster" navigates to `MerchCountrySelectionScreen`
- Existing map menu tests (if any) updated to match new label
- `flutter analyze` zero issues

---

## Dependencies

- Task 140 and 141 are independent; implement in order.

## Risks

- **Two card CTAs in the map menu**: After M40, the map menu has both "Create card" (→ `CardGeneratorScreen`) and "Create a poster" (→ `MerchCountrySelectionScreen`). This is intentional for M40; M41 will consolidate/restructure.
- **Two card CTAs in scan State A**: After M40, State A has "Create a travel card →" (above) and "Get a poster with your new discoveries →" (below). Both are low-visual-weight `TextButton`s — the primary CTA remains "Explore your map". This duplication is acceptable for M40; M41 will clean up.
