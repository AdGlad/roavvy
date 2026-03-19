# Privacy Principles

## The Guarantee

Roavvy's privacy model is structural, not policy-based. The scan pipeline is designed as a one-way reduction: GPS coordinates go in, a country code comes out, and the coordinates are discarded immediately. There is no code path that uploads a photo, stores a coordinate, or persists any data richer than a country code and a date.

This is a stronger claim than "we won't do it." It means the capability does not exist.

---

## What Happens to Each Data Type

| Data | What happens |
|---|---|
| Photo pixels / image data | Never read. PhotoKit bridge extracts only location and date metadata. |
| GPS coordinates | Passed to `resolveCountry()`, then discarded. Never written to DB or sent over network. |
| Capture date | Retained as `firstSeen` / `lastSeen` on `CountryVisit`. |
| PHAsset identifier | Stored in local SQLite `photo_date_records` table (`asset_id` column). Never written to Firestore. Used only for on-device photo gallery display (ADR-060). |
| Photo filename | Never read. |
| Country code | Written to local DB; synced to Firestore with user consent. |

---

## The Scan Pipeline

```
Photo asset (PHAsset)
    │
    │  Swift PhotoKit bridge reads:
    │    CLLocation (lat, lng)  ← extracted
    │    creationDate           ← extracted
    │    PHAsset.localIdentifier ← written to local SQLite only (ADR-060)
    │    image data             ← never accessed
    ▼
country_lookup.resolveCountry(lat, lng)
    │
    │  GPS coordinates released from memory
    │  PHAsset.localIdentifier released from memory after batch completes
    ▼
CountryVisit { countryCode, firstSeen, lastSeen }
    │
    ▼
Local SQLite DB  ──►  Firestore (country code + dates only)
```

At no point after `resolveCountry()` returns do GPS coordinates or asset identifiers exist in memory, on disk, or in the network payload.

---

## Permissions

- **Photo library** — requested only when the user taps "Scan Photos". Never on launch.
- **Live location** — never requested. GPS comes from photo EXIF, not the device's current position.
- **Analytics** — opt-in only. No analytics in packages; only in app layers. Events are aggregate and non-identifiable.

---

## User Control

Users can, at any time:
- View every country visit recorded by the app.
- Edit or delete any visit.
- Delete their entire travel history (purges local DB and Firestore).
- Delete their account (purges all Firestore data immediately; local data cleared on next app launch).
- Revoke a sharing card (deletes the Firestore document; the public URL returns 404 immediately).

---

## Sharing Pages

Public travel card pages (`/share/[token]`):
- Contain only a list of country codes and aggregate statistics.
- Do not contain the user's name, profile photo, email, or Firebase UID.
- Are identified by an opaque token with ≥ 128 bits of entropy — not by user identity.
- Are crawlable but contain no PII.

---

## Firestore Security

Firestore security rules must enforce:
- Users can only read and write their own `users/{userId}` documents.
- `sharingCards/{token}` documents are publicly readable (no auth required) but only writable by the owning user.
- No rule grants cross-user data access.

Rules must be reviewed whenever the Firestore structure changes.

---

## Compliance Notes

- **GDPR:** data minimisation and right to erasure are satisfied by architecture. No separate deletion job needed beyond the account deletion flow.
- **App Store:** the photo library permission usage string must state that only location metadata (not images) is accessed.
- **Third-party SDKs:** `country_lookup` and `shared_models` have no third-party dependencies. Analytics and crash reporting SDKs live only in app layers.
