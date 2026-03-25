# M28 — Web Commerce: Authenticated Checkout

**Milestone:** 28
**Phase:** 12 — Commerce & Mobile Completion
**Goal:** A signed-in web user can select their visited countries, call `createMerchCart`, and complete a Shopify checkout.
**Branch:** `milestone/m28-web-commerce-checkout`

---

## Context

M27 delivered the public `/shop` landing page. The shop page already:
- Shows a country count and a "Create my poster →" link to `/shop/design` for signed-in users with visits
- Shows a "Sign in to personalise your design" CTA for unauthenticated users
- Has a post-order confirmation state (`?ordered=true` banner)

The `/shop/design` route does not yet exist. This milestone builds it.

Firebase Functions has `createMerchCart` deployed; it accepts `{ variantId, selectedCountryCodes, quantity }` and returns `{ checkoutUrl, cartId, merchConfigId, previewUrl }`.

The poster-only variantId for the default product (Enhanced Matte 18×24in) is:
`gid://shopify/ProductVariant/47577104351419`

---

## Scope

**Included:**
- `/shop/design` authenticated route: country selection → call `createMerchCart` → redirect to `checkoutUrl`
- Country selection: checkbox grid of visited countries (all pre-selected); shows flag emoji + country name
- "Create my poster" primary CTA button calls `createMerchCart` with the poster default variantId and selected codes
- Loading state while function executes (button disabled + spinner)
- Error state: function failure → inline error message + retry
- Redirect: on success, `window.location.href = checkoutUrl`
- Auth guard: unauthenticated users redirected to `/sign-in?next=/shop/design`

**Excluded (as per M28 spec):**
- Variant picker (colour, size) on web — poster only (default 18×24in Enhanced Matte)
- Mockup image generation display on web (previewUrl returned by function but not shown)
- Order history on web
- T-shirt selection on web

---

## Tasks

### Task 115 — `/shop/design` authenticated country-selection page

**Deliverable:**
- `apps/web_nextjs/src/app/shop/design/page.tsx` — new Next.js route
- Auth guard: if not signed in, redirect to `/sign-in?next=/shop/design`
- Loads visited countries via `useUserVisits` hook (already exists)
- Renders a checkbox grid: country flag emoji + ISO code + name; all pre-selected on mount
- "Select all" / "Deselect all" controls
- "Create my poster" button: disabled when 0 countries selected or while loading
- On button click: calls `createMerchCart` Firebase callable with `{ variantId: POSTER_VARIANT_ID, selectedCountryCodes, quantity: 1 }`
- On success: redirect to `checkoutUrl` via `window.location.href`
- On error: show inline error message "Something went wrong. Please try again." with a retry option
- Loading state: button shows spinner + "Creating your poster…" text; grid is non-interactive

**Acceptance criteria:**
- Signed-in user with ≥1 country can reach `/shop/design`, sees their countries pre-checked, and can call the function
- Unauthenticated user visiting `/shop/design` is redirected to `/sign-in?next=/shop/design`
- User with 0 visited countries sees an empty-state message ("No countries found — scan the app first") and the button is disabled
- Error path: if the callable throws, an inline error is shown without navigating away
- `next build` passes with no TypeScript errors
- Unit test: `apps/web_nextjs/src/app/shop/design/__tests__/page.test.tsx`

### Task 116 — Country name lookup helper for web

**Deliverable:**
- `apps/web_nextjs/src/lib/countryNames.ts` — static map of ISO 3166-1 alpha-2 → display name; exported as `COUNTRY_NAMES: Record<string, string>` and `countryName(code: string): string` helper (falls back to code)
- Used by Task 115 design page to label each checkbox
- Unit test: `apps/web_nextjs/src/lib/__tests__/countryNames.test.ts`

**Acceptance criteria:**
- Contains entries for at minimum: US, GB, FR, DE, JP, AU, BR, CA, IN, ZA, NG, CN, MX, IT, ES, NL, RU, TR, SA, AR
- Fallback to code string for unknown codes
- No network calls — pure static data

---

## Dependencies

- Task 116 must complete before Task 115 (country name helper used in design page)
- M27 `/shop` page is complete — "Create my poster →" link to `/shop/design` already exists
- `createMerchCart` Firebase callable is deployed (M20)
- `useUserVisits` hook exists at `apps/web_nextjs/src/lib/firebase/useUserVisits.ts`
- Firebase Functions SDK already initialised in `apps/web_nextjs/src/lib/firebase/init.ts`

---

## Risks

1. **`httpsCallable` region** — Firebase Functions may be deployed to a non-default region. The builder must check the functions deployment region and pass it to `getFunctions` if needed.
2. **CORS / callable protocol** — `httpsCallable` from the Firebase JS SDK handles auth automatically. No manual CORS headers needed.
