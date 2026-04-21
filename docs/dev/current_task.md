# Active Task: M73 — Mockup Fidelity: Strict Printful-Only Purchase Flow
Branch: milestone/m73-mockup-fidelity

## Goal
After approval, the user sees only Printful-generated mockups for every required face, and cannot proceed to checkout unless all required mockups are present.

## Scope
In: Restore Printful placement IDs; restore back mockup display; remove local fallback from ready state; plain-shirt view for none positions; strict checkout gate; error state; cloud function logging.
Out: Card templates, scan, map, web, poster, shopifyOrderCreated.

## Tasks
- [x] T1 — Restore Printful placement IDs + logging — `apps/functions/src/index.ts`
- [x] T2 — Restore _backMockupUrl field + response reading — `local_mockup_preview_screen.dart`
- [x] T3 — Rewrite ready-state display (no local fallback) — `local_mockup_preview_screen.dart`
- [x] T4 — Add _buildPlainShirtView helper — `local_mockup_preview_screen.dart`
- [x] T5 — Add _buildMockupErrorState + strict checkout gate — `local_mockup_preview_screen.dart`
- [x] T6 — Rebuilt + deployed cloud function ✅ Complete (2026-04-21)

## Risks
| Risk | Mitigation |
|---|---|
| front_left/front_right may not exist on Printful product 12 | Strict error state surfaces failure; logging reveals API response |
| back comment "front-facing photo" was wrong | Revert — back placement mockup shows back of shirt |
