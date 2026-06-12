# M157 — Merch Pipeline Efficiency

## Goal

Reduce cloud function cost, storage footprint, and improve stability of the merch
purchase flow through four targeted changes:

1. **Printful mockup webhook** — replace polling loop with event-driven callback
2. **Temp file deletion** — delete Firebase Storage files once consumed
3. **Drop preview upload** — remove redundant server-side preview generation
4. **Image processing on phone** — move Sharp workload to the device; function becomes lightweight

---

## Background

### Current flow (pre-M157)

```
Phone (base64 blobs)
  → createMerchCart (2 GiB, 300 s)
      Sharp resize + composite
      4× GCS uploads (preview, front print, back print, mockup)
      Signed URL generation
      Shopify cart creation
      Printful mockup task submit
      Polling loop (50× 3 s = up to 150 s background, void)
  → returns checkoutUrl
  → client Firestore listener waits for mockupStatus=ready
```

### Post-M157 flow

```
Phone
  image processing (resize, composite) — on device
  3× GCS uploads (front print, back print, mockup) — direct from phone
  → createMerchCart (256 MB, 60 s)
      Signed URL generation from storage paths
      Shopify cart creation
      Printful mockup task submit → store taskId → return
  → client Firestore listener waits for mockupStatus=ready

Printful → printfulMockupWebhook
      Write frontMockupUrl to Firestore
      Delete mockup GCS file

shopifyOrderCreated
      Submit to Printful (existing)
      Delete print GCS files after print_file_submitted
```

---

## Phase 1 — Printful Webhook + Storage Cleanup (backend only)

No Flutter changes. Deployable independently.

### T1 — Add `printfulMockupTaskId` to MerchConfig type

**File:** `apps/functions/src/types.ts`

Add field to `MerchConfig` interface:

```typescript
/**
 * Printful v2 mockup task ID returned by POST /v2/mockup-tasks.
 * Stored so the printfulMockupWebhook can look up the config by task ID.
 * Null for poster products or pre-M157 configs.
 */
printfulMockupTaskId: number | null;
```

### T2 — Convert `generatePrintfulMockup` from polling to task-submit only

**File:** `apps/functions/src/index.ts`

Replace `generatePrintfulMockup` signature and body:

- **Before:** submits task, polls 50× at 3 s intervals, returns `{ frontMockupUrl, backMockupUrl }`
- **After:** submits task, returns `{ taskId }` immediately — no polling loop

New signature:

```typescript
async function submitPrintfulMockupTask(
  printfulVariantId: number,
  frontMockupFileUrl: string | null,
  backPrintFileUrl: string | null,
  frontPosition: string,
): Promise<{ taskId: number | null }>
```

Remove all polling code (`maxAttempts`, `intervalMs`, the `for` loop).

### T3 — Store taskId in MerchConfig after task submission

**File:** `apps/functions/src/index.ts`
**Location:** Step 5 in `createMerchCart`, where mockup generation is triggered

After `submitPrintfulMockupTask` returns, write `printfulMockupTaskId` to Firestore:

```typescript
await configRef.update({
  mockupStatus: 'generating',
  printfulMockupTaskId: taskId,   // ADD
  updatedAt: Timestamp.now(),
});
```

Remove the `void generatePrintfulMockup(...).then(...).catch(...)` pattern — the
webhook handler takes over the result writing.

### T4 — Implement `printfulMockupWebhook` cloud function

**File:** `apps/functions/src/index.ts`

New `onRequest` export (public invoker, same pattern as `shopifyOrderCreated`):

```typescript
export const printfulMockupWebhook = onRequest(
  { invoker: 'public' },
  async (req, res) => { ... }
);
```

Handler logic:
1. Accept POST only; return 200 for all other methods (Printful retries on non-200).
2. Parse body — expect `{ type: 'mockup_task_finished', data: MockupGeneratorTask }`.
3. Extract `data.id` (taskId) and `data.status`.
4. Query `merch_configs` collectionGroup where `printfulMockupTaskId == taskId`, limit 1.
5. If not found: log warning, return 200.
6. Extract `frontMockupUrl` from `data.catalog_variant_mockups[0].mockups[0].mockup_url`
   (same traversal as current polling parser).
7. Write to Firestore:
   ```typescript
   mockupStatus: data.status === 'completed' ? 'ready' : 'failed',
   frontMockupUrl: frontMockupUrl ?? null,
   backMockupUrl: null,   // style 24458 is a collage — single URL
   updatedAt: Timestamp.now(),
   ```
8. If `frontMockupUrl` is non-null, delete the `mockup_files/{configId}.png` GCS object.
9. Return 200.

Security note: Printful v2 webhooks do not provide HMAC signatures. The Firestore
lookup by `printfulMockupTaskId` is the verification — an unknown task ID finds no
config and is silently dropped. The handler is fully idempotent.

### T5 — Delete print files in `shopifyOrderCreated` after submission

**File:** `apps/functions/src/index.ts`
**Location:** After successful Printful order creation (`designStatus=print_file_submitted`)

```typescript
// Delete print files from GCS — Printful has downloaded them.
void Promise.all([
  config.frontPrintFileStoragePath
    ? bucket.file(config.frontPrintFileStoragePath).delete().catch(() => {})
    : Promise.resolve(),
  config.backPrintFileStoragePath
    ? bucket.file(config.backPrintFileStoragePath).delete().catch(() => {})
    : Promise.resolve(),
]);
```

Use `.catch(() => {})` — deletion failure must never affect the webhook response.

### T6 — Register `mockup_task_finished` webhook with Printful

One-time setup step (not code — document as a deployment instruction):

```bash
curl -X POST https://api.printful.com/v2/webhooks/mockup_task_finished \
  -H "Authorization: Bearer $PRINTFUL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"mockup_task_finished","url":"https://<region>-<project>.cloudfunctions.net/printfulMockupWebhook"}'
```

Document the deployed URL in `.env` or project secrets as `PRINTFUL_WEBHOOK_URL`.

---

## Phase 2 — Drop Preview Upload

### T7 — Remove preview generation from `createMerchCart`

**File:** `apps/functions/src/index.ts`

- Remove the `previewJpeg` generation (Sharp resize to 800×600 JPEG).
- Remove the `previews/{configId}.jpg` GCS upload from the `Promise.all`.
- Remove `previewUrl` from the returned response — set to empty string or remove field.
- Remove `previewStoragePath` Firestore write.
- Update `CreateMerchCartResponse` in `types.ts` — remove `previewUrl` field.

### T8 — Remove `previewUrl` usage from Flutter

**File:** `apps/mobile_flutter/lib/features/merch/merch_variant_screen.dart`

`merch_variant_screen.dart:450` uses `_mockupUrl ?? _previewUrl` to display an image
after cart creation. Replace `_previewUrl` fallback with the local artwork bytes the
phone already holds at this point in the flow (passed as constructor param or held in
state). The local bytes are the same source the server was generating the preview from.

Remove `_previewUrl` state field and all references to `previewUrl` from the function
response parsing.

---

## Phase 3 — Image Processing on Phone

### T9 — Add Flutter packages

**File:** `apps/mobile_flutter/pubspec.yaml`

```yaml
dependencies:
  image: ^4.2.0            # pure-Dart image processing (resize, composite, PNG/JPEG)
  firebase_storage: ^12.3.0  # direct GCS upload from device
```

Run `flutter pub get`.

### T10 — Implement on-device image processor

**New file:** `apps/mobile_flutter/lib/features/merch/merch_image_processor.dart`

Pure Dart class `MerchImageProcessor` with static methods mirroring the Sharp logic
currently in the cloud function:

```dart
class MerchImageProcessor {
  /// Resizes [inputBytes] (PNG) to the print canvas dimensions for the given
  /// [variantId], returning { printBuf, mockupBuf }.
  /// Replicates the Sharp front-image logic in createMerchCart.
  static Future<MerchProcessedImages> processFront({
    required Uint8List inputBytes,
    required String frontPosition,
    required MerchPrintDimensions dims,
  });

  /// Resizes [inputBytes] (PNG) to the print canvas dimensions.
  /// Replicates the Sharp back-image logic in createMerchCart.
  static Future<Uint8List> processBack({
    required Uint8List inputBytes,
    required MerchPrintDimensions dims,
  });
}

class MerchProcessedImages {
  final Uint8List printBuf;    // composited print file (for ordering)
  final Uint8List mockupBuf;   // raw design for Printful v2 mockup API
}
```

Print dimensions (`MerchPrintDimensions`) mirror `PRINT_DIMENSIONS` from
`printDimensions.ts` — define as a Dart class or const map keyed by variantId.

Chest position compositing must match the pixel-level logic in the cloud function
(same percentage-based offsets).

### T11 — Implement direct Firebase Storage uploader

**New file:** `apps/mobile_flutter/lib/features/merch/merch_storage_uploader.dart`

```dart
class MerchStorageUploader {
  /// Uploads [bytes] to [storagePath] and returns the GCS path.
  /// Throws on upload failure.
  static Future<String> upload({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
  });
}
```

Uses `firebase_storage` package: `FirebaseStorage.instance.ref(storagePath).putData(bytes)`.

Storage paths (same as current):
- Front print: `front_print_files/{configId}.png`
- Back print: `back_print_files/{configId}.png`
- Mockup: `mockup_files/{configId}.png`

`configId` at this stage is a client-generated UUID (generate with `uuid` package or
`DateTime.now().microsecondsSinceEpoch` as hex). The cloud function will use the same
ID for its Firestore doc — pass it as part of the request.

### T12 — Update `createMerchCart` function to accept storage paths

**File:** `apps/functions/src/types.ts`

Add new fields to `CreateMerchCartRequest`:

```typescript
/** GCS path of the front print PNG uploaded by the phone. Replaces frontImageBase64. */
frontPrintStoragePath?: string;
/** GCS path of the back print PNG uploaded by the phone. Replaces backImageBase64. */
backPrintStoragePath?: string;
/** GCS path of the mockup PNG uploaded by the phone for Printful v2 mockup API. */
mockupStoragePath?: string;
/** Client-generated config ID — used as the Firestore doc ID. */
clientConfigId?: string;
```

Keep `frontImageBase64` / `backImageBase64` in the interface as optional for backwards
compatibility during transition. The function checks: if storage paths present, use
them; otherwise fall back to base64 processing (allows old clients to continue working
during rollout).

### T13 — Update `createMerchCart` function body

**File:** `apps/functions/src/index.ts`

When `frontPrintStoragePath` / `backPrintStoragePath` are present:
- Skip all Sharp processing.
- Skip all GCS uploads (already done by phone).
- Generate signed URLs from the provided storage paths directly.
- Proceed with Shopify cart creation and Printful task submission as before.

Use `clientConfigId` as the Firestore doc ID when provided (so the phone knows the
config ID before the function returns, enabling the Firestore listener to attach
immediately).

Reduce function memory: `{ timeoutSeconds: 60, memory: '256MiB' }`.

Remove Sharp import and all image processing code once base64 path is retired.

### T14 — Update Flutter call site

**File:** `apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart`

In `_onApprove` / cart creation flow:

1. Generate `clientConfigId` (UUID).
2. Process images on device using `MerchImageProcessor`.
3. Upload to GCS using `MerchStorageUploader` with paths keyed to `clientConfigId`.
4. Call `createMerchCart` with storage paths + `clientConfigId` instead of base64 blobs.
5. Attach Firestore listener to `merch_configs/{clientConfigId}` immediately (no need
   to wait for function to return the config ID).

---

## Type / Schema Changes

| Field | Change |
|---|---|
| `MerchConfig.printfulMockupTaskId` | ADD — `number \| null` |
| `MerchConfig.previewStoragePath` | DEPRECATE — leave nullable, stop writing |
| `CreateMerchCartRequest.frontPrintStoragePath` | ADD — optional |
| `CreateMerchCartRequest.backPrintStoragePath` | ADD — optional |
| `CreateMerchCartRequest.mockupStoragePath` | ADD — optional |
| `CreateMerchCartRequest.clientConfigId` | ADD — optional |
| `CreateMerchCartResponse.previewUrl` | REMOVE |

All schema changes are additive or nullable — no migration required.

---

## File Map

```
apps/functions/src/
  types.ts                          EDIT — MerchConfig + request/response types
  index.ts                          EDIT — webhook, polling removal, deletion, paths

apps/mobile_flutter/
  pubspec.yaml                      EDIT — add image, firebase_storage
  lib/features/merch/
    merch_image_processor.dart      NEW  — on-device Sharp equivalent
    merch_storage_uploader.dart     NEW  — direct GCS upload
    local_mockup_preview_screen.dart EDIT — use processor + uploader, pass paths
    merch_variant_screen.dart        EDIT — remove previewUrl fallback
```

---

## Deployment Order

1. Deploy Phase 1 (backend only) — webhook live, polling removed, file deletion active.
2. Register Printful webhook (T6) immediately after Phase 1 deploy.
3. Deploy Phase 2 (backend + Flutter) — preview upload gone.
4. Deploy Phase 3 (Flutter + backend) — image processing on phone.

Phase 1 and 2 can be deployed without a Flutter release. Phase 3 requires a coordinated
app + function deploy (backwards-compatible: function still accepts base64 during rollout).

---

## Definition of Done

- [ ] `printfulMockupWebhook` receives Printful callbacks and writes `frontMockupUrl` to Firestore.
- [ ] Polling loop removed from `generatePrintfulMockup`.
- [ ] `printfulMockupTaskId` stored in `MerchConfig` after task submission.
- [ ] `mockup_files/{configId}.png` deleted after webhook fires.
- [ ] `front_print_files` / `back_print_files` deleted after `print_file_submitted`.
- [ ] Preview upload removed from `createMerchCart`.
- [ ] `previewUrl` fallback replaced with local bytes in `merch_variant_screen.dart`.
- [ ] `MerchImageProcessor` replicates Sharp logic for front/back/mockup images.
- [ ] `MerchStorageUploader` uploads directly to GCS from device.
- [ ] `createMerchCart` accepts storage paths and skips Sharp when provided.
- [ ] Cloud function memory reduced to 256 MiB.
- [ ] Client Firestore listener attaches before function returns.
- [ ] `flutter analyze` — no new warnings.
- [ ] Existing checkout flow, cart display, and order history unaffected.
- [ ] Printful webhook registered and confirmed via webhook simulator.

**Phase:** Merch Infrastructure
**Depends on:** M156
