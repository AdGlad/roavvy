# M160 — Firestore Restore on Reinstall

**Milestone:** M160 — Firestore Restore on Reinstall
**Status:** Complete (pending manual test + commit)

## Done
- T1: `FirestoreRestoreService` — 5 collections, 5-second timeout, isDirty=0
- T2/T3: `startupCompleteProvider` calls restore → bootstrap → flushDirty post-runApp
- T4: "Restoring your map…" shown after 2s in `_OnboardingGate` loading state
- T5: Restored rows marked isDirty=0 (not re-uploaded by flushDirty)
- flutter analyze — 0 new warnings

## Deferred
- T6 (unit tests): fake_cloud_firestore available; add in a follow-up
- T7 (integration test): add in a follow-up

## Manual test checklist
- [ ] Delete app → reinstall → sign in → map populated without re-scan
- [ ] Existing user (non-empty DB) → restore does NOT run (shouldRestore=false)
- [ ] Slow network → "Restoring your map…" appears after 2s
