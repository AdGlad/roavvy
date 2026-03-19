# Current Task — Task 50: Onboarding flow

**Milestone:** 18
**Phase:** 8 — Celebrations & Delight

## Why

First-time users open the app to an empty map with no guidance. Without onboarding, the scan permission prompt appears with no context and new users may deny it. Onboarding establishes the value proposition before asking for photo access.

## Acceptance criteria

- [ ] Three screens in sequence: Welcome, How It Works, Scan CTA
- [ ] Each screen has a title, body copy, illustration placeholder, and a primary `FilledButton` CTA
- [ ] "Skip" `TextButton` on all three screens; tapping immediately sets `hasSeenOnboarding = true` and navigates to Scan tab
- [ ] Final screen CTA sets `hasSeenOnboarding = true` and navigates to Scan tab
- [ ] `hasSeenOnboarding` persisted locally (Architect to specify mechanism — Drift or SharedPreferences)
- [ ] Onboarding is not shown on subsequent launches
- [ ] Onboarding is not shown if the user already has visits (returning user / reinstall)
- [ ] `dart analyze` reports zero issues
- [ ] 4+ widget tests: shown on first launch; not shown on subsequent; skip works; CTA navigates correctly

## Status: AWAITING UX DESIGNER → ARCHITECT → BUILDER

## Files to change

- `lib/features/onboarding/onboarding_flow.dart` — new
- `lib/data/db/roavvy_database.dart` — `hasSeenOnboarding` persistence (schema TBD by Architect)
- `lib/app.dart` — route to `OnboardingFlow` on first launch
- `test/features/onboarding/onboarding_flow_test.dart` — new

## Dependencies

None. Independent — build first in M18.
