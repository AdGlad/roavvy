# M76 — Named Printful Placement for Left Chest Designs

## Goal
Replace pre-compositing for `left_chest` with Printful's named `left_chest` placement,
so the Printful photorealistic mockup shows a small chest badge. Production orders use the
same named placement so mockup and printed shirt match.

## Scope
In: `apps/functions/src/index.ts`, `apps/functions/src/types.ts`
Out: right_chest (pre-composite retained), mobile app, local mockup, card editor, web, packages

---

## T1 — Add `frontPosition` to MerchConfig and persist it

**File:** `apps/functions/src/types.ts`, `apps/functions/src/index.ts`

**Deliverable:**
- Add `frontPosition: string | null` to `MerchConfig` interface with JSDoc.
- In `createMerchCart` `configData`, write `frontPosition: effectiveFrontPosition`.

**Acceptance criteria:**
- `MerchConfig.frontPosition` exists in TypeScript type.
- New `configData` object includes `frontPosition`.

---

## T2 — Update left_chest print file: small chest PNG, not composited canvas

**File:** `apps/functions/src/index.ts` — front image processing block (~line 331)

**Deliverable:**
- For `effectiveFrontPosition === 'left_chest'`:
  - Resize artwork to fit within `maxW = Math.round(canvasW * 0.29)`,
    `maxH = Math.round(canvasH * 0.30)` using `{ fit: 'inside' }`.
  - Return this small buffer directly — do NOT composite onto full canvas.
- For `effectiveFrontPosition === 'right_chest'`: keep existing pre-composite (unchanged).
- For `center`: unchanged.

**Acceptance criteria:**
- `left_chest` branch produces a small buffer, not a 4500×5400 canvas.
- `right_chest` and `center` branches are unchanged.

---

## T3 — Update `generatePrintfulMockup` to use named `left_chest` placement

**File:** `apps/functions/src/index.ts` — placements construction (~line 45)

**Deliverable:**
- When `frontPosition === 'left_chest'` → push `placement: 'left_chest'`.
- Otherwise → push `placement: 'front'` (unchanged).

**Acceptance criteria:**
- Mockup task uses `placement: 'left_chest'` for left_chest.
- All other positions use `placement: 'front'`.

---

## T4 — Update `shopifyOrderCreated` Orders API file placement

**File:** `apps/functions/src/index.ts` — files array (~line 793)

**Deliverable:**
- Read `config.frontPosition`.
- `left_chest` → `{ placement: 'left_chest', url: frontPrintFileSignedUrl }`.
- Otherwise → `{ url: frontPrintFileSignedUrl, type: 'default' }` (unchanged).

**Acceptance criteria:**
- Printful order uses `placement: 'left_chest'` for left_chest configs.
- All other front placements unchanged.

---

## T5 — Compile, ADR, docs

**Deliverable:**
- `npm run build` in `apps/functions` compiles without errors.
- ADR-128 appended to `adr-recent.md`.
- `current_task.md` marked ✅ Complete.
