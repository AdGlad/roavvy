# M89 — Hero Image Detection & Trip Labels

**Branch:** `milestone/m89-hero-image-detection`
**Phase:** 19 — Personalisation & Memory
**Status:** Not started

---

## 1. Milestone Name

**M89 — Hero Image Detection & Trip Labels**

---

## 2. Milestone Goal

During and after photo scanning, identify the single best representative image per trip, run on-device image labelling on a small number of shortlisted candidates, and persist a structured label record in local SQLite. Original photos never leave the device. Scan performance is unaffected.

---

## 3. Product Value

Hero images and labels are a foundational data layer that powers:

| Downstream feature | How M89 enables it |
|---|---|
| Memory Pulse | `"Bali sunset"` = country + mood label |
| Trip summary screen | Show hero image above trip stats |
| Country detail screen | Best photo per country as header |
| Share cards | Auto-selected background candidate |
| Travel journal | Rich visual entry per trip |
| Auto-titles | `"Island Escape"` from `island + beach` labels |
| Filtering | Show all "mountain" trips |
| Recap video | Hero frames per country in order |

None of these features are built in M89. M89 builds the data pipeline so they can be built incrementally.

---

## 4. Proposed Scan Pipeline

```
[PhotoScanPlugin — existing]
  Emits: {assetId, lat, lng, capturedAt} per photo
        |
        v
[Country/region detection — existing]
  Produces: PhotoDateRecord {assetId, countryCode, capturedAt, regionCode}
        |
        v
[Trip inference — existing]
  Produces: TripRecord {id, countryCode, startedOn, endedOn, photoCount}
        |
        v
[HeroCandidateSelector — NEW, Dart, runs during scan]
  Input: PhotoDateRecords grouped by tripId
  Output: up to 3 candidate assetIds per trip (metadata-only, fast)
  Stored: CandidateRecord in memory (not persisted yet)
        |
        v  [scan completes — UI shows results immediately]
        |
        v
[HeroImageAnalyzer — NEW, Swift, runs in background after scan]
  Input: candidate assetIds
  Steps:
    1. PHImageManager.requestImage → thumbnail (200×200 px, no original fetch)
    2. VNClassifyImageRequest → top labels (on-device, no network)
    3. LabelNormalizer → map ML labels to Roavvy vocabulary
    4. QualityScorer → sharpness + dimensions + GPS presence
    5. HeroScorer → composite score
    6. Select rank-1 hero per trip (+ rank 2-3 stored as candidates)
  Output: [HeroImageResult] passed back to Dart via MethodChannel
        |
        v
[HeroImageRepository — NEW, Dart/Drift]
  Upserts hero_images table (schema v11)
  Skips trips where isUserSelected = true
```

**Key constraint:** scan result screen appears before hero analysis starts. Hero analysis is a background post-scan enrichment step, not a blocker.

---

## 5. Candidate Selection Logic

Candidates are selected using metadata only — no ML, no image loading at this stage.

**Eligibility rules (applied per trip, in priority order):**

| Rule | Rationale |
|---|---|
| Photo has GPS coordinates | Confirms the location; higher quality signal |
| `capturedAt` is the earliest in the trip | Often the arrival moment — high contextual value |
| Image dimensions ≥ 1080px on shorter axis | Weeds out thumbnails and screenshots |
| Photo is not within 60 seconds of a duplicate assetId | Avoids burst-mode clusters |
| Photo is spaced ≥ 30 minutes from the previous candidate | Ensures temporal diversity |

**Selection cap:** max 5 candidates per trip. Passed to Swift for label analysis.

**Fallback:** if no GPS-tagged photos exist in the trip, relax constraints and take the first 3 photos by timestamp.

---

## 6. Image Labelling Approach

**Framework:** `Vision.framework` — `VNClassifyImageRequest`
- Available since iOS 13
- On-device Core ML model (no network)
- Returns `[VNClassificationObservation]` with `identifier` (WordNet label) and `confidence` (0–1)

**Input:** 200×200 px thumbnail (`PHImageRequestOptions.deliveryMode = .fastFormat`)
- Avoids downloading iCloud originals
- Sufficient resolution for scene classification

**Confidence threshold:** only observations with `confidence >= 0.35` are considered.

**Label normalization:** raw ML identifiers are mapped to Roavvy vocabulary before crossing the MethodChannel (see Section 7 for scoring, normalization map below).

**Label normalization map (ML identifier → Roavvy label):**

```
// Primary scene
"seashore", "beach", "coast", "shore"        → beach
"cityscape", "street", "downtown"            → city
"mountain", "alp", "peak", "cliff"           → mountain
"island"                                     → island
"desert", "sand dune"                        → desert
"forest", "jungle", "woodland"               → forest
"snowfield", "glacier", "ski slope"          → snow
"lake", "pond", "reservoir"                  → lake
"countryside", "farmland", "pasture"         → countryside

// Mood
"sunset", "dusk"                             → sunset
"sunrise", "dawn"                            → sunrise
"golden hour"                                → golden_hour
"night", "nighttime"                         → night

// Subject
"person", "people", "crowd"                  → people
"group", "party"                             → group
"selfie", "portrait"                         → selfie
"landmark", "monument"                       → landmark
"architecture", "building", "church"         → architecture
"food", "meal", "restaurant"                 → food

// Activity
"hiking", "trekking"                         → hiking
"skiing", "snowboarding"                     → skiing
"boat", "ship", "yacht"                      → boat
"road", "highway"                            → roadtrip
```

**What is NOT stored:** sky, outdoor, blue, cloud, vacation, travel, horizon, water (generic/noisy — no UX value).

**Structured output per image:**

```dart
class HeroLabels {
  final String?       primaryScene;    // e.g. "beach"
  final String?       secondaryScene;  // e.g. "coast"
  final List<String>  activity;        // e.g. ["boat"]
  final List<String>  mood;            // e.g. ["sunset", "golden_hour"]
  final List<String>  subjects;        // e.g. ["people"]
  final String?       landmark;        // e.g. "eiffel_tower" (future)
  final double        confidence;      // highest raw confidence observed
}
```

**Label count target:** 3–6 labels per image. Never dump raw ML output.

---

## 7. Hero Image Scoring Model

```
HeroScore =
    qualityScore   (0–30)
  + labelScore     (0–25)
  + diversityScore (0–25)
  + metadataScore  (0–20)
```

**qualityScore** — based on image properties:
- `pixelWidth >= 2000`: +15
- `pixelWidth >= 1080`: +10
- `pixelWidth < 1080`: +0
- Sharpness via `VNDetectImageApertureScoreRequest` (iOS 16+), or estimated from EXIF blur:
  - `apertureScore >= 0.6`: +15 | `>= 0.4`: +10 | `>= 0.2`: +5

**labelScore** — based on label content:
- Has `landmark`: +12
- Has `sunset` or `golden_hour` mood: +10
- Has `people` or `group` subject: +7
- Has a primary scene (any): +6
- Each additional label (mood/activity): +2 each, max +5

**diversityScore** — within the trip's candidate set:
- Photo timestamp is in the first 25% of trip: +10
- Photo timestamp is in a different day than other candidates: +8
- Photo's GPS location differs from others by > 5 km: +7

**metadataScore**:
- Has GPS coordinates: +15
- `capturedAt` is not within 60 s of another photo: +5

**Tie-breaking:** if two photos have equal score, prefer the one with higher `confidence` from the label model.

---

## 8. Data Model

### Dart model (`packages/shared_models`)

```dart
class HeroImage {
  const HeroImage({
    required this.id,
    required this.assetId,
    required this.tripId,
    required this.countryCode,
    required this.capturedAt,
    required this.heroScore,
    required this.rank,
    required this.isUserSelected,
    this.primaryScene,
    this.secondaryScene,
    this.activity = const [],
    this.mood = const [],
    this.subjects = const [],
    this.landmark,
    this.labelConfidence = 0.0,
    this.qualityScore = 0.0,
    this.thumbnailLocalPath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `"hero_{tripId}"` for rank-1; `"hero_{tripId}_2"` / `"_3"` for candidates.
  final String id;
  final String assetId;           // PHAsset.localIdentifier — never leaves device
  final String tripId;
  final String countryCode;
  final DateTime capturedAt;
  final double heroScore;
  final int rank;                 // 1 = selected hero, 2-3 = candidates
  final bool isUserSelected;      // true = never auto-replaced

  // Labels (all nullable — labelling may not have run yet)
  final String? primaryScene;
  final String? secondaryScene;
  final List<String> activity;
  final List<String> mood;
  final List<String> subjects;
  final String? landmark;
  final double labelConfidence;

  // Quality
  final double qualityScore;

  // Local only — device-specific cache path; never synced to Firestore
  final String? thumbnailLocalPath;

  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### JSON wire format (for MethodChannel Swift → Dart)

```json
{
  "assetId": "E7E2F912-...",
  "capturedAt": "2024-07-12T10:30:00Z",
  "primaryScene": "beach",
  "secondaryScene": "coast",
  "activity": ["boat"],
  "mood": ["sunset"],
  "subjects": ["people"],
  "landmark": null,
  "labelConfidence": 0.82,
  "qualityScore": 0.71,
  "pixelWidth": 4032,
  "pixelHeight": 3024,
  "hasGps": true
}
```

---

## 9. Local Storage and Firestore Strategy

### Local — Drift SQLite (schema v11)

New table: `hero_images`

```sql
CREATE TABLE hero_images (
  id                 TEXT PRIMARY KEY,
  asset_id           TEXT NOT NULL,
  trip_id            TEXT NOT NULL,
  country_code       TEXT NOT NULL,
  captured_at        INTEGER NOT NULL,        -- ms since epoch UTC
  primary_scene      TEXT,
  secondary_scene    TEXT,
  activity           TEXT,                    -- JSON array e.g. '["boat"]'
  mood               TEXT,                    -- JSON array
  subjects           TEXT,                    -- JSON array
  landmark           TEXT,
  label_confidence   REAL NOT NULL DEFAULT 0,
  quality_score      REAL NOT NULL DEFAULT 0,
  hero_score         REAL NOT NULL DEFAULT 0,
  rank               INTEGER NOT NULL DEFAULT 1,
  is_user_selected   INTEGER NOT NULL DEFAULT 0,  -- bool
  thumbnail_local_path TEXT,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL
);

CREATE INDEX idx_hero_trip    ON hero_images(trip_id);
CREATE INDEX idx_hero_country ON hero_images(country_code);
```

**Upsert strategy on re-scan:**
- If `isUserSelected = true`: skip entirely — never overwrite user choice
- Otherwise: upsert on `id` — update `heroScore`, `rank`, labels, `updatedAt`

**Cache invalidation:**
- On app launch, check `PHAsset.fetchAssets(withLocalIdentifiers: [assetId])` — if empty, tombstone the row (`rank = -1`, `thumbnailLocalPath = null`)

### Firestore (optional, deferred to M89-ext)

Store only if user is signed in. Sync a lightweight record under `users/{uid}/heroImages/{id}`:

```
{
  tripId, countryCode, capturedAt,
  primaryScene, mood (first entry), heroScore, rank, isUserSelected
}
```

**Never sync:** `assetId`, `thumbnailLocalPath`, `activity`, `subjects` (more granular — kept local only for privacy).

**Schema rule:** `assetId` is a device-local PHAsset identifier. It MUST NOT appear in Firestore (ADR-002).

**Decision for M89:** Firestore sync is OUT OF SCOPE. Local storage only. Sync added in a later milestone when hero images are surfaced in UI.

---

## 10. UX Behaviour

### During scan
- No change to current scan UX. Country detection, trip grouping, and scan summary are unaffected.
- Hero candidate selection (metadata-only, fast) runs inside the existing scan stream — no blocking.
- No hero images are shown on the scan results screen.

### After scan completes
- Hero image analysis (Vision labelling) starts in the background, silently.
- No spinner or progress indicator — user is browsing scan results while analysis runs.
- When labelling completes, a `heroImagesProvider` in Riverpod emits updated state. Screens that display hero images (future milestones) will reactively update.

### Trip detail / Country detail screen (future milestone)
- Hero image shown as the card header image.
- Small edit icon (pencil) bottom-right of the hero image area.
- Tapping edit opens a horizontal scroll of top-3 candidates; user taps to select.
- Selected image sets `isUserSelected = true`.

### Progressive disclosure
```
scan completes → basic trip list shown immediately
                        ↓  (background, seconds later)
               hero images analysed and stored
                        ↓  (reactive)
               trip cards update with hero image header
```

---

## 11. User Override Rules

| Action | Behaviour |
|---|---|
| User taps a different candidate | Sets `isUserSelected = true`, `rank = 1` on new choice; old rank-1 becomes `rank = 2` |
| User taps "Remove" on hero image | Sets `rank = -1` (tombstone); `isUserSelected = true` so re-scan won't restore it |
| User taps "Reset to auto" | Sets `isUserSelected = false`; next scan re-evaluates |
| Re-scan runs, `isUserSelected = true` | Row is never touched — user choice wins permanently |
| Re-scan runs, `isUserSelected = false` | Upsert recalculates score; may change hero image |

**Hard rule:** if `isUserSelected = true`, neither a scan nor any background analysis may overwrite the record.

---

## 12. Performance Strategy

| Concern | Mitigation |
|---|---|
| Labelling all 50,000 photos | Only shortlisted candidates (≤ 5 per trip) are ever labelled |
| Re-analysing already-labelled photos | `hero_images` rows with `updatedAt` within the same scan session are skipped |
| Blocking the scan result screen | Hero analysis runs after `ScanSummaryScreen` is pushed; never on the main thread |
| iCloud photos not downloaded | `PHImageRequestOptions.isNetworkAccessAllowed = false`; if fetch fails, skip candidate gracefully |
| Large libraries (10,000+ trips) | Candidate selection is O(n) metadata pass; labelling is capped at 5 × trip_count requests |
| Thumbnail cache size | Max 200×200 px thumbnails; max 50 cached thumbnails per session; evict oldest on overflow |
| Repeated scans | Re-scan upserts, not inserts; no duplicate rows accumulate |

---

## 13. Risks and Edge Cases

| Risk / Edge Case | Handling |
|---|---|
| `assetId` refers to a deleted photo | `PHAsset.fetchAssets` returns empty → tombstone row (`rank = -1`) |
| iCloud asset not downloaded | `isNetworkAccessAllowed = false` → image fetch returns nil → skip candidate, log warning |
| No geotagged photos in a trip | Relax GPS rule; select first 3 photos by timestamp |
| All photos are near-duplicates (burst mode) | 60-second dedup rule reduces burst to single candidate |
| `VNClassifyImageRequest` returns nothing above threshold | Store `primaryScene = null`; score is metadata-only |
| iOS < 16 (no `VNDetectImageApertureScoreRequest`) | Fall back to dimension-only quality score |
| Permission revoked mid-analysis | Analysis is cancelled; existing rows are not cleared |
| Thumbnail write fails (low disk space) | Store labels and score; `thumbnailLocalPath = null`; app still functional |
| Trip deleted by user | Cascade delete: `hero_images` rows for that `trip_id` are removed |
| User changes iOS locale/timezone | `capturedAt` stored as UTC; unaffected |
| Multiple quick rescans | Second scan deduplicates on `assetId`; `isUserSelected` rows are not modified |
| VNClassifyImageRequest model accuracy | Normalization map maps noisy outputs to product vocabulary; unknown identifiers are discarded |

---

## 14. Acceptance Criteria

- [ ] Each inferred trip with ≥ 1 photo has at most 1 `rank = 1` hero image row in `hero_images`
- [ ] Up to 3 candidate rows (`rank` 1/2/3) are stored per trip
- [ ] Labels stored are from the Roavvy vocabulary — no raw ML identifiers in the DB
- [ ] Original photo bytes are never stored, uploaded, or retained
- [ ] Scan speed (time from start → `ScanSummaryScreen`) is not measurably affected by M89
- [ ] Image labelling does not run on the main thread
- [ ] `VNClassifyImageRequest` is called for ≤ 5 candidates per trip; never for every photo
- [ ] If `isUserSelected = true`, a re-scan does not modify the row
- [ ] A deleted/unavailable `assetId` results in a tombstoned row, not a crash
- [ ] iCloud-only photos are skipped gracefully without blocking analysis of other candidates
- [ ] `thumbnailLocalPath` is absent from any Firestore writes
- [ ] `assetId` is absent from any Firestore writes
- [ ] `flutter analyze` remains clean

---

## 15. Implementation Tasks

### T1 — `HeroImage` shared model + `HeroLabels`
**Files:** `packages/shared_models/lib/src/hero_image.dart`, `packages/shared_models/lib/shared_models.dart`
**Deliverable:** `HeroImage` and `HeroLabels` Dart classes with equality, `copyWith`, and JSON serialization for the MethodChannel response.
**Acceptance:** Unit tests pass; `flutter analyze` clean.

---

### T2 — Drift schema v11: `hero_images` table
**Files:** `lib/data/app_database.dart` (or equivalent Drift db file)
**Deliverable:** `HeroImages` table with all fields listed in Section 9. Drift `DataAccessObject` with `upsertHero`, `getHeroForTrip`, `getHeroesForCountry`, `deleteHeroesForTrip`, `tombstone` methods. Schema migration v10 → v11.
**Acceptance:** Migration runs without error on existing test DB; DAO unit tests pass.

---

### T3 — `HeroCandidateSelector` (Dart)
**Files:** `lib/features/scan/hero_candidate_selector.dart`
**Deliverable:** Pure Dart class. Input: `List<PhotoDateRecord>` for one trip. Output: `List<String> assetIds` (up to 5 candidates). Applies metadata rules from Section 5 in order.
**Acceptance:** Unit tests for: GPS-first selection, burst dedup, temporal spacing, fallback (no GPS), trips with 1 photo.

---

### T4 — `HeroImageAnalyzer` (Swift)
**Files:** `ios/Runner/HeroImageAnalyzer.swift`
**Deliverable:** Swift class that accepts `[String]` (assetIds), fetches 200×200 thumbnails via `PHImageManager`, runs `VNClassifyImageRequest` on each, applies `LabelNormalizer`, calls `QualityScorer`, and returns `[[String: Any]]` JSON-compatible result.
**Acceptance:** Does not access the network. `isNetworkAccessAllowed = false`. Returns empty array gracefully for unavailable assets.

---

### T5 — `LabelNormalizer` (Swift)
**Files:** `ios/Runner/LabelNormalizer.swift`
**Deliverable:** Static lookup table mapping Vision `identifier` strings → Roavvy label vocabulary. Returns structured `HeroLabels` dict.
**Acceptance:** Unit tests cover all mappings in Section 6. Unknown identifiers are discarded.

---

### T6 — `HeroAnalysisMethodChannel` bridge
**Files:** `ios/Runner/AppDelegate.swift` (or plugin registration), new `hero_analysis_channel.dart`
**Deliverable:** `MethodChannel("roavvy/hero_analysis")` with single method `analyseHeroCandidates(tripId, assetIds)` → returns `List<Map>` of `HeroImageResult`. Dart wrapper invokes T4 asynchronously via `Isolate` or `compute`.
**Acceptance:** Integration test with mock asset IDs.

---

### T7 — `HeroScoringEngine` (Dart)
**Files:** `packages/shared_models/lib/src/hero_scoring_engine.dart`
**Deliverable:** Pure Dart class. Input: `List<HeroAnalysisResult>` for one trip. Applies scoring formula from Section 7. Returns ranked list with `heroScore` and `rank` assigned.
**Acceptance:** Unit tests for score ordering; tests for tie-breaking by `labelConfidence`.

---

### T8 — `HeroImageRepository` (Dart)
**Files:** `lib/features/scan/hero_image_repository.dart`
**Deliverable:** Repository wrapping the Drift DAO. Key method: `upsertHeroesForTrip(tripId, List<HeroImage>)` — honours `isUserSelected` guard. Provides `watchHeroForTrip(tripId)` stream.
**Acceptance:** Unit tests for: upsert skips user-selected rows; tombstone on unavailable asset.

---

### T9 — Post-scan background analysis trigger
**Files:** `lib/features/scan/scan_screen.dart` (or scan completion handler)
**Deliverable:** After `ScanSummaryScreen` is pushed, fire `HeroAnalysisService.runForTrips(trips)` in an isolate/background task. Service: selects candidates (T3) → invokes MethodChannel (T6) per trip → scores results (T7) → upserts (T8).
**Acceptance:** Scan summary appears without waiting for hero analysis. Hero analysis does not run on main thread. If app is backgrounded during analysis, task completes or resumes on next foreground.

---

### T10 — Cache validation on app launch
**Files:** `lib/features/scan/hero_cache_validator.dart`
**Deliverable:** On cold start (or once per day), fetch all `assetId` values from `hero_images` where `rank >= 0`. Batch-check existence via `PHAsset.fetchAssets`. Tombstone any missing assets.
**Acceptance:** Test with mock unavailable assetId → row is tombstoned, not deleted.

---

### T11 — `heroImagesProvider` (Riverpod)
**Files:** `lib/core/providers.dart` (or `lib/features/scan/hero_providers.dart`)
**Deliverable:** `heroForTripProvider(tripId)` — streams `HeroImage?` from the repository. Used by future trip/country detail screens.
**Acceptance:** Provider emits updated state when repository upserts.

---

## 16. Recommended Build Order

```
T1  HeroImage + HeroLabels model          (foundation for everything)
T2  Drift schema v11                      (required by repository)
T3  HeroCandidateSelector                 (pure Dart, testable in isolation)
T5  LabelNormalizer (Swift)               (dependency of T4)
T4  HeroImageAnalyzer (Swift)             (depends on T5)
T6  MethodChannel bridge                  (wires T4 to Dart)
T7  HeroScoringEngine                     (pure Dart, testable)
T8  HeroImageRepository                   (depends on T2)
T9  Post-scan trigger                     (integrates T3, T6, T7, T8)
T10 Cache validator                       (standalone, add last)
T11 Riverpod provider                     (final wiring, enables future UI)
```

**Parallelisable:**
- T1 + T5 can start in parallel (Dart model vs Swift normalizer)
- T3 + T7 are pure Dart and can be written and tested before any Swift or DB work
- T4 can be written alongside T2

---

## ADR

**ADR-134 — M89 On-Device Hero Image Detection Pipeline**

Hero image selection and labelling runs entirely on-device using iOS Vision framework (`VNClassifyImageRequest`). Only metadata is persisted — never photo bytes. The analysis pipeline is asynchronous and post-scan: country detection is never blocked. Raw ML labels are normalized to a fixed Roavvy vocabulary before storage. `assetId` (PHAsset local identifier) is stored in Drift only; it is excluded from all Firestore writes (extends ADR-002). User-selected hero images are protected from automatic re-scoring via `isUserSelected` flag. Firestore sync of hero metadata is deferred to a later milestone.

---

## Scope

**In:**
- `packages/shared_models` — `HeroImage`, `HeroLabels`, `HeroScoringEngine`
- `apps/mobile_flutter/lib/data/` — Drift schema v11 migration + `hero_images` DAO
- `apps/mobile_flutter/lib/features/scan/` — `HeroCandidateSelector`, `HeroAnalysisService`, `HeroImageRepository`, `HeroCacheValidator`, `hero_providers.dart`
- `apps/mobile_flutter/ios/Runner/` — `HeroImageAnalyzer.swift`, `LabelNormalizer.swift`, MethodChannel registration

**Out:**
- Any UI that displays hero images (separate milestone)
- Firestore sync of hero data
- Landmark detection (deferred — requires larger model or structured data lookup)
- Web app
- Android (iOS-first)
- Sound effects, animations
