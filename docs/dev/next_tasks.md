# M157 — Merch Pipeline Efficiency: Task List

## Phase 1 — Backend: Printful Webhook + Storage Cleanup

- [x] T1: Add `printfulMockupTaskId: number | null` to `MerchConfig` in `types.ts`
- [x] T2: Replace polling loop with `submitPrintfulMockupTask` (submit only, return taskId)
- [x] T3: Store taskId + set `mockupStatus=generating` in Firestore after submission
- [x] T4: Implement `printfulMockupWebhook` onRequest function
- [x] T5: Delete print files in `shopifyOrderCreated` after `print_file_submitted`
- [x] T6: Register `mockup_task_finished` webhook with Printful (dev) — URL: https://us-central1-roavvy-dev.cloudfunctions.net/printfulMockupWebhook

## Phase 2 — Drop Preview Upload

- [x] T7: Remove preview generation + upload from `createMerchCart`; remove `previewUrl` from types
- [x] T8: Remove `previewUrl` fallback in `merch_variant_screen.dart`, use local bytes

## Phase 3 — Image Processing on Phone

- [x] T9: Add `image: ^4.2.0` and `firebase_storage: ^12.3.0` to pubspec
- [x] T10: Implement `MerchImageProcessor` (on-device Sharp equivalent)
- [x] T11: Implement `MerchStorageUploader` (direct GCS upload)
- [x] T12: Add storage path fields to `CreateMerchCartRequest` in `types.ts`
- [x] T13: Update `createMerchCart` to accept paths, skip Sharp, use `clientConfigId`
- [x] T14: Update `local_mockup_preview_screen.dart` to process on device, upload, pass paths

## Notes

- Printful webhook secret stored in `apps/functions/.env` as `PRINTFUL_WEBHOOK_SECRET`
- Webhook `public_key`: `ApIEyWketnyY` (for display/identification)
- Prod deployment: repeat T6 curl against prod Printful store + prod function URL
