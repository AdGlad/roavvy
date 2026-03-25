# M38 — Print from Card

**Milestone:** 38
**Phase:** Phase 13a — Identity Commerce
**Status:** Not started

**Goal:** The disabled "Print your card" button in `CardGeneratorScreen` becomes active. Tapping it saves the `TravelCard` to Firestore and navigates the user directly to product selection (`MerchProductBrowserScreen`), bypassing `MerchCountrySelectionScreen`. The `cardId` is threaded through to `createMerchCart` and stored on `MerchConfig` so the order is traceable back to the originating card.

---

## Scope

**Included:**
- Enable "Print your card" CTA in `CardGeneratorScreen` — save card + navigate to `MerchProductBrowserScreen(selectedCodes, cardId)`
- Add optional `cardId` param to `MerchProductBrowserScreen` and `MerchVariantScreen`; pass through to `createMerchCart` callable payload
- Add optional `cardId?: string` to `CreateMerchCartRequest` and `MerchConfig` TypeScript types
- Update `createMerchCart` Firebase Function to store `cardId` on `MerchConfig` when provided
- Deploy updated Firebase Function

**Excluded:**
- Country picker within the card print flow (always uses all card's country codes in M38)
- Changing the existing `MerchCountrySelectionScreen` → `MerchProductBrowserScreen` → `MerchVariantScreen` path (it continues to work as before)
- `previewImageUrl` on `TravelCard` (deferred; no Firebase Storage upload in M38)
- Web print-from-card flow

---

## Tasks

### Task 134 — Add `cardId` to `CreateMerchCartRequest`, `MerchConfig`, and `createMerchCart` function

**Deliverable:**
- `apps/functions/src/types.ts`:
  - `MerchConfig`: add `cardId?: string` field (optional; null for carts not originating from a card)
  - `CreateMerchCartRequest`: add `cardId?: string` field
- `apps/functions/src/index.ts`:
  - Read `cardId` from `request.data` (optional)
  - Include `cardId: cardId ?? null` in the initial `MerchConfig` write (Step 1)
- Deploy: `firebase deploy --only functions`

**Acceptance criteria:**
- [ ] `CreateMerchCartRequest` type includes `cardId?: string`
- [ ] `MerchConfig` type includes `cardId?: string`
- [ ] `createMerchCart` stores `cardId` (or null) on the created `MerchConfig` document
- [ ] TypeScript compiles with zero errors (`npm run build` in `apps/functions`)
- [ ] Firebase Function deploys successfully

**Notes:**
- `cardId` is optional — carts created from the existing `MerchCountrySelectionScreen` flow do not supply it; the Function must handle `undefined`
- No validation needed: if `cardId` is undefined, store `null`

---

### Task 135 — Thread `cardId` through `MerchProductBrowserScreen` and `MerchVariantScreen`

**Deliverable:**
- `apps/mobile_flutter/lib/features/merch/merch_product_browser_screen.dart`:
  - Add `cardId: String?` optional constructor param (default `null`)
  - Pass `cardId` to each `MerchVariantScreen(...)` push
- `apps/mobile_flutter/lib/features/merch/merch_variant_screen.dart`:
  - Add `cardId: String?` optional constructor param (default `null`)
  - In `_callCreateMerchCart()`, include `'cardId': widget.cardId` in the callable payload if non-null

**Acceptance criteria:**
- [ ] `MerchProductBrowserScreen` accepts optional `cardId: String?`
- [ ] `MerchVariantScreen` accepts optional `cardId: String?`
- [ ] `createMerchCart` callable payload includes `'cardId': widget.cardId` when non-null
- [ ] Existing `MerchCountrySelectionScreen` → `MerchProductBrowserScreen` navigation still compiles (no required params added)
- [ ] `flutter analyze` zero issues

---

### Task 136 — Enable "Print your card" CTA in `CardGeneratorScreen`

**Deliverable:**
- `apps/mobile_flutter/lib/features/cards/card_generator_screen.dart`:
  - Replace the disabled `OutlinedButton` "Print your card" stub with an active button
  - On tap: create a `TravelCard`, write fire-and-forget to Firestore (same `uid` guard as share), then navigate to `MerchProductBrowserScreen(selectedCodes: codes, cardId: card.cardId)`
  - Button is disabled while `_sharing` is true (same guard as Share button)
  - Commerce copy: keep "Print your card" (matches Phase 13 copy rules)

**Acceptance criteria:**
- [ ] "Print your card" button is tappable and navigates to `MerchProductBrowserScreen`
- [ ] `MerchProductBrowserScreen` receives the card's `countryCodes` as `selectedCodes`
- [ ] `cardId` is passed through to `MerchProductBrowserScreen`
- [ ] Fire-and-forget `TravelCard` save occurs before navigation (same pattern as share)
- [ ] Button disabled during `_sharing` in-progress (no concurrent share + print actions)
- [ ] `Tooltip("Coming soon")` removed
- [ ] `flutter analyze` zero issues

---

## Dependencies

```
Task 134 (Function types + deploy)
    └─ Task 135 (mobile: accept cardId param)
        └─ Task 136 (enable Print CTA — uses MerchProductBrowserScreen with cardId)
```

Tasks 134 and 135 can be built in parallel (Function and mobile are independent codebases), but Task 136 depends on both.

---

## Risks / Open Questions

| Risk | Mitigation |
|---|---|
| Firebase Function deploy fails (e.g. billing) | Confirm `roavvy-prod` is on Blaze plan; deploy is already known-working from M34 |
| `cardId` optional field breaks existing MerchConfig reads | Field is optional on the TypeScript interface; Firestore reads of existing docs without the field return `undefined` — handled by `?? null` |
| `MerchProductBrowserScreen` skipping country selection feels abrupt | Acceptable for M38 — user sees their countries reflected in the flag grid preview on `MerchVariantScreen` |
| `_callCreateMerchCart` method name — verify it exists | Read file before editing in Task 135 |
