# Roadmap

Phases are sequenced by dependency and risk. Each phase must be shippable and internally consistent — no half-built features at the end of a phase. The mobile app ships to the App Store before the commerce experience begins.

---

## Completed Phases

| Phase | Goal | Status |
|---|---|---|
| Phase 1 — Core Scan & Map | Scan photos, see world map, manual edits | ✅ Complete |
| Phase 2 — Sync & Achievements | Firebase Auth, Firestore sync, achievement engine | ✅ Complete |
| Phase 3 — Sharing | Travel card image, web share page, share sheet, token revocation | ✅ Complete |
| Phase 5 — Trip Intelligence (M15) | Trip inference, trip storage, trip list in country detail, manual trip editing | ✅ Complete |
| Phase 6 — Geographic Depth (M16 slice) | Region detection (ISO 3166-2 offline), region_visits table, region list in country detail | ✅ Complete — remaining Phase 6 features (city detection, continent overlay, region achievements) deferred |

---

## Phase 4 — Web Map ✅ Complete (M13 + M14)

**Goal:** Signed-in users can view their travel map on the web.

| Feature | Notes | Status |
|---|---|---|
| `/sign-in` page | Email/password Firebase Auth | M13 — done |
| `/map` route | Authenticated guard; reads Firestore; renders DynamicMap | M13 — done |
| `/sign-up` page | Create account | M14 — done |
| Sign-out | On `/map` page | M13 — done |

---

## Phase 5 — Trip Intelligence (Mobile)

**Goal:** Every country visit becomes a named trip with dates. Users see how many times they've been somewhere, not just whether they've been.

A **trip** is a contiguous cluster of photos taken in the same country within a configurable time window (default: 30-day gap = new trip). Trips are inferred automatically from the existing scan data and stored locally.

| Feature | Notes |
|---|---|
| Trip inference engine | Group photos by country + time cluster; produce trip records with start/end dates |
| Trip storage | New Drift table: `trips` (id, country_code, started_on, ended_on, photo_count) |
| Trip count on map | Country polygon label or detail sheet shows "X trips" |
| Country detail — trips list | Tap country → see each trip as a card (dates, duration, photo count) |
| Manual trip editing | Edit start/end dates; merge trips; delete a trip |
| Firestore sync | Push trip records alongside existing inferred/added/removed collections |

**Not in this phase:** region/city detection, photo gallery.

---

## Phase 6 — Geographic Depth (Mobile)

**Goal:** Visits have sub-country resolution. Users see which regions and cities they explored within each country.

| Feature | Notes |
|---|---|
| Region detection | Offline ISO 3166-2 admin1 polygon lookup (bundled into `country_lookup`) |
| City detection | Offline major city lookup via bundled dataset (~30k cities, coordinate nearest-match) |
| Region + city persistence | Stored per photo coordinate in Drift; linked to trips |
| Continent map screen layer | At world zoom: show 6 continent overlays with country counts |
| Region view in country detail | List of regions detected within a country |
| City view in trip detail | Cities visited on a specific trip |
| Achievements: regions | New achievements for visiting X regions, all regions of a country |

**Offline constraint:** All region and city data is bundled. Zero network calls for geographic resolution.

---

## Phase 7 — Rich Mobile Experience (Navigation Redesign) — M17 In Planning

**Goal:** The app has a complete, polished navigation structure. Every piece of travel data is one or two taps away.

**M17 scope (Tasks 47–49):** 4-tab nav shell (Map · Journal · Stats · Scan), Journal screen, Stats & Achievements screen. Country Detail full-screen, Trip Detail, and remaining map enhancements deferred to M18.

### Navigation — 4 tabs

| Tab | Icon | Content |
|---|---|---|
| **Map** | Globe | World map (primary experience) |
| **Journal** | Book | All trips, chronological, grouped by year |
| **Stats** | Chart | Travel stats + achievement gallery |
| **Scan** | Camera | Photo scanner |

### Map Screen (Redesigned)

- Multi-zoom: World → Continent → Country → Region
- Country polygons coloured by visit frequency (deeper green = more trips)
- Continent labels at world zoom with country count badges
- Stats strip: countries · continents · trips
- Floating action button: quick-add a country
- ⋮ menu: Share travel card · Privacy & account

### Country Detail (Full Screen, replaces bottom sheet)

- Hero: country name + flag + "X trips · First visited [year]"
- **Trips tab**: chronological list of trips; each card shows dates, duration, region count, photo count; tap → Trip Detail
- **Map tab**: mini-map showing the country with regions coloured
- **Regions tab**: list of regions/states visited; percentage of country explored
- **Photos tab**: photo grid (fetched on-device via photo local identifiers)
- Edit controls: add trip · add to/remove from map
- Celebration badge if this country unlocked an achievement

### Trip Detail Screen

- Header: Country flag + "Trip to [Country]" + date range + duration
- Mini-map: country outline with regions highlighted for this trip
- Regions visited on this trip
- Cities visited on this trip
- Photo grid for this trip (on-device)
- Edit: adjust dates · delete trip

### Journal Screen

- Grouped by year (sticky section header: "2023 — 14 trips · 8 countries")
- Each entry: flag, country name, date range, trip duration, region count, thumbnail
- Filter by: continent · country · year
- Search by country name

### Stats & Achievements Screen

- **Stats panel**: countries visited · continents · trips · years of travel · most visited country · longest trip · total days abroad (estimated)
- **Continent breakdown**: 6 continent tiles, each showing countries visited vs. total
- **Achievements gallery**: grid of all 8+ achievements; locked achievements shown greyed with hint; unlocked with date and share button
- **Timeline chart**: countries-per-year bar chart

---

## Phase 8 — Celebrations & Delight

**Goal:** The app celebrates your travel milestones. First-use is magical.

| Feature | Notes |
|---|---|
| Onboarding flow | Welcome screen → permission rationale → scan → animated map reveal |
| New country celebration | Confetti burst + "You've visited [Country]!" full-screen moment after scan |
| New continent celebration | Special animation for first country on each continent |
| Achievement unlock animation | Triggered post-scan and post-review; share button inline |
| Map reveal animation | Countries highlight one-by-one on first scan completion |
| Milestone toasts | Unobtrusive banner: "10 countries! You've unlocked Seasoned Traveller" |
| Scan summary redesign | After scan: hero screen showing new countries found + achievements unlocked |

---

## Phase 9 — App Store Readiness

**Goal:** The app is ready for public App Store submission.

| Feature | Notes |
|---|---|
| App icon (final) | Designed asset, all required sizes |
| Screenshots | 6.9" iPhone required; 12.9" iPad optional |
| App preview video | 30-second capture of key moments |
| App Store metadata | Title, subtitle, description, keywords, privacy policy URL |
| Push notifications (opt-in) | Achievement unlocked; "Scan for new photos" 30-day nudge; APNs + FCM |
| iPad layout | Side-by-side map + detail panel on wide canvas |
| Referral CTA on share page | "Get Roavvy" banner on `/share/[token]` web page |

---

## Phase 10 — Commerce & Personalised Merchandise ✅ Mobile Complete (M20A + M20 + M24)

**Goal:** Users can buy personalised travel merchandise — t-shirts and posters — with their visited countries rendered as a design. Print-on-demand via Shopify + Printful/Printify. Available on mobile (iOS app) and web.

**M24 (In Progress):** Preview-first checkout, post-purchase celebration screen, order history. Mobile only.

**UX spec:** [docs/ux/commerce_flow.md](../ux/commerce_flow.md)

**Architecture:** See ADR-062. Commerce uses a backend-mediated four-layer architecture: mobile app → Firebase Functions → Shopify Storefront API → POD Shopify app. The mobile app never calls Shopify directly; all cart creation happens server-side.

| Feature | Notes |
|---|---|
| Country selection | Default: all visited countries pre-selected; user can deselect |
| Product browser | T-shirt (primary) + Travel poster; live mockup per product using user's selection |
| Design studio — styles | World Map · Flags · Passport Stamps |
| Design studio — options | Placement (Front / Back / Both) · shirt colour · size |
| Live mockup | Mockup image fetched from Printful/Printify mockup API (called from Firebase Functions); skeleton shimmer while loading |
| `MerchConfig` persistence | Design payload saved to Firestore (`users/{uid}/merch_configs/{configId}`) by Firebase Functions before cart creation |
| Cart creation (server-side) | Firebase Functions calls Shopify Storefront API `cartCreate`; attaches `merchConfigId` as cart attribute; returns `checkoutUrl` to app |
| Shopify checkout | `checkoutUrl` opened in `SFSafariViewController` (mobile) / redirect (web); Shopify-hosted checkout for PCI compliance |
| Post-purchase screen | Native celebration screen (mobile); Shopify confirmation page (web) |
| Order webhook | Shopify `orders/create` webhook received by Firebase Functions; links `orderId` to `MerchConfig` in Firestore |
| POD fulfilment | POD provider connects to Shopify as a Shopify app — receives and fulfils orders automatically through Shopify; no direct Roavvy→POD API in PoC |
| `/shop` public landing page | Accessible without sign-in; sample mockups; prompts sign-in to personalise |
| In-app entry points | Stats screen "Shop" button (primary); travel card share flow; scan summary |
| Web entry points | Nav bar link on `/map`; CTA on `/share/[token]`; direct `/shop` URL |

**Not in PoC:** Custom per-order print file generation (generating unique artwork from the user's country list at order time). For the PoC, the store owner manually supplies or selects the print file per order. Post-PoC, Firebase Functions will generate and submit the print file to the POD provider's API via the order webhook.

**Prerequisites (external):**
- Firebase project with Cloud Functions enabled (Blaze/pay-as-you-go plan)
- Shopify store created with product variants (colour × size) configured; one product per merch template
- Shopify Admin API token — stored in Firebase Functions environment only, never in client
- Shopify Storefront API token — used by Firebase Functions for cart creation
- Printful or Printify app connected to Shopify store as a Shopify app
- Fulfilment partner mockup API access confirmed (called from Firebase Functions, not from client)

---

## Phase 11 — Gamified Map & Progression System ✅ Complete (M22–M26, excl. soft social ranking — deferred)

**Goal:** Transform the map from a static travel record into an emotionally engaging progression system. Users feel rewarded for every country discovered, motivated to complete regions, and proud of their travel identity.

**UX spec:** [docs/ux/gamified_map.md](../ux/gamified_map.md)

**Design target:** Premium + playful. Apple Maps craft meets Duolingo progression. The map remains the hero — gamification serves the map, not the other way around.

| Feature | Notes |
|---|---|
| Country visual states | 5 states: unvisited / visited / reviewed / newly-discovered / target. Polygon fill, border, and animation differ per state. |
| XP + level system | XP awarded for country discovery, region completion, scan completion, sharing. Level indicator + progress bar in map top strip. 8 levels: Wanderer → Legend. |
| Discovery overlay | Full-screen moment when a new country is detected. Country name, flag emoji, XP earned, "Add to map" CTA. Haptic feedback. |
| Region progress chips | Floating chips on map at region centroids (e.g. "4/5 Nordic"). Tap → region detail sheet with country list and missing countries highlighted. |
| Milestone cards | Slide-up celebration at 5, 10, 25, 50, 100 countries. Badge + share button. |
| Rovy mascot | Contextual quokka speech bubble. Used sparingly: celebration, encouragement, one-more-to-go nudge. Never interrupts flow. |
| Soft social ranking | "You've explored more than 72% of Roavvy travellers." Shown subtly in Stats screen and achievements. No leaderboard. |
| Progressive scan reveal | During first scan: countries appear one-by-one as detected. Not a loading screen — a discovery moment. |
| Timeline scrubber | Filter map to show countries visited before a given year. Scrubber at bottom of map screen. Uses existing trip date data. |
| Country depth colouring | Countries coloured by trip frequency: 1 visit = light amber, 5+ = deep gold. No new data required. |

**Not in this phase:** city-level colouring, social feed, real-time comparison with friends.

**Dependencies:** Phase 10 commerce must be stable first. XP system must not conflict with existing achievement engine — coordinate in ADR.

---

---

## Phase 12 — Commerce & Mobile Completion

**Goal:** Complete the shopping experience on web; ensure mobile app is fully polished for launch.

| Milestone | Goal |
|---|---|
| M27 — Web Shop landing page | Public `/shop` page + nav/share entry points |
| M28 — Web Commerce checkout | Authenticated country selection → `createMerchCart` → Shopify redirect |
| M29 — Mobile entry points + scan nudge | Scan summary + share CTAs + 30-day in-app nudge |
| M30 — Firestore Trip Sync | Trip records synced to Firestore; trip count on web map | ✅ **Complete** |
| M31 — Web password reset | `/forgot-password` page; link from `/sign-in` |
| M33 — Commerce sandbox validation | End-to-end test purchase → Shopify webhook → Printful draft order; no real card charged | ✅ **Complete** |
| M34 — Mobile mockup preview | Photorealistic t-shirt mockup shown before checkout (Printful Mockup API) | ✅ **Complete** |
| M35 — Trip Region Map | Journal trip tap → country map with visited regions highlighted | ✅ **Complete** |
| M36 — Country Region Map | Stats Regions breakdown → country map with all visited regions highlighted; tap region → name label | ✅ **Complete** |

---

## Phase 13 — Identity Commerce (Achievement-Driven)

**Goal:** Transform commerce from store-driven browsing to an identity-driven system anchored to Travel Cards. Users create personalised travel cards from their detection data, share them, and flow naturally from card creation into printing merchandise.

**Strategy:** Design-first. The Travel Card is the primary entity. Physical products are output formats for a card. Commerce CTAs appear only after positive emotional events (scan, achievement unlock, level-up) — never as a browse-first store experience.

**XP level labels updated (pre-Phase 13):** Traveller → Explorer → Navigator → Globetrotter → Pathfinder → Voyager → Pioneer → Legend (XP thresholds unchanged).

**Migration phases:**
1. **Phase 13a** — Add Cards concept alongside existing Shop (M37–M38)
2. **Phase 13b** — Print flow from card; achievement-triggered commerce (M39–M40)
3. **Phase 13c** — Reduce Shop tab emphasis; move Shop under Cards (M41)
4. **Phase 13d** — Full nav restructure: World · Achievements · Cards · Profile (M42+)

| Milestone | Goal | Status |
|---|---|---|
| M37 — Travel Card Generator | TravelCard data model + card generator screen (3 templates: grid, heart, passport stamps) + entry points from Stats and Map | ✅ Complete |
| M38 — Print from Card | "Print" CTA on card preview → product selection → `createMerchCart` with card design; replaces direct product browsing as primary commerce path | ✅ Complete |
| M39 — Achievement & Level-Up Commerce Triggers | Level-up modal with "Create your [Level] shirt" CTA; commerce offer on milestone card (5/10/25/50/100 countries) | ✅ Complete |
| M40 — Scan & Map Commerce Triggers | New-country scan → card creation nudge; map "Create poster" menu item | ✅ Complete |
| M43 — Scan Delight: Real-Time Discovery | Discovery toast + inline world map + micro-confetti during scan; post-scan flag timeline; app-open scan prompt | Not started |
| M41 — Shop De-emphasis | Move Shop tab content inside Cards tab; Stats-screen "Shop" button replaced by "Cards" | Deferred |

**New data entities:**
- `TravelCard` (Firestore `travel_cards/{cardId}`): cardId, userId, templateType (grid|heart|passport), countryCodes, countryCount, previewImageUrl, createdAt, updatedAt, schemaVersion
- `MerchOrder` refactor: link to `cardId` instead of ad-hoc design payload

**Commerce copy rules:** "Turn your travels into a shirt" not "Buy this shirt". "Print your travel map" not "View products". CTAs feel optional and celebratory.

**Not in this phase:** additional product categories beyond tee/poster, social commerce features, web Cards UI.

---

## Phase 14 — Scan Delight & Real-Time Discovery

**Goal:** Make every scan feel alive. Real-time animated feedback during scanning; dramatic post-scan reveal; proactive re-engagement on app open.

| Milestone | Goal | Status |
|---|---|---|
| M43 — Scan Delight: Real-Time Discovery | Discovery toast + inline world map + micro-confetti during scan; post-scan flag timeline; app-open scan prompt | **Next** |

---

## Deferred / Not Planned

- Android support (revisit after iOS App Store launch)
- Social feed or user discovery — soft social ranking (aggregate percentile comparison) is partially addressed in Phase 11; a full social feed with user-to-user interaction remains deferred
- Real-time location tracking
- Multi-device conflict resolution (pull from Firestore)
- City or region-level granularity on the web map
