# Backlog — Active Milestones

> Upcoming work only. Completed milestones live in `docs/dev/backlog.md`.
> Mobile milestones take priority over web (see memory: feedback_mobile_first).

---

## Next up (mobile-first order)

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
