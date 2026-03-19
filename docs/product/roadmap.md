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

## Phase 4 — Web Map (In Progress)

**Goal:** Signed-in users can view their travel map on the web.

| Feature | Notes | Status |
|---|---|---|
| `/sign-in` page | Email/password Firebase Auth | M13 — done |
| `/map` route | Authenticated guard; reads Firestore; renders DynamicMap | M13 — done |
| `/sign-up` page | Create account | M13 — pending |
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

## Phase 10 — Commerce & Web Shop

**Goal:** Users can buy personalised travel merchandise (a travel poster with their visited countries highlighted).

| Feature | Notes |
|---|---|
| Shop landing page (`/shop`) | Accessible without sign-in; featured products |
| Product personalisation | User signs in; visited countries rendered as SVG/PNG map preview |
| Shopify Storefront API | Product catalogue, add to cart, redirect to Shopify checkout |
| Travel poster asset generation | Canvas export of Leaflet map; attached to Shopify line item as custom property |
| In-app shop entry point | "Buy a travel poster" CTA on Stats screen and travel card share flow |

---

## Deferred / Not Planned

- Android support (revisit after iOS App Store launch)
- Social feed or user discovery
- Real-time location tracking
- Multi-device conflict resolution (pull from Firestore)
- City or region-level granularity on the web map
