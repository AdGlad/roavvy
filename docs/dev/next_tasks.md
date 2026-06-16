# M160 — Firestore Restore on Reinstall

## Tasks

- [x] T0 — Read existing repo/service patterns (visit_repository, trip_repository, achievement_repository, firestore_sync_service)
- [ ] T1 — Create `FirestoreRestoreService` (lib/data/firestore_restore_service.dart)
- [ ] T2 — Update main.dart: call restore before bootstrapExistingUser
- [ ] T3 — 5-second timeout built into restore() via Future.any (part of T1)
- [ ] T5 — Restored rows marked isDirty=0 (part of T1)
- [ ] T6 — flutter analyze passes

## Key decisions

- Service takes `RoavvyDatabase db` directly to write with isDirty=0 cleanly
- `shouldRestore` checks both inferred_visits AND photo_date_records are empty
- 5-second timeout via Future.any([_doRestore(), Future.delayed(5s)])
- Restore runs BEFORE bootstrapExistingUser so bootstrap can synthesise trips from restored data
- T4 (loading indicator) deferred — pre-runApp Flutter UI not possible without native splash integration
