# Backlog — Future Milestones

---

## Phase Completion Status (as of 2026-03-19)

| Phase | Description | Status |
|---|---|---|
| Phase 1 — Core Scan & Map | PhotoKit bridge, country_lookup, Drift DB, map, scan, manual edits | ✅ **Complete** |
| Phase 2 — Sync & Achievements | Firebase Auth (anon + Apple), Firestore sync, achievement engine + UI, account deletion | ✅ **Complete** |
| Phase 3 — Sharing | Travel card image, web share page `/share/[token]`, share sheet, token revocation | ✅ **Complete** |
| Phase 4 — Web Map | Authenticated web map (`/sign-in`, `/map`) | ✅ **M13 complete** — sign-up (M14) deferred |
| Phase 5 — Trip Intelligence | Trip inference, trip storage, trip editing | ✅ **Complete (M15)** |
| Phase 6 — Geographic Depth | Region detection (ISO 3166-2) | 🔄 **Slice 1 complete (M16)** — city detection + continent overlay deferred |
| Phase 7 — Rich Mobile Experience | 4-tab shell, Journal, Stats + achievement gallery | ✅ **Complete (M17)** |
| Phase 8 — Celebrations & Delight | Onboarding, new-country celebration, achievement animation, scan summary | 🔲 Not started |
| Phase 9 — App Store Readiness | Icon, screenshots, push notifications, iPad layout, referral CTA | 🔲 Not started |
| Phase 10 — Commerce | Shopify Storefront API, travel poster, shop landing page | 🔲 Not started |

See [docs/product/roadmap.md](../product/roadmap.md) for full phase definitions.
See [docs/ux/mobile_ux_spec.md](../ux/mobile_ux_spec.md) for the mobile UX specification.

### Phase 2 — remaining gap (absorbed into Phase 8)
- Achievement unlock animation — deferred; now planned as part of Phase 8 Celebrations.

### Phase 3 — no remaining gaps
All sharing features are complete as of M12.

---

## Milestone 12 — Phase 2/3 Closeout ✅ COMPLETE (2026-03-17)

**Goal:** Close the remaining Phase 2 and Phase 3 gaps before starting Phase 4.

**Delivered:**
- Task 31: Share token revocation — `PrivacyAccountScreen`, `ShareTokenService.revokeToken`, Firestore delete rule fix
- Task 32: Account deletion — `AccountDeletionService`, two-confirmation dialog flow, auth + Firestore + local data purge

---

## Milestone 13 — Phase 4: Authenticated Web Map ✅ COMPLETE (2026-03-19)

**Goal:** Signed-in users can open `roavvy.app/map` in a browser, sign in with the same Firebase account used on their phone, and see their live travel map.

**Why this comes first:** Phase 4's commercial goal (selling merchandise personalised with the user's travel data) requires a web-authenticated map as the foundation. The shop must read the user's country set from Firestore — which requires the user to be signed in on web.

**Scope — included:**
- Sign-in page (`/sign-in`): Firebase Auth JS SDK; Sign in with Google (primary) and Sign in with Apple (secondary); anonymous accounts cannot sign in here (no anonymous session on web)
- `/map` route: authenticated guard (redirect to `/sign-in` if not signed in); reads `users/{uid}/inferred_visits`, `user_added`, `user_removed` from Firestore; computes effective visited countries client-side; renders world map with Leaflet + existing `DynamicMap`/`Map` components
- Sign-out action on `/map` page
- Updated Firestore rules: allow read of `users/{uid}/...` subcollections only by matching `request.auth.uid == uid`
- Loading and error states on `/map`

**Scope — excluded:**
- Shopify integration (Milestone 14)
- Country editing on web (mobile-only for now)
- Multi-device conflict resolution (deferred indefinitely)

**Technical notes:**
- The web app already has Firebase SDK wired (`apps/web_nextjs/`), Leaflet, and the `DynamicMap`/`Map` components from Task 30. The map rendering can be reused directly.
- The effective visited countries computation (inferred − removed + added) must be reimplemented in TypeScript — this is the only non-trivial logic. Keep it simple: load all three subcollections, apply the merge rules.
- Google Sign-In is easier to implement on web than Apple (no nonce/callback complexity). Start with Google; add Apple if needed.
- Firestore rules for `users/{uid}` subcollections currently have no explicit read rule — the wildcard `allow read, write` is too broad; this milestone tightens them.

**Delivered:** `/sign-in` (Google + Apple), `/map` authenticated route, effective-visits merge in TypeScript, Firestore rules tightened, loading + error states.

---

## Milestone 14 — Phase 4: Web Sign-Up

**Goal:** Users can create a Roavvy account on the web with email/password, completing the web auth flow.

**Scope — included:**
- `/sign-up` page: email + password fields; Firebase `createUserWithEmailAndPassword`; validation (email format, password min 8 chars); on success → redirect to `/map`
- Error states: "email already in use", "weak password", "network error"
- Link from `/sign-in` → "Don't have an account? Sign up"
- Link from `/sign-up` → "Already have an account? Sign in"

**Scope — excluded:**
- Email verification (deferred)
- Password reset (deferred)
- Social sign-in on web

**Not started. No tasks written yet.**

---

## Milestone 15 — Phase 5: Trip Intelligence (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** Every country visit becomes a set of named trips with inferred dates. Users see trip counts on the map and a chronological trip list per country.

**Scope — included:**
- `TripRecord` domain model in `shared_models`: `id`, `countryCode`, `startedOn`, `endedOn`, `photoCount`
- Trip inference engine: clusters `InferredCountryVisit` photo records by country + 30-day gap; produces `TripRecord` list
- Drift `trips` table (schema v4): stores inferred trips; `isDirty`/`syncedAt` columns
- `TripRepository`: upsert, load by country, load all, clear
- Trip count shown on country detail sheet ("X trips")
- Trips list in country detail (date cards)
- Manual trip: add / edit dates / delete
- Firestore sync: push trip records to `users/{uid}/trips/{tripId}`

**Scope — excluded:**
- Photo gallery (Phase 7)
- Region/city detection (Milestone 16)
- Journal tab (Milestone 17)

**Delivered:** `TripRecord` + `TripInference` in `shared_models`; `trips` Drift table (schema v5); `TripRepository`; `TripEditSheet`; `BootstrapService` back-fills trips from existing scan data.

---

## Milestone 16 — Phase 6 Slice 1: Region Detection (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** After a photo scan, users see which regions (admin1) they visited within each country — resolved entirely offline.

**Scope — included:**
- `packages/region_lookup`: offline ISO 3166-2 admin1 polygon lookup
- Schema v7: `PhotoDateRecord.regionCode` column; scan pipeline resolves region codes in background isolate
- `RegionVisit` domain model + `region_visits` Drift table + `RegionRepository`
- Scan pipeline + bootstrap produce `RegionVisit` records
- Region count + region list in country detail sheet

**Scope — excluded (deferred to future milestones):**
- City detection (`packages/city_lookup`)
- Continent overlay on world map
- Region-level achievements
- Firestore sync for region_visits
- User-edit override for regions

**Offline constraint:** All geodata bundled. Zero network calls.

**Delivered:** `packages/region_lookup` (offline admin1 binary, 3.5 MB); `RegionVisit` + `region_visits` Drift table (schema v7); `RegionRepository`; scan pipeline resolves region codes; `BootstrapService` back-fills region visits; region count + expandable list in `CountryDetailSheet`. Tasks 42–46.

---

## Milestone 17 — Phase 7: Navigation Redesign & Rich Screens (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** 4-tab navigation. Journal tab lists all trips. Stats tab shows comprehensive stats + achievement gallery.

**Scope — included:**
- Navigation: 4-tab bottom bar (Map · Journal · Stats · Scan) replacing current 2-tab
- Map screen: visit-frequency colour gradient; stats strip updated (countries · continents · trips); continent labels at world zoom
- Country Detail: full-screen push (replaces bottom sheet); tabs: Overview · Trips · Regions · Photos
- Trip Detail: full-screen push; mini-map; regions; cities; photo grid
- Journal tab: chronological all-trips list; grouped by year; filter sheet
- Stats tab: stats panel (countries, continents, trips, years, longest trip); continent breakdown tiles; achievements gallery (locked + unlocked); per-year bar chart
- Photo grid (on-device via PhotoKit local identifiers stored during scan)
- Country share card (flag + trip count + top regions)
- Achievement share card (badge + title + unlock date)

**Delivered:** 4-tab `NavigationBar` + `IndexedStack` in `MainShell` (ADR-052); `JournalScreen` (trip list grouped by year, country flags, taps open CountryDetailSheet); `StatsScreen` (stats panel + achievement gallery grid, unlocked-first sort, amber trophy / grey lock icons); `AchievementRepository.loadAllRows()`; `regionCountProvider`. Tasks 47–49. 291 flutter tests passing.

---

## Milestone 18 — Phase 8: Celebrations & Delight (Mobile)

**Goal:** The app celebrates milestones. First use is magical.

**Scope — included:**
- Onboarding flow (4 screens): Welcome · Permission rationale · Scanning · Map reveal (animated)
- New country celebration: full-screen confetti + flag animation
- New continent celebration: globe-spin animation
- Achievement unlock sheet: slide-up with badge animation; share button
- Scan summary screen: replaces inline state; shows new countries, new trips, achievements unlocked; animated map reveal
- "Nothing new" state: compact, friendly, shows last-scan date
- All animations respect `reduceMotion` accessibility setting

**Not started. No tasks written yet.**

---

## Milestone 19 — Phase 9: App Store Readiness

**Goal:** App is ready for public App Store submission.

**Scope — included:**
- Final app icon (all required sizes)
- App Store screenshots (6.9" iPhone; 12.9" iPad optional)
- App preview video (30 seconds)
- App Store metadata: title, subtitle, description, keywords, privacy policy URL
- Push notifications (opt-in): achievement unlocked · 30-day scan nudge; APNs + FCM setup
- iPad layout: side-by-side map + detail panel; split scan + review
- "Get Roavvy" CTA on `/share/[token]` web share page

**Not started. No tasks written yet.**

---

## Milestone 20 — Phase 10: Shop & Merchandise

**Goal:** Users can buy personalised travel merchandise (a travel poster with their visited countries highlighted) via a Shopify-hosted checkout.

**Why:** This is the primary revenue stream. The product is differentiated: a physical travel poster that reflects the user's actual travel history, not a generic map.

**Scope — included:**
- Shop landing page (`/shop`): accessible without sign-in; shows featured products
- Product personalisation flow: user signs in (or is already signed in from `/map`), their visited country codes are loaded, the map is rendered as an SVG/PNG preview
- Shopify Storefront API integration: product catalogue, add to cart, redirect to Shopify checkout
- Travel poster asset generation: render the Leaflet map to an image (canvas export); attach to the Shopify line item as a custom property (`visitedCodes` array) for fulfilment
- In-app [Buy a travel poster] CTA on Stats screen and travel card share flow

**Scope — excluded:**
- Shopify admin / product management (done manually by the business)
- Custom fulfilment automation (deferred — initially handled manually)
- Physical print quality rendering (the web map is the preview; actual print files are separate)

**Technical risks:**
1. **Shopify Storefront API**: requires a Shopify store and a private app token. Setup is a prerequisite.
2. **Map-to-image export**: Leaflet renders to a `<canvas>` — `canvas.toDataURL()` gives a PNG. Custom layers (polygons) must be on canvas, not SVG. May need to switch from the current SVG-based GeoJSON layer to a canvas layer. Needs a spike.
3. **Passing the country set to Shopify**: Storefront API allows line item custom attributes. The `visitedCodes` array goes in there. Fulfilment system reads it to generate the custom print file.

**Not started. No tasks written yet.**

---

## Milestone 14 — Phase 4: Shop & Merchandise [SUPERSEDED — see Milestone 20]

**Goal:** Users can buy personalised travel merchandise (a travel poster with their visited countries highlighted) via a Shopify-hosted checkout.

**Why:** This is the primary revenue stream. The product is differentiated: a physical travel poster that reflects the user's actual travel history, not a generic map.

**Scope — included:**
- Shop landing page (`/shop`): accessible without sign-in; shows featured products
- Product personalisation flow: user signs in (or is already signed in from `/map`), their visited country codes are loaded, the map is rendered as an SVG/PNG preview
- Shopify Storefront API integration: product catalogue, add to cart, redirect to Shopify checkout
- Travel poster asset generation: render the Leaflet map to an image (canvas export); attach to the Shopify line item as a custom property (`visitedCodes` array) for fulfilment

**Scope — excluded:**
- Shopify admin / product management (done manually by the business)
- Custom fulfilment automation (deferred — initially handled manually)
- Physical print quality rendering (the web map is the preview; actual print files are separate)

**Technical risks:**
1. **Shopify Storefront API**: requires a Shopify store and a private app token. Setup is a prerequisite.
2. **Map-to-image export**: Leaflet renders to a `<canvas>` — `canvas.toDataURL()` gives a PNG. Custom layers (polygons) must be on canvas, not SVG. May need to switch from the current SVG-based GeoJSON layer to a canvas layer. Needs a spike.
3. **Passing the country set to Shopify**: Storefront API allows line item custom attributes. The `visitedCodes` array goes in there. Fulfilment system reads it to generate the custom print file.

**Not started. No tasks written yet.**

---

## Milestone 15 — Phase 5: Trip Intelligence [see new M15 above]

> This entry superseded. Phase 5 is now Trip Intelligence (mobile). See Milestone 15 above.
> Old Phase 5 (Polish & App Store Readiness) is now Milestones 18 and 19.

---

## Deferred items (no milestone assigned)

- Firestore pull / multi-device conflict resolution
- Map zoom-to-country on tap (replaced by Country Detail full-screen in M17)
- Vertex simplification for map rendering performance
- `packages/shared_models` TypeScript counterpart (effective-visits merge logic for web)
- CI deployment of `firestore.rules`
- Firestore rules comprehensive security review
- Android support (revisit after iOS App Store launch)
- Email verification for web accounts
- Password reset flow for web accounts
- Social sign-in on web (Google / Apple) — deferred; email/password is sufficient for M13/14
- "Scan for new photos" button when > 30 days since last scan (currently the user must go to Scan tab manually)
