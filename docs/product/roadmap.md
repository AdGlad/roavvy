# Roadmap

Phases are sequenced by dependency and risk. Each phase must be shippable and internally consistent — no half-built features at the end of a phase.

---

## Phase 1 — Core Scan & Map (Foundation)

**Goal:** A user can scan their photo library and see a world map of the countries they've visited.

| Feature | Notes |
|---|---|
| Swift PhotoKit bridge | Extract GPS + date from photo library; stream to Flutter |
| `country_lookup` package | Bundled geodata; offline resolution; < 5 ms target |
| Local SQLite DB (Drift) | Store `CountryVisit` records; sync metadata |
| Travel map screen | Highlight visited countries; country count |
| Manual add / edit / delete | User edits override auto-detection |
| Scan progress UI | Progress bar; "nothing new" state; error states |
| Permission handling | Full, limited, denied states |
| Incremental scan | Subsequent scans fetch only new photos |

**Not in phase 1:** Firebase sync, achievements, sharing, shop.

---

## Phase 2 — Sync & Achievements

**Goal:** Data syncs across devices. Users are rewarded for milestones.

| Feature | Notes |
|---|---|
| Firebase Auth | Anonymous auth; optional email/Google sign-in |
| Firestore sync | Push dirty records; pull remote changes; conflict resolution |
| Achievement engine | Define achievement set; compute locally; display in-app |
| Achievement unlock animation | Delight moment on first unlock |
| Account deletion | Purge Firestore data; clear local DB |

---

## Phase 3 — Sharing

**Goal:** Users can share their travel record publicly without exposing their identity.

| Feature | Notes |
|---|---|
| Sharing card generation | Snapshot of country list; opaque token |
| Next.js sharing page | SSR; `/share/[token]`; no PII |
| Sharing card revoke | Delete Firestore doc; URL returns 404 |
| Share sheet integration | iOS share sheet from mobile app |

---

## Phase 4 — Web Map & Shop

**Goal:** Users can view their map on the web and buy personalised merchandise.

| Feature | Notes |
|---|---|
| Authenticated web map | Login with same Firebase account; view full map |
| Shopify integration | Product catalogue; personalised with travel data; checkout |
| Travel poster personalisation | Map rendered with user's countries; sent to Shopify |

---

## Phase 5 — Polish & Growth

**Goal:** App is App Store-ready; growth loops are in place.

| Feature | Notes |
|---|---|
| Onboarding flow | First-launch; permission rationale; first scan |
| App Store optimisation | Screenshots, preview video, metadata |
| Referral / share loop | Sharing card drives organic installs |
| Push notifications | Achievement unlocked; sync complete (opt-in) |
| iPad layout | Larger canvas for the travel map |

---

## Not Planned

- Android support (revisit after iOS is stable)
- Social feed or user discovery
- City or region-level granularity
- Real-time location tracking
