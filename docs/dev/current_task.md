# M21 — Personalised Flag Print Pipeline

**Milestone:** 21
**Phase:** 10 — Commerce
**Status:** ✅ Complete — 2026-03-21

## Goal

Every merch order carries a unique auto-generated flag grid image. Mobile shows a live preview. Firebase Functions generate preview + print file at `createMerchCart` time (before payment). Webhook only validates and submits to Printful via direct API.

## Tasks

| Task | Description | Status |
|---|---|---|
| 76 | `FlagGridPreview` Flutter widget — live flag grid in `MerchVariantScreen` | ✅ Done |
| 77 | `MerchConfig` M21 type extension + Shopify GID → Printful variant ID mapping table | ✅ Done |
| 78 | `imageGen.ts` — `generateFlagGrid()` helper (`flag-icons` + `@resvg/resvg-js` + `sharp`) | ✅ Done |
| 79 | `createMerchCart` updated — generates preview + print PNG, uploads to Firebase Storage | ✅ Done |
| 80 | `shopifyOrderCreated` updated — validates file, creates Printful order via API with print file | ✅ Done |

## Key ADRs

- ADR-062 — Commerce backend architecture
- ADR-063 — Printful as POD partner (revised M21: pure API, Shopify app out of critical path)
- ADR-064 — Firebase Functions v2 structure
- ADR-065 — Two-stage flag image pipeline (generate at cart time; webhook validates + submits)

## Pending before production

1. **Printful variant IDs** — replace placeholder `0` values in `printDimensions.ts` with verified numeric IDs from the Printful dashboard.
2. **Firebase Storage rules** — configure bucket to allow public read on `previews/*`; print files remain private.
3. **`PRINTFUL_API_KEY`** — add to Firebase Functions environment config.
4. **Cloud Run smoke test** — deploy and verify `@resvg/resvg-js` + `sharp` linux/amd64 binaries load correctly.
5. **Printful Shopify app auto-import** — disable in Printful dashboard for generated-merch variants (ADR-063).

## Next step

Update `docs/dev/current_state.md` and plan next milestone.
