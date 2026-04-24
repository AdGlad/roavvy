# Backlog — Active Milestones

> Upcoming work only. Completed milestones live in `docs/dev/backlog.md`.
> Mobile milestones take priority over web (see memory: feedback_mobile_first).

---

## Next up (mobile-first order)

### M77 — Incremental Scan Redesign ← CURRENT
**Goal:** Globe pre-populated with known countries, country list shows existing visits from scan start, assetId-based dedup for robustness, instant visual feedback on auto-scan.
**Phase:** 16 — Scan UX
**Scope in:** `scan_screen.dart`, `visit_repository.dart` only.
**Scope out:** Firestore, web, card editor, merch, packages, map screen.
**Status:** In progress (2026-04-24).

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
