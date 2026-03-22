# Roavvy Commerce — UX Specification

**Scope:** Phase 10 — personalised merchandise purchase on mobile (iOS Flutter) and web (Next.js)
**Principle:** The user's travel history is already known. The experience is not "configure a product" — it is "turn your map into something real." Every step should feel like revealing something the user has already earned.

---

## Product Vision Alignment

The vision states: *"A user buys a personalised travel poster because the map is worth putting on the wall."*

This spec expands that to wearables — specifically t-shirts — alongside posters. The principle is the same: Roavvy knows exactly which countries the user has visited; the merchandise reflects that. The user's only job is to choose a design and confirm their order.

Print-on-demand via a Shopify-connected fulfiller (Printful or Printify) handles production and shipping. Roavvy never holds stock.

---

## Entry Points

### Mobile (iOS app)

| Location | Entry point | Context |
|---|---|---|
| Stats screen | "Shop" button in the header area | User is looking at their stats — most likely to feel proud |
| Travel card share flow | "Turn this into a t-shirt" CTA after generating a share card | High-emotion moment post-share |
| Scan summary screen | "Shop your new countries" chip after unlocking a milestone | Celebration moment |
| Stats screen achievement gallery | "Get it on a t-shirt" link below the achievement count | Aspirational |

The primary entry point is the **Stats screen**. It is the screen that shows the user's travel identity in one place (47 countries · 6 continents · 112 trips).

### Web (Next.js)

| Location | Entry point |
|---|---|
| `/map` page | "Shop" link in the nav bar |
| `/share/[token]` page | "Turn this into a t-shirt" CTA below the share card |
| `/shop` (direct) | Public landing page, no sign-in required; prompts sign-in to personalise |

---

## Flow Overview

```
Entry point
    │
    ▼
[1] Country Selection
    └─ Default: all visited countries selected
    └─ Can deselect individual countries
    │
    ▼
[2] Product Browser
    └─ Browse product types: T-Shirt · Poster · (more later)
    └─ Each product shows a live mockup using the user's selection
    │
    ▼
[3] Design Studio (per product)
    └─ Choose design style (Map, Flags, Passport Stamps, …)
    └─ Choose placement (Front / Back / Both)
    └─ Choose colour and size
    └─ Live mockup updates in real time
    │
    ▼
[4] Add to Cart
    └─ Summary card: product, design, size, price
    │
    ▼
[5] Shopify Checkout
    └─ Redirect to Shopify-hosted checkout (standard experience)
    └─ Return to app / web after completion
```

---

## Screen-by-Screen Specification

---

### Screen 1 — Country Selection

**Purpose:** Let the user choose which countries appear on their merchandise. Default is all visited countries — most users will tap straight through.

**Header:**
> "Your countries ([N] selected)"

**Body:**
- Scrollable list of the user's visited countries, sorted alphabetically by name
- Each row: flag emoji · country name · checkbox (checked by default)
- "Select all" / "Deselect all" toggle at the top
- Search field to filter by country name (useful for users with 50+ countries)
- Countries the user manually added are included; countries the user removed are excluded (respects the source of truth)

**Empty state (no countries visited):**
> "Scan your photos first to detect your visited countries — then come back here to put them on a t-shirt."
> [Scan Photos button]

**Footer CTA:**
> "Choose a design →" (disabled if 0 countries selected)

**Design notes:**
- This screen is optimistic — the user rarely needs to change anything. Keep it lightweight. Don't make it feel like a form.
- Selected count updates live as the user toggles.
- Minimum selection is 1. Show an inline error if the user deselects everything.

---

### Screen 2 — Product Browser

**Purpose:** Present the range of products. Each product card shows a real mockup using the user's selected countries.

**Layout:**
- Vertical scroll of product cards
- Each card:
  - Full-width mockup image (pre-rendered by the design system; see Technical Notes)
  - Product name + tagline
  - Starting price ("From £29")
  - "Customise →" button

**Initial product range (Phase 10):**

| Product | Tagline |
|---|---|
| Classic T-Shirt | Wear your world |
| Travel Poster | Frame the journey |

**Future products (not in Phase 10):** hoodie, mug, phone case, tote bag.

**Design notes:**
- Product order: T-shirt first (highest emotional appeal), poster second.
- Mockups on this screen use the user's first selected design style (Map by default) as a preview. Full customisation happens in Screen 3.
- The page header shows the currently selected country count: "Designing for 23 countries".

---

### Screen 3 — Design Studio (T-Shirt)

**Purpose:** Let the user personalise the design before adding to cart.

#### Layout

```
┌──────────────────────────────────────┐
│  ← Back          T-Shirt            │
├──────────────────────────────────────┤
│                                      │
│         [Live T-Shirt Mockup]        │
│                                      │
│         [Front]   [Back]             │  ← toggle
│                                      │
├──────────────────────────────────────┤
│  Design                              │
│  ┌────────┐ ┌────────┐ ┌────────┐   │
│  │  Map   │ │ Flags  │ │Stamps  │   │  ← segmented tabs
│  └────────┘ └────────┘ └────────┘   │
├──────────────────────────────────────┤
│  Placement                           │
│  ○ Front only   ○ Back only          │
│  ○ Front + Back (large map on back)  │
├──────────────────────────────────────┤
│  Shirt colour                        │
│  ⬛ ⬜ 🟤 🔵 🟢  (colour swatches)   │
├──────────────────────────────────────┤
│  Size    [XS] [S] [M] [L] [XL] [2X] │
├──────────────────────────────────────┤
│  £34.00          [Add to Cart →]     │
└──────────────────────────────────────┘
```

#### Design Styles

| Style | Description |
|---|---|
| **World Map** | Outline world map with the user's countries filled in (the Roavvy map aesthetic). Country names labelled for visited countries. |
| **Flags** | Grid of flag emoji / high-res flag icons for each visited country, arranged by continent row. Country name below each flag. |
| **Passport Stamps** | Illustrated stamp-style graphic per country — circular or rectangular, with country name and a silhouette. Arranged in an organic collage layout. |

Each style has a distinct visual identity. The mockup updates immediately when the user switches style.

#### Placement Options

| Option | Front | Back |
|---|---|---|
| Front only | Full design | Plain shirt |
| Back only | Small Roavvy logo | Full design |
| Front + Back | Small design (e.g. flag grid) | Large world map |

#### Shirt Colour Options (Phase 10)

White, Black, Navy, Forest Green, Stone Grey. (Limited to colours supported by the fulfilment partner for the chosen product SKU.)

#### Mockup Behaviour

- Mockup image updates when any of these change: design style, placement, shirt colour
- Front/Back toggle shows the other side of the shirt
- Mockup image is generated/fetched from the fulfilment partner's mockup API (e.g. Printful Mockup Generator API) with the user's country list encoded as a line item property
- While the mockup is loading, a skeleton shimmer replaces it (never shows a blank space)

#### Size Guide

A "Size guide" link opens a modal sheet with a simple measurement table. This is standard Shopify content, not built by Roavvy.

---

### Screen 3b — Design Studio (Poster)

Same structure as the T-Shirt screen. Differences:

- No "Placement" selector (posters are single-sided)
- Colour option is paper stock: White Matte · White Gloss · Recycled Cream
- Size options: A3 · A2 · A1 · 18×24" · 24×36"
- Design styles: World Map · Flags Grid (no Passport Stamps on poster)
- Price varies by size

---

### Screen 4 — Add to Cart / Cart Review

**Purpose:** Confirm the selection before handing off to Shopify.

**Layout:**

```
┌──────────────────────────────────────┐
│  ← Back             Cart (1 item)   │
├──────────────────────────────────────┤
│  [Mockup thumbnail]                  │
│  Classic T-Shirt                     │
│  World Map · Front only · Black · L  │
│  23 countries                        │
│  £34.00                        [✎]  │
├──────────────────────────────────────┤
│  + Add another product               │
├──────────────────────────────────────┤
│  Subtotal          £34.00            │
│  Shipping          Calculated at     │
│                    checkout          │
├──────────────────────────────────────┤
│       [Proceed to Checkout →]        │
└──────────────────────────────────────┘
```

- Edit button (✎) returns to Design Studio with current selections intact
- "Add another product" returns to the Product Browser
- Cart is local state within the session; not persisted between app launches (Shopify handles the cart natively at checkout)

---

### Screen 5 — Shopify Checkout

**Mobile:** Opens Shopify's mobile checkout in an in-app `SFSafariViewController` (iOS) or `WebView`. Do not build a native checkout — use Shopify's hosted checkout for PCI compliance and cart abandonment recovery.

**Web:** Redirect to Shopify checkout URL in the same tab. Shopify returns the user to a confirmation page on completion.

**Data passed to Shopify as line item custom properties:**

```json
{
  "visitedCodes": ["GB", "FR", "JP", "US", "..."],
  "designStyle": "world_map",
  "placement": "front_only",
  "shirtColour": "black"
}
```

The fulfilment integration (Printful/Printify → Shopify) reads `visitedCodes` and `designStyle` to generate the print-ready file.

---

### Post-Purchase

**Mobile:** After the SFSafariViewController dismisses (user taps Done or Shopify returns), show a native confirmation screen:

```
┌──────────────────────────────────────┐
│                                      │
│              🎉                      │
│   Order placed!                      │
│   You'll receive a confirmation      │
│   email shortly.                     │
│                                      │
│   Your t-shirt is being made with    │
│   your [23] countries.               │
│                                      │
│   [Back to my map]                   │
│   [Share my order]  ← optional       │
└──────────────────────────────────────┘
```

"Share my order" pre-populates the iOS share sheet with a message like: *"Just ordered a t-shirt with all 23 countries I've visited — made with Roavvy 🌍"*

**Web:** Shopify's standard order confirmation page. No custom web post-purchase screen needed in Phase 10.

---

## Web Experience

The web flow mirrors the mobile flow within `/shop`. Key differences:

| Aspect | Mobile | Web |
|---|---|---|
| Entry | Stats screen / share flow | Nav bar / `/share/[token]` CTA / direct URL |
| Authentication | Already signed in | Must sign in (Firebase) to load visited countries |
| Country loading | From local Drift DB | From Firestore (`users/{uid}/inferred_visits` + `user_added` − `user_removed`) |
| Design Studio | Flutter Canvas-based preview | Browser Canvas / SVG-based preview |
| Checkout | `SFSafariViewController` | Same-tab redirect to Shopify |
| Unauthenticated | Not applicable | Show `/shop` landing with sample mockups; prompt sign-in to personalise |

### `/shop` Public Landing Page

Unauthenticated visitors see:

- Hero: "Wear your world. Every country you've visited, on one t-shirt."
- Sample mockup (generic — 20 example countries)
- Product cards (T-Shirt · Poster) with example pricing
- CTA: "Sign in to personalise with your countries →"

After sign-in, Firestore loads their visited countries and the flow continues from Screen 1.

---

## Design Principles for This Flow

**1. Zero-friction personalisation.** The user's countries are pre-loaded. The design is pre-selected. The only mandatory action before checkout is choosing a size.

**2. The mockup is the product.** The design studio's mockup panel is the hero element — not the options list. Options are secondary UI. Give the mockup 60%+ of the visible viewport.

**3. One decision at a time.** Each design dimension (style → placement → colour → size) is a single row with clear visual affordances. No multi-column configuration grids.

**4. Trust the Shopify checkout.** Do not rebuild cart management, address entry, or payment in Roavvy. Hand off cleanly at "Proceed to Checkout" and return cleanly after.

**5. Celebrate the purchase.** The post-purchase screen is a moment — not a receipt. Use the same celebration language as the scan summary ("Your 23 countries").

---

## Technical Notes

### Mockup Generation

Two approaches (to be decided by Architect). Both are called from Firebase Functions, not directly from the mobile app or web browser:

**Option A — Printful/Printify Mockup API (recommended for Phase 10)**
- Firebase Functions sends the design parameters + product SKU to the fulfilment partner's mockup endpoint
- Receive a pre-rendered PNG of the shirt/poster with the design applied; return URL to the client
- Cache the result per (countryList hash + style + colour) to avoid repeated API calls
- Latency: ~1–3 seconds per mockup; show skeleton shimmer while loading

**Option B — On-device / in-browser render**
- Render the design client-side (Flutter Canvas on mobile, SVG/Canvas on web)
- Composite onto a transparent shirt overlay PNG
- Zero latency after initial asset load; more complex to maintain
- Deferred to a future phase if Option A is sufficient

### Backend (Firebase Functions)

Firebase Functions is the orchestration layer between the mobile/web app and Shopify. It holds all server-side credentials and performs all Shopify API calls.

**`POST /createMerchCart`**
- Requires Firebase Auth ID token in the `Authorization: Bearer <token>` request header
- Validates the authenticated user
- Saves a `MerchConfig` document to `users/{uid}/merch_configs/{configId}` in Firestore
- Creates a Shopify cart via Storefront API `cartCreate` mutation
- Attaches `{ "merchConfigId": "<configId>" }` as a cart custom attribute
- Returns `{ checkoutUrl, cartId, merchConfigId }` to the client

**`POST /shopify/webhook/orders-created`**
- Receives Shopify `orders/create` webhook
- Authenticated via Shopify HMAC signature on the request header (not Firebase Auth)
- Finds the `MerchConfig` document by `shopifyCartId` (from the order's cart token) and writes `shopifyOrderId` to it

Both functions require no Shopify credentials on the client side.

### Shopify Integration

- Shopify Storefront API (GraphQL) is called from Firebase Functions (server-side) — not from the mobile app or web browser
- Shopify Admin API credentials live only in Firebase Functions environment variables; never in client bundles
- Cart attributes carry only `{ "merchConfigId": "<Firestore doc ID>" }` — the full design config stays in Firestore, avoiding the Shopify 255-char attribute value limit and preventing SKU explosion
- `checkoutUrl` is returned by `POST /createMerchCart` and opened by the app in `SFSafariViewController` (iOS) or as a same-tab redirect (web)
- Shopify Storefront API product catalogue queries (listing products and variants) may be made directly from the client using the public Storefront API token, as these are read-only unauthenticated queries

### Print-on-Demand

- The POD provider (Printful / Printify) connects to the Shopify store as a Shopify app — it receives and fulfils orders automatically through Shopify's fulfilment app mechanism
- No direct Roavvy→POD API call is needed in the PoC
- Custom per-order print file generation (generating unique artwork from the user's country list) is a post-PoC enhancement. For the PoC, the POD fulfils using a static template or the store owner manually supplies the print file per order
- Post-PoC: Firebase Functions will generate the print-ready file and submit it to the POD provider's API when the Shopify `orders/create` webhook fires

### Country List Encoding

The `MerchConfig` document in Firestore stores `selectedCountryCodes` as a `string[]`. Only `merchConfigId` is passed to Shopify as a cart attribute — the full country list stays in Firestore. This avoids the Shopify 255-char cart attribute value limit (ISO alpha-2 codes at 100+ countries ≈ 300 chars).

### Privacy

The country code list (not photos, not GPS coordinates) is the only personal data passed to Shopify and the fulfilment partner. This is consistent with ADR-002: only derived metadata leaves the device. Country codes are not sensitive data. The `MerchConfig` document is stored in Firestore under `users/{uid}/merch_configs/{configId}` — the same security model as visits: accessible only to the authenticated owner.

---

## Open Questions for Architect

1. **Mockup strategy:** Option A (Printful/Printify mockup API called from Firebase Functions) vs Option B (on-device/browser render)? Needs mockup API key and rate limit confirmation before committing to Option A.
2. **Print file generation for PoC:** Static POD template (simplest — store owner assigns a template to the product) vs server-generated artwork (post-PoC). Which approach for launch?
3. **Firebase Functions region:** Should commerce Functions live in the same region as existing Firestore data? Confirm to minimise latency and avoid cross-region egress charges.
4. **Country code list size:** 100+ countries ≈ ~300 chars as a comma-separated string. Shopify cart attribute value limit is 255 chars per value. Decision (ADR-062): pass only `merchConfigId` to Shopify; store full country list in Firestore. Confirm this is implemented correctly in the `cartCreate` mutation before builder starts.

---

## Acceptance Criteria (Phase 10)

- [ ] User can reach the commerce flow from the Stats screen CTA (mobile)
- [ ] User can reach the commerce flow from the `/shop` route (web, signed in)
- [ ] Country selection defaults to all visited countries; user can deselect any
- [ ] At least 3 design styles available: World Map, Flags, Passport Stamps
- [ ] At least 2 placement options: Front only, Back only
- [ ] At least 3 shirt colours available
- [ ] Live mockup updates when design style, placement, or colour changes
- [ ] Front/Back toggle shows both sides of the shirt
- [ ] Size selector with size guide link
- [ ] T-Shirt and Poster available as products
- [ ] Cart review screen shows product summary before Shopify handoff
- [ ] Checkout opens Shopify via `SFSafariViewController` (mobile) / same-tab redirect (web)
- [ ] `visitedCodes`, `designStyle`, `placement`, and `shirtColour` passed as Shopify line item custom properties
- [ ] Post-purchase confirmation screen shown (mobile)
- [ ] Unauthenticated web visitors see `/shop` landing with sign-in CTA
- [ ] No photo data or GPS coordinates are sent to Shopify or the fulfilment partner
