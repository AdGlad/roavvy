# M28 — ✅ Complete (2026-03-26)

**Milestone:** 28
**Phase:** 12 — Commerce & Mobile Completion
**Status:** ✅ Complete

## Task List

| Task | Description | Status |
|---|---|---|
| 116 | Country name lookup helper for web | ✅ Done |
| 115 | `/shop/design` authenticated country-selection page | ✅ Done |

## What Was Built

- `apps/web_nextjs/src/lib/countryNames.ts` — `COUNTRY_NAMES` record + `countryName(code)` helper using `Intl.DisplayNames` with static fallback; 65 codes
- `apps/web_nextjs/src/lib/__tests__/countryNames.test.ts` — 24 tests, all passing
- `apps/web_nextjs/src/app/shop/design/page.tsx` — authenticated country-selection page: auth guard, pre-selected checkbox grid, select all/deselect all, `createMerchCart` call, Shopify redirect, error + loading states
- `apps/web_nextjs/src/app/shop/design/__tests__/page.test.tsx` — 2 tests (POSTER_VARIANT_ID format + value)
- `apps/web_nextjs/jest.config.ts` — updated `testMatch` to include `*.test.tsx`
- `next build` clean, `/shop/design` present in route output
