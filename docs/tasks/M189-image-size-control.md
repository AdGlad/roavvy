# M189 — Shop Configurator: Image Size (Small / Medium / Large)

**Status:** `done`
**Created:** 2026-07-26
**Updated:** 2026-07-26
**Depends on:** M187 for final UI wiring; pipeline work is independent
**Program:** Rich Shop Configurator (M187–M189)

---

## Product Rationale

The printed artwork is currently locked to a **fixed print area per placement** —
the user cannot make the design bigger or smaller. Some people want a bold
chest-filling print; others want a small, subtle badge. Adding **Small /
Medium / Large** gives that control with three safe, curated presets (rather than
a fiddly free-scale) — simple to choose, and each maps to a print area we've
validated against the mockups and Printful placement.

Today `product_mockup_specs.dart` returns a hardcoded `printAreaNorm` Rect per
(placement, frontPosition). Image size becomes a **scale multiplier applied to
that Rect about its centre**, plumbed through the mockup preview and into the
order metadata so preview == print.

---

## Scope

### Delivered
- **New `ImageSize` concept** — `small | medium | large` (Medium = today's
  behaviour, so existing designs are unchanged by default).
- **Scale applied to the print area:** each size maps to a multiplier (e.g.
  S ≈ 0.75, M = 1.0, L ≈ 1.3) applied to `printAreaNorm` about its centre, then
  clamped to stay within the garment's printable bounds.
- **Live mockup reflects the size** — the composited artwork visibly grows/shrinks
  on the shirt as the user changes size.
- **Persisted + forwarded:** the chosen size is stored on `MerchCartItem` and
  carried into the order/Printful metadata so the manufactured print matches the
  preview (via `printful_placement_mapper` / `merch_variant_lookup` as needed).
- **Exposed in the M187 configurator** as an S/M/L segmented control.

### Out of scope
- Free continuous scale / drag-to-resize (curated presets only).
- Per-face independent sizing (one image-size applies to the active design;
  revisit if QA shows front & back need to differ).
- Changing Printful product variants — size here is *print scale*, distinct from
  garment size (S/M/L/XL clothing size stays separate; **name the control
  "Image size" to avoid confusion with garment size**).

---

## UX Design

- **Control:** segmented `Small · Medium · Large` in the configurator, labelled
  **Image size** (distinct from garment **Size**). Default **Medium**.
- Changing it re-composites the mockup so the print area grows/shrinks about its
  centre — instantly visible on the large mockup.
- Guardrail: Large is clamped so the artwork never bleeds past the printable
  area; if a placement can't grow (e.g. left-chest), Large is capped and still
  reads as "as big as this placement allows".
- **Reduce-motion:** size change is an instant re-render, no scale animation.

## Architecture

- **`product_mockup_specs.dart`:**
  - Introduce `enum ImageSize { small, medium, large }` (or a shared location if
    a model file is more appropriate) with a `double scaleMultiplier`.
  - `specsFor(...)` gains an `ImageSize imageSize = ImageSize.medium` param;
    after selecting the base `printArea`, scale it about its centre by the
    multiplier and clamp to `[0,1]` bounds (and to a per-placement max so it
    stays on-garment). Medium ⇒ ×1.0 ⇒ byte-identical to today.
  - Add unit tests: M is unchanged vs current constants; S shrinks about centre;
    L grows about centre and clamps at bounds.
- **`local_mockup_preview_screen.dart`:** add `_imageSize` state (default
  medium); pass into `ProductMockupSpecs.specsFor(...)` wherever specs are
  resolved for the painter; changing it triggers a re-render (setState / variant
  refresh path used by placement changes).
- **Persistence + order path:** add `imageSize` to `MerchCartItem`
  (field + `toJson`/`fromJson`, ~128-187) so it survives add-to-cart and reorder.
  Thread into the order confirmation / Printful metadata. If Printful needs an
  explicit print scale/position, extend `printful_placement_mapper.dart`;
  otherwise the scaled artwork bytes already encode the size and we only persist
  it for display/reorder.
- **Interaction with placement:** scale is applied *after* the placement Rect is
  chosen, so S/M/L composes cleanly with left-chest / center / right-chest / back.

## Tasks
- T1 — `ImageSize` enum + multipliers; `specsFor` scales `printAreaNorm` about
  centre with bounds/placement clamping.
- T2 — Unit tests for specs: M == current; S/L scale about centre; clamp at
  edges; left-chest cap.
- T3 — `MerchCartItem.imageSize` field + JSON round-trip + test.
- T4 — Thread `imageSize` through the order/Printful metadata path
  (`printful_placement_mapper` / `merch_variant_lookup` / order confirmation).
- T5 — (M187-dependent) "Image size" S/M/L segmented control in the configurator;
  live re-render; clearly distinct from garment Size.
- T6 — Widget test: changing image size re-composites the mockup print area.
- T7 — `flutter analyze` clean; device QA that preview matches expected print
  scale for each placement.

## Definition of Done
- [ ] Image size S/M/L selectable; Medium reproduces today's output exactly.
- [ ] Mockup print area visibly scales; artwork never bleeds off the garment.
- [ ] Size persists on the cart item and reaches order/Printful metadata.
- [ ] Control is clearly distinct from garment size.
- [ ] `flutter analyze` no new issues; specs + widget tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Large bleeds past printable area | Medium | High | Clamp to bounds + per-placement max; test edges |
| Confusion with garment size | High | Medium | Label "Image size"; separate control group; copy |
| Preview scale ≠ printed scale | Medium | High | Single source multiplier used for both preview + order metadata; QA |
| Medium accidentally changes existing output | Low | High | M ⇒ ×1.0 identity; golden-free equality test vs current constants |
