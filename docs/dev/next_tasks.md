# M34 — Mobile Commerce: Full T-shirt Mockup Preview

**Milestone:** 34
**Phase:** 12 — Commerce & Mobile Completion
**Status:** Not started

**Goal:** Before completing checkout, the user sees a photorealistic mockup of the full t-shirt with their flag grid design applied — not just the print file image.

---

## Scope

**Included:**
- Printful Mockup Generator API called server-side in `createMerchCart`, after print file is uploaded
- `mockupUrl` field added to `MerchConfig` (Firestore document + Dart model)
- `MerchVariantScreen` updated to display the mockup image (shimmer skeleton while `mockupUrl` is null; flag grid preview as fallback if generation times out or errors)

**Excluded:**
- Multiple mockup angles (back / lifestyle shots) — front face only
- Poster product mockups — poster Printful sync variants are not configured; t-shirt only
- Web mockup generation — deferred to M28
- Pre-generation on colour change — mockup is generated once per cart creation

---

## Tasks

### Task 120 — Add `mockupUrl` to TypeScript types

**Deliverable:**
- `MerchConfig` TypeScript interface (`apps/functions/src/types.ts`) gains a `mockupUrl: string | null` field
- `CreateMerchCartResponse` TypeScript interface gains a `mockupUrl: string | null` field

**Acceptance criteria:**
- `MerchConfig.mockupUrl` is `null` on creation; set by Firebase Function after mockup generation
- `CreateMerchCartResponse.mockupUrl` is present (nullable) — allows the mobile app to read it directly from the callable response without a Firestore poll
- No Dart model changes needed — the mobile reads the callable response as a raw map
- No other fields changed

---

### Task 121 — Call Printful Mockup API in `createMerchCart`

**Deliverable:**
- After the print file is uploaded and the Shopify cart is created, `createMerchCart` calls the Printful Mockup Generator API
- The mockup task is submitted, polled until complete (max 20 s), and the first returned mockup URL stored in the Firestore `MerchConfig` document as `mockupUrl`
- If the API times out or errors, `mockupUrl` remains `null` — the function does not throw; checkout proceeds normally

**Acceptance criteria:**
- `POST https://api.printful.com/v2/mockup-tasks` is called with the correct catalog variant ID (from `PRINTFUL_VARIANT_IDS`) and the print file URL
- Polling interval: 2 s; max attempts: 10 (20 s total)
- On success: Firestore `MerchConfig.mockupUrl` is set to the returned image URL before the function returns
- On timeout/error: `mockupUrl` is `null`; function returns `checkoutUrl` as normal; error is logged via `console.error`
- `PRINTFUL_API_KEY` is used for auth (already present in environment)
- Only the t-shirt product is targeted — poster variants (`mockupUrl` always `null` for poster) are skipped silently

**Notes:**
- Printful Mockup API: `POST /v2/mockup-tasks` with `{ variant_ids: [printfulVariantId], files: [{ placement: "front", url: printFileSignedUrl }], format: "jpg" }` — v2, consistent with existing order creation (ADR-089)
- Poll with `GET /v2/mockup-tasks/{task_key}` — check `data.status`: `"waiting"` → retry, `"completed"` → extract `data.mockups[0].mockup_url`, `"error"` → log + return null
- Skip mockup entirely when `printfulVariantId === 0` (poster variants, not configured in Printful)
- Mockup call goes AFTER cart creation (step 5 of 6) — cart must succeed before spending time on mockup
- This adds up to 20 s to `createMerchCart`. The function already has `timeoutSeconds: 300` and the app shows a loading spinner — no UX change needed

---

### Task 122 — Display mockup image in `MerchVariantScreen`

**Deliverable:**
- `MerchVariantScreen` shows the full t-shirt mockup image where the flag grid preview currently appears
- While `mockupUrl` is null (loading or fallback), the existing flag grid preview image is shown with a shimmer overlay
- Once `mockupUrl` is set, the mockup image replaces the flag grid

**Acceptance criteria:**
- If `createMerchCart` returns a `mockupUrl`: display it via `Image.network`; flag grid preview is not shown
- If `mockupUrl` is null (timeout / poster product): display the flag grid preview as before — no regression
- Shimmer skeleton shown during `createMerchCart` call (already exists; ensure it covers the mockup image area correctly)
- No layout changes to the rest of the screen (variant picker, size selector, checkout button)

---

## Dependencies

```
Task 120 (MerchConfig field)
    └─ Task 121 (Firebase Function mockup call)
        └─ Task 122 (mobile display)
```

---

## Risks / Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| Printful Mockup API request shape differs from expected (product ID vs sync product ID) | Medium | Read Printful API docs before starting Task 121; verify against a live API call in Cloud Shell |
| Mockup generation takes > 20 s for a complex flag grid | Low | Flag grid fallback is always available; timeout path is tested |
| Printful API returns a low-resolution or watermarked mockup on free tier | Low | Verify in Printful dashboard after first successful generation |
| Poster variants silently skip mockup — user sees flag grid; acceptable for PoC | Accepted | Poster Printful sync not configured; document in code comment |
