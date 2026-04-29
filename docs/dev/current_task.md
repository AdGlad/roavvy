# Active Task: M89 — Hero Image Detection & Trip Labels

Branch: milestone/m89-hero-image-detection

## Goal

Build the on-device hero image detection pipeline: candidate selection (metadata), Vision labelling (Swift, background), scoring, and Drift persistence. No UI changes. Scan performance unaffected.

## Status: Complete (2026-04-29)

## Tasks

- [x] T1 — HeroImage shared model (packages/shared_models/lib/src/hero_image.dart)
- [x] T2 — Drift schema v11: hero_images table (roavvy_database.dart + migration)
- [x] T3 — HeroCandidateSelector (lib/features/scan/hero_candidate_selector.dart)
- [x] T4 — LabelNormalizer (ios/Runner/LabelNormalizer.swift)
- [x] T5 — HeroImageAnalyzer (ios/Runner/HeroImageAnalyzer.swift)
- [x] T6 — HeroAnalysisMethodChannel bridge (hero_analysis_channel.dart + AppDelegate)
- [x] T7 — HeroScoringEngine (packages/shared_models/lib/src/hero_scoring_engine.dart)
- [x] T8 — HeroImageRepository (lib/features/scan/hero_image_repository.dart)
- [x] T9 — HeroAnalysisService + post-scan trigger (hero_analysis_service.dart + scan_screen.dart)
- [x] T10 — HeroCacheValidator (lib/features/scan/hero_cache_validator.dart)
- [x] T11 — heroForTripProvider (lib/features/scan/hero_providers.dart)
