# Data Model

## Principles

- Store the minimum data needed to deliver each feature.
- Cloud-stored data is derived metadata only — never raw photo content, EXIF, filenames, or GPS coordinates.
- Country codes: ISO 3166-1 alpha-2 throughout (`"GB"`, `"JP"`).
- Dates: ISO 8601 strings in Firestore; UTC `DateTime` in Dart; UTC `Date` in TypeScript.

---

## Models

### `VisitSource` (enum)

```
auto    — detected from photo metadata
manual  — added or edited by the user
```

`manual` records are never overwritten by automatic detection, regardless of timestamp.

---

### `CountryVisit`

One record per country per user. Keyed by `countryCode` in both local DB and Firestore.

| Field | Type | Description |
|---|---|---|
| `countryCode` | `String` | ISO 3166-1 alpha-2 |
| `firstSeen` | `DateTime` UTC | Earliest photo date in this country |
| `lastSeen` | `DateTime` UTC | Most recent photo date in this country |
| `source` | `VisitSource` | `auto` or `manual` |
| `updatedAt` | `DateTime` UTC | Last local modification time — used for sync conflict resolution |

**Local DB only (not synced to Firestore):**

| Field | Type | Description |
|---|---|---|
| `isDirty` | `bool` | True if not yet synced to Firestore |
| `syncedAt` | `DateTime?` UTC | Timestamp of last successful sync |
| `isDeleted` | `bool` | Soft-delete flag; record is tombstoned in Firestore until hard-deleted |

---

### `TravelProfile`

Aggregated stats, stored as a single Firestore document. Counts are derived from the visits subcollection and recomputed locally; stored in Firestore for the web app to read without fetching all visit documents.

| Field | Type | Description |
|---|---|---|
| `userId` | `String` | Firebase Auth UID |
| `schemaVersion` | `int` | Incremented on breaking schema changes; both apps check this on read |
| `totalCountries` | `int` | Derived from visit count |
| `totalContinents` | `int` | Derived from visit country codes |
| `lastSyncedAt` | `DateTime` UTC | Timestamp of last successful Firestore sync |

---

### `Achievement`

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Stable identifier, e.g. `"first_country"`, `"ten_countries"` |
| `unlockedAt` | `DateTime` UTC | When first earned |

Achievements are computed locally and synced to Firestore. They are append-only — once unlocked, never removed.

---

### `SharingCard`

A point-in-time snapshot. Created explicitly by the user. Contains no identity information.

| Field | Type | Description |
|---|---|---|
| `token` | `String` | Opaque, non-guessable URL token (≥ 128 bits entropy) |
| `countryCodes` | `List<String>` | Country codes at time of generation |
| `totalCountries` | `int` | Count at time of generation |
| `generatedAt` | `DateTime` UTC | Snapshot timestamp |

Revoking a card deletes the Firestore document; the public URL returns 404 immediately.

---

## Firestore Structure

```
users/{userId}
  ├── profile                    (TravelProfile document)
  ├── visits/
  │     └── {countryCode}        (CountryVisit document, one per country)
  ├── achievements/
  │     └── {achievementId}      (Achievement document)
  └── sharingCards/
        └── {token}              (SharingCard document)
```

Visits are a subcollection, not an array on the profile document. This avoids Firestore document size limits and allows granular reads and writes.

## Local Storage (Mobile)

SQLite via Drift. Schema mirrors Firestore with additional sync metadata columns (`isDirty`, `syncedAt`, `isDeleted`). The local DB is the primary data store; Firestore is the sync target.

## What Is Never Stored

| Data | Local DB | Firestore |
|---|---|---|
| Photo binary / thumbnails | Never | Never |
| GPS coordinates | Never (discarded post-resolution) | Never |
| Full EXIF data | Never | Never |
| Photo filenames | Never | Never |
| Asset identifiers (PHAsset) | Never | Never |
| User's real name or email | Not stored | Not stored |
