# Offline Strategy

## Principle

The mobile app's core value — scanning photos, viewing the travel map, editing visits, checking achievements — must work with zero network access. Firestore is a sync target, not a dependency.

## Feature Availability

| Feature | Offline? | Notes |
|---|---|---|
| Photo scan | Yes | PhotoKit is local; `country_lookup` is bundled |
| Travel map | Yes | Rendered from local SQLite |
| Edit / delete visits | Yes | Writes locally; queued for sync |
| Achievements | Yes | Computed locally |
| Generate sharing card | Partial | Snapshot created locally; public URL live only after sync |
| Shop / merchandise | No | Shopify requires connectivity — clearly communicated in UI |

---

## Local DB as Source of Truth

```
Photo Scan ──────────────────────────────────► Local SQLite (Drift)
                                                     ▲
User Edits ──────────────────────────────────────────┘
                                                     │
                                          (when online, background)
                                                     │
                                               Firestore
```

All mutations write to SQLite first. The UI always reflects local state. Firestore is updated asynchronously.

---

## Sync Model

**Dirty flag.** Every `CountryVisit` row has `isDirty: bool`. The sync service flushes dirty records to Firestore when connectivity is detected.

**Conflict resolution — explicit precedence rules:**

1. `manual` source always beats `auto` source, regardless of `updatedAt`.
2. Among two records with the same source, the one with the later `updatedAt` wins.
3. These rules apply both during sync and during scan-time merging.

This means: once a user manually edits a visit, automatic re-scans will never overwrite it.

**Soft deletes.** Deleted visits are marked `isDeleted = true` locally and a tombstone document is written to Firestore on next sync. Hard deletion (removing the tombstone and local row) is triggered by a Cloud Function 30 days after `isDeleted` is set.

---

## Geodata Bundling

`country_lookup` bundles Natural Earth polygon data at build time as a Flutter asset. There is no runtime download, no CDN call, and no fallback network path. This is intentional — offline capability is unconditional, not best-effort.

**Trade-off:** geodata updates ship with app updates. Border changes or newly recognised countries require a new app release.

---

## Reconnection Behaviour

1. `connectivity_plus` notifies the sync service of connectivity.
2. Sync service reads all `isDirty = true` records from local DB.
3. Records are pushed to Firestore (upsert by `countryCode`).
4. Firestore changes from other devices are pulled and merged using the precedence rules above.
5. `isDirty` is cleared and `syncedAt` is updated on success.

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| First launch, no connectivity | App works fully; sync deferred until connected |
| Connectivity lost mid-scan | Scan continues; results saved locally; sync deferred |
| Connectivity lost mid-sync | Partial sync; remaining dirty records retried on next connection |
| Firestore error | Log silently; retry next sync cycle; never block the user |
| Schema version mismatch on pull | Discard incoming record; log warning; do not corrupt local data |
