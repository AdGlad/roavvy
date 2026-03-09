# System Overview

## What Roavvy Does

Roavvy turns a user's existing photo library into a record of every country they have visited. No photos leave the device. GPS metadata is resolved to country codes on-device, offline, and only the resulting country records sync to the cloud.

## System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                         Device (iOS)                          │
│                                                               │
│  Photo Library                                                │
│       │  CLLocation + creationDate (no image data)           │
│       ▼                                                       │
│  Swift PhotoKit Bridge  ──── batched IPC ────►               │
│                                                               │
│  Flutter Scan Service                                         │
│       │  lat/lng per photo                                    │
│       ▼                                                       │
│  packages/country_lookup  ◄── bundled geodata (Natural Earth) │
│       │  countryCode (coordinates discarded immediately)      │
│       ▼                                                       │
│  Local SQLite DB (Drift)                                      │
│       │  CountryVisit records + user edits                    │
│       ▼  (when online, background)                            │
│  Firestore sync adapter                                       │
│             │                                                 │
└─────────────│─────────────────────────────────────────────────┘
              │  country codes + date ranges only
              ▼
     ┌────────────────────┐
     │  Cloud Firestore   │◄──── Firebase Auth (anonymous + sign-in)
     └──────────┬─────────┘
                │
     ┌──────────▼─────────┐
     │   Next.js web app  │
     │  ├── Authenticated │  travel map, achievements
     │  ├── share/[token] │  public SSR travel card (no user identity)
     │  └── shop/         │──── Shopify Storefront API
     └────────────────────┘
```

## Data Flow

1. User taps "Scan Photos". Swift PhotoKit bridge streams batches of `{lat, lng, capturedAt}` to Flutter via platform channel. No image data crosses the boundary.
2. Flutter Scan Service passes each coordinate to `country_lookup.resolveCountry()`. Coordinates are discarded immediately after resolution.
3. Resolved `CountryVisit` records are merged into local SQLite. User edits already in the DB are never overwritten.
4. Achievements are computed locally from the updated visit set.
5. When connectivity is available, dirty records sync to Firestore (country codes and date ranges only).
6. The Next.js web app reads from Firestore to render the travel map and public sharing pages.

## Components

| Component | Technology | Role |
|---|---|---|
| Mobile app | Flutter + Swift (iOS) | Scanning, map, achievements, offline experience |
| Web app | Next.js 14+ (App Router) | Map viewer, public sharing pages, merchandise |
| `country_lookup` | Dart, pure, no deps | Offline GPS → country code resolution |
| `shared_models` | Dart + TypeScript | Canonical data schema, serialisation |
| Auth | Firebase Auth | Anonymous identity; optional persistent sign-in |
| Cloud DB | Cloud Firestore | Sync of derived metadata only |
| Commerce | Shopify Storefront API | Product catalogue and checkout (web only) |

## Key Design Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| GPS coordinates discarded after resolution | Privacy guarantee is structural, not policy-based | Cannot re-resolve if geodata is updated; requires an app update |
| Geodata bundled at build time | No network dependency for core feature | Increases binary size; updates ship with app releases |
| Local DB is source of truth on mobile | Full offline capability; sync is secondary | Conflict resolution required for multi-device edits |
| User edits permanently override auto-detection | User agency; prevents frustrating re-detection | Auto-detection cannot self-correct a user's manual entry |
| Firestore subcollection per visit | Granular reads and writes; avoids document size limits | Slightly more complex query patterns than a single document |
