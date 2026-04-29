# M89 — Hero Image Detection & Trip Labels

**Branch:** `milestone/m89-hero-image-detection`
**Status:** In Progress

## Goal

Build an on-device pipeline that selects hero image candidates per trip during scan, labels them using iOS Vision framework post-scan in a background task, and persists structured label records in Drift schema v11. No photos leave the device. Scan performance unaffected.

## Scope

**In:**
- `packages/shared_models/lib/src/hero_image.dart` — `HeroImage`, `HeroLabels`, `HeroAnalysisResult` models
- `apps/mobile_flutter/lib/data/db/roavvy_database.dart` — schema v11 `HeroImages` table + migration
- `apps/mobile_flutter/lib/features/scan/hero_candidate_selector.dart` — metadata-only candidate picker
- `apps/mobile_flutter/ios/Runner/LabelNormalizer.swift` — ML label to Roavvy vocabulary
- `apps/mobile_flutter/ios/Runner/HeroImageAnalyzer.swift` — Vision framework analysis
- `apps/mobile_flutter/lib/features/scan/hero_analysis_channel.dart` — MethodChannel Dart wrapper
- `apps/mobile_flutter/ios/Runner/AppDelegate.swift` — register hero analysis channel
- `packages/shared_models/lib/src/hero_scoring_engine.dart` — composite score + ranking
- `apps/mobile_flutter/lib/features/scan/hero_image_repository.dart` — Drift DAO wrapper
- `apps/mobile_flutter/lib/features/scan/hero_analysis_service.dart` — orchestrates T3+T6+T7+T8
- `apps/mobile_flutter/lib/features/scan/hero_cache_validator.dart` — tombstone deleted assets
- `apps/mobile_flutter/lib/features/scan/hero_providers.dart` — Riverpod heroForTripProvider

**Out:** Any UI displaying hero images; Firestore sync; landmark detection; web; Android.

## Tasks

- [ ] T1 — HeroImage shared model
  - Files: packages/shared_models/lib/src/hero_image.dart, packages/shared_models/lib/shared_models.dart
  - Deliverable: HeroImage, HeroLabels, HeroAnalysisResult Dart classes with equality, copyWith, and JSON parsing from MethodChannel response.
  - Acceptance: Unit tests pass; exported from shared_models barrel.

- [ ] T2 — Drift schema v11: hero_images table
  - Files: apps/mobile_flutter/lib/data/db/roavvy_database.dart
  - Deliverable: HeroImages Drift table + migration v10 to v11 + DAO with upsertHero, getHeroForTrip, getHeroesForCountry, deleteHeroesForTrip, tombstone methods.
  - Acceptance: Migration runs on existing DB; DAO unit tests pass.

- [ ] T3 — HeroCandidateSelector (Dart)
  - File: apps/mobile_flutter/lib/features/scan/hero_candidate_selector.dart
  - Deliverable: Pure Dart. Input: List<PhotoDateRecord> for one trip. Output: List<String> assetIds (up to 5). Applies GPS-first selection, 60s burst dedup, 30-min temporal spacing, fallback (no GPS).
  - Acceptance: Unit tests for GPS-first, burst dedup, temporal spacing, fallback, single-photo trip.

- [ ] T4 — LabelNormalizer (Swift)
  - File: apps/mobile_flutter/ios/Runner/LabelNormalizer.swift
  - Deliverable: Static struct with lookup table mapping Vision identifier strings to Roavvy vocabulary. Returns [String: Any] dict with primaryScene, secondaryScene, activity, mood, subjects, landmark.
  - Acceptance: Covers all mappings in milestone doc. Unknown identifiers discarded.

- [ ] T5 — HeroImageAnalyzer (Swift)
  - File: apps/mobile_flutter/ios/Runner/HeroImageAnalyzer.swift
  - Deliverable: Accepts [String] assetIds. Fetches 200x200 thumbnails via PHImageManager (isNetworkAccessAllowed = false). Runs VNClassifyImageRequest. Calls LabelNormalizer. Applies quality score. Returns [[String: Any]].
  - Acceptance: No network access. Returns empty array gracefully for unavailable/iCloud assets. Does not block main thread.

- [ ] T6 — HeroAnalysisMethodChannel bridge
  - Files: apps/mobile_flutter/lib/features/scan/hero_analysis_channel.dart, apps/mobile_flutter/ios/Runner/AppDelegate.swift
  - Deliverable: MethodChannel("roavvy/hero_analysis") with method analyseHeroCandidates({tripId, assetIds}) returning List<Map>. Dart wrapper calls channel async. AppDelegate registers handler calling HeroImageAnalyzer.
  - Acceptance: Dart wrapper compiles; AppDelegate registers channel.

- [ ] T7 — HeroScoringEngine (Dart)
  - File: packages/shared_models/lib/src/hero_scoring_engine.dart
  - Deliverable: Pure Dart. Input: List<HeroAnalysisResult> for one trip. Applies scoring formula (quality 0-30, label 0-25, diversity 0-25, metadata 0-20). Returns ranked list with heroScore and rank.
  - Acceptance: Unit tests for score ordering, tie-breaking by labelConfidence.

- [ ] T8 — HeroImageRepository (Dart)
  - File: apps/mobile_flutter/lib/features/scan/hero_image_repository.dart
  - Deliverable: Wraps Drift DAO. upsertHeroesForTrip(tripId, List<HeroImage>) honours isUserSelected guard. watchHeroForTrip(tripId) stream.
  - Acceptance: Unit tests: upsert skips user-selected rows; tombstone on unavailable asset.

- [ ] T9 — HeroAnalysisService + post-scan trigger
  - Files: apps/mobile_flutter/lib/features/scan/hero_analysis_service.dart, apps/mobile_flutter/lib/features/scan/scan_screen.dart
  - Deliverable: Service orchestrates T3 to T6 to T7 to T8 per trip. Called from scan_screen.dart after ScanSummaryScreen is pushed (fire-and-forget). Runs on background isolate.
  - Acceptance: ScanSummaryScreen appears without waiting. Hero analysis does not run on main thread.

- [ ] T10 — HeroCacheValidator
  - File: apps/mobile_flutter/lib/features/scan/hero_cache_validator.dart
  - Deliverable: On app launch (max once per day), batch-check assetId values from hero_images via PHAsset.fetchAssets. Tombstone missing assets.
  - Acceptance: Unit test with mock unavailable assetId results in tombstoned row, not deletion.

- [ ] T11 — heroForTripProvider (Riverpod)
  - File: apps/mobile_flutter/lib/features/scan/hero_providers.dart
  - Deliverable: heroForTripProvider(String tripId) StreamProvider<HeroImage?> from repository. Emits updated state on upsert.
  - Acceptance: Provider compiles; emits null when no hero exists for trip.

## Risks

| Risk | Mitigation |
|---|---|
| Drift code-gen required after schema change | Run dart run build_runner build after T2 |
| VNDetectImageApertureScoreRequest iOS 16+ only | Gate with #available(iOS 16, *); fallback to dimension-only |
| PHAsset access requires Photos permission | Reuse existing permission infrastructure; analysis only runs post-scan |
| Background analysis may be interrupted | State is safe: upsert is idempotent; retry on next scan |
