# M65 — Fix Printful Back Mockup: Task List

**Goal:** `LocalMockupPreviewScreen` correctly stores and displays both the Printful front and back mockup URLs after generation. The user sees both final production-ready Printful views before purchase. Silent fallback to local mockup when Printful back exists is eliminated.

**Branch:** `milestone/m65-printful-back-mockup`

---

## Investigation Summary

The Cloud Function `generateDualPlacementMockups()` already returns both URLs (`frontMockupUrl`, `backMockupUrl`). The bug is entirely client-side:

- `LocalMockupPreviewScreen` stores only `String? _frontMockupUrl` — no `_backMockupUrl` field.
- Response handler discards `backMockupUrl` from the callable result.
- `_buildMockupArea()` unconditionally returns the local mockup when `!_showingFront`, regardless of whether `_backMockupUrl` is available.

**Root files:** `apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart`

No Cloud Function changes are required.

---

## Scope

**Included:**
- Add `String? _backMockupUrl` state field
- Extract and store `backMockupUrl` from callable response alongside existing `frontMockupUrl`
- Update `_buildMockupArea()` to display Printful back mockup when `_backMockupUrl != null` and back face is active
- Add a `_PrintfulMockupStatus` value type to distinguish front-only / back-only / both / neither states
- Show explicit inline banner when one Printful URL is null after generation (not silent local fallback)
- Add `InteractiveViewer` zoom support to back Printful mockup (same as existing front)
- Tests

**Excluded:**
- Cloud Function changes (already correct)
- Poster product (different mockup path)
- Non-passport card templates
- Printful API changes

---

## Tasks

### Task 1 — Add `_backMockupUrl` state and populate from callable response
**Deliverable:** Screen stores both Printful mockup URLs after generation completes.

**Acceptance criteria:**
- `String? _backMockupUrl` field added alongside `String? _frontMockupUrl` in `LocalMockupPreviewScreen` state (initialised to null)
- In the block that handles the `createMerchCart` callable response, extract `backMockupUrl` from the result data map and assign to `_backMockupUrl` (same location that currently assigns `frontMockupUrl`)
- `setState` call covers both assignments atomically
- `dart analyze` clean

---

### Task 2 — Add `_PrintfulMockupStatus` helper
**Deliverable:** A lightweight value type (or enum) that encodes which Printful mockups are available after generation.

**Acceptance criteria:**
- Defined as a private enum or sealed class within `local_mockup_preview_screen.dart`:
  ```dart
  enum _PrintfulMockupStatus { pending, frontOnly, backOnly, both, neither }
  ```
- A getter on the screen state returns the correct value based on `_state`, `_frontMockupUrl`, and `_backMockupUrl`:
  - `_state != ready` → `pending`
  - both non-null → `both`
  - front only → `frontOnly`
  - back only → `backOnly`
  - both null → `neither`
- No behaviour change from this task alone — status used in Task 3
- `dart analyze` clean

---

### Task 3 — Update `_buildMockupArea()` to display Printful back mockup
**Deliverable:** When back face is active and `_backMockupUrl` is non-null, the Printful back mockup image is shown instead of the local mockup.

**Acceptance criteria:**
- `_buildMockupArea()` logic:
  ```
  if state == approving → _ApprovingView (unchanged)
  if state == ready:
    if showing front:
      if _frontMockupUrl != null → InteractiveViewer(Image.network(_frontMockupUrl))
      else → _buildPrintfulUnavailableBanner(face: front)
    if showing back:
      if _backMockupUrl != null → InteractiveViewer(Image.network(_backMockupUrl))
      else → _buildPrintfulUnavailableBanner(face: back)
  else → _buildLocalMockupArea() (pre-generation preview, unchanged)
  ```
- `InteractiveViewer` for back mockup uses same `minScale: 1.0, maxScale: 5.0` as front
- `errorBuilder` on back `Image.network` shows the unavailable banner widget on network error
- Pre-generation path (state != ready) continues to show local mockup as preview (unchanged)
- `dart analyze` clean

---

### Task 4 — Add `_buildPrintfulUnavailableBanner` widget
**Deliverable:** An explicit inline widget shown when one Printful mockup is missing after generation — replaces silent local fallback.

**Acceptance criteria:**
- Widget displays a brief message e.g. "Front view unavailable" / "Back view unavailable" (parameterised by face)
- Visual: centred column with a muted icon (e.g. `Icons.image_not_supported_outlined`) and text at caption size, on a light grey background matching the mockup area
- Does NOT show the local mockup image — this deliberately signals a Printful issue, not a local preview
- Tapping the area does nothing (no retry in this milestone — KISS)
- Widget is only reachable when `_state == ready` and the relevant URL is null
- `dart analyze` clean

---

### Task 5 — Tests
**Deliverable:** Unit and widget tests covering the new dual-mockup behaviour.

**Acceptance criteria:**
- Unit test: `_PrintfulMockupStatus` getter returns correct value for all (state, frontUrl, backUrl) combinations (6 cases minimum)
- Widget test: with `_state = ready`, `_frontMockupUrl = 'https://…'`, `_backMockupUrl = 'https://…'`, toggling to back shows `Image.network` (not local painter)
- Widget test: with `_state = ready`, `_frontMockupUrl = 'https://…'`, `_backMockupUrl = null`, toggling to back shows unavailable banner (not local painter)
- Widget test: with `_state != ready`, both faces show local mockup (pre-generation path unchanged)
- All existing tests pass

---

## Dependencies

```
Task 1 (store backMockupUrl) → Tasks 2, 3, 4
Task 2 (_PrintfulMockupStatus) → Task 3
Task 3 (display logic) → Task 4
Tasks 1–4 → Task 5
```

Tasks 3 and 4 are implemented together (Task 3 calls the widget built in Task 4).

---

## Risks

1. **Callable response field name** — verify the exact key name in the Cloud Function response map (`backMockupUrl` vs `back_mockup_url`). Read the response extraction block in the Cloud Function before implementing Task 1.
2. **`_buildMockupArea` complexity** — the method has multiple nested branches; read it in full before editing to avoid breaking the `approving`/`rerendering` state paths.
3. **No retry** — if Printful returns one null URL, this milestone intentionally shows a static banner rather than a retry button. Retry is out of scope.
