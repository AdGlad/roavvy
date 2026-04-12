# Roavvy – Milestone 66: Heart Card Redesign (Flag-Based Layout)

## 🎯 Milestone Goal

Redesign the Heart Card so that it:
- is a **transparent heart-shaped image**
- is filled with **real flag images (NOT emojis)**
- has **no visible gaps between flags**
- dynamically scales flags to fill the heart area
- maintains a visually balanced and dense composition
- is suitable for t-shirt printing

---

## 🧩 Current Problem

The current Heart Card:
- Uses a grid-based tile layout (`HeartLayoutEngine._generateCandidates`) clipped by a heart path.
- Leaves a 1px gap between tiles (`config.gapWidth`).
- Tiles are squares that sometimes render emoji flags if SVGs fail or aren't cached.
- Leaves a dark navy background (`Color(0xFF0D2137)`) behind the heart.
- Edge tiles are thresholded at 66% coverage, leaving noticeable grid-like stair-stepping and gaps around the border.
- Scaling logic is hardcoded to density bands that don't guarantee full gapless packing.
- Does not look premium or print-ready.

---

## ✅ Target Outcome

The Heart Card must look like:
👉 A **solid heart filled edge-to-edge with flags**
- no empty space
- no background bleed
- no visible grid gaps

---

## ❤️ Core Design Rules

### 1. Heart as Mask (CRITICAL)
- The heart shape acts as a **mask / clipping shape**.
- Flags are rendered **underneath** the mask.
- Only the portion inside the heart is visible.

### 2. Transparent Background
- Entire image must be **100% transparent outside the heart**.
- No background color.
- No semi-transparent halo.
- No rectangular artifacts.

### 3. Flag Images Only
- Use real flag images (PNG/SVG).
- DO NOT use emojis.
- Maintain correct aspect ratio (stretch to fill a packing cell if needed, or crop, but no blank space).

---

## 📐 Layout Rules

### 4. No Gaps
- Flags must **completely fill the heart area**.
- No spacing between flags (gapWidth = 0).
- No background showing through.

### 5. Dynamic Scaling
Flags must expand or shrink depending on:
- number of countries
- available space
Examples:
- few countries → large flags
- many countries → smaller flags

### 6. Dense Packing
- Layout must be **tight and efficient**.
- Avoid empty pockets or uneven clustering.

### 7. Edge Behaviour (CRITICAL)
For flags on the edges of the heart:
- flags may be partially clipped by the heart mask.
- BUT at least **80% of each flag should be visible** inside the heart prior to clipping.
- Do NOT allow tiny slivers of flags.
- Do NOT cut flags too aggressively.

### 8. Single Country Case
If there is only ONE country:
- the entire heart should be filled with that flag.
- the heart acts as a **cookie cutter**.
- no tiling.
- no repetition.

---

## 🧠 Layout Strategy

**Pre-mask Arrangement (Tessellation):**
To guarantee zero gaps and edge-to-edge filling, the algorithm must tile the rectangular bounding box of the heart shape, *then* apply the heart mask over it.

- **Grid/Masonry Packing:** A tight masonry or row-based grid (e.g. alternating row offsets) will ensure 100% density without gaps.
- **Aspect Ratio Handling:** Flags should be drawn into rectangular cells. Since flag aspect ratios vary, we will use `BoxFit.cover` inside uniform rectangular cells (e.g. 4:3 or 3:2 ratio cells) to ensure complete cell coverage without distortion.
- **Coverage Filtering:** 
  1. Generate a dense grid covering the heart's bounding box.
  2. Compute coverage for each cell using `MaskCalculator.coverageFraction`.
  3. Discard cells with `< 80%` coverage to avoid tiny slivers.
  4. Cells with `>= 80%` coverage are drawn.
  5. Apply the global heart mask to clip the entire grid smoothly.

**Balancing Density:**
To handle $N$ countries, we calculate the required grid dimensions:
- We need exactly $N$ cells with $\ge 80\%$ coverage.
- We iteratively solve for `tileSize` by generating grids of decreasing `tileSize` until the number of valid cells matches $N$ (or slightly exceeds, looping the flags).

**Single Country:**
If $N=1$, `tileSize` is set to the heart's bounding box size. The flag is drawn with `BoxFit.cover` centered in the box, and the heart mask clips it perfectly.

---

## 🧱 Rendering Pipeline

The rendering should follow:
1. **Calculate Dimensions**: Determine optimal `tileSize` so that $\ge N$ cells have $\ge 80\%$ heart coverage.
2. **Generate Layout**: Map country codes to the valid cells based on `HeartFlagOrder`.
3. **Canvas Setup**: Clear canvas to transparent.
4. **Apply Mask**: `canvas.clipPath(heartPath)`.
5. **Draw Flags**: Loop through valid cells, drawing the SVGs/PNGs filling each cell (`BoxFit.cover`).
6. **Output**: Render to a transparent PNG (via `PictureRecorder`).

---

## 📱 UX Requirements
- Heart card preview must render instantly.
- Scale cleanly across screens.
- Look identical in preview and print.
- No additional editing required for MVP.

---

## 🧪 Acceptance Criteria
- Image is fully transparent outside heart.
- Heart shape is clean and sharp.
- Flags fill entire heart area.
- No gaps between flags.
- Flags scale correctly for different country counts.
- Edge flags are at least 80% visible.
- Single country fills entire heart.
- No emoji flags used.
- Output is print-ready.

---

## ⚠️ Non-Negotiable Rules
- DO NOT use emoji flags.
- DO NOT leave gaps between flags.
- DO NOT distort flags.
- DO NOT allow background artifacts.
- DO NOT clip flags excessively (<80% visible).
- MUST use heart as mask, not drawn outline.

---

## 📌 Implementation Tasks

1. **Task 1: Rendering Pipeline Updates**
   - Update `_HeartPainter` to remove the background color (`0xFF0D2137`).
   - Modify `HeartRenderConfig` to default `gapWidth: 0.0`.
   - Update `FlagTileRenderer` to enforce SVG only (throw/drop if no SVG is available, never draw emoji) and use `BoxFit.cover` semantics to fill destination rects completely.

2. **Task 2: Dynamic Grid Algorithm**
   - Rewrite `HeartLayoutEngine._generateCandidates`.
   - Implement binary search or iterative stepping to find the exact `tileSize` that yields $\ge N$ cells with $\ge 0.80$ coverage fraction.
   - For single country ($N=1$), short-circuit to return a single Rect covering the heart bounding box.

3. **Task 3: Edge Rule Enforcement**
   - Update `_kCoverageThreshold` in `HeartLayoutEngine` to `0.80` to enforce the 80% visibility rule for edge flags.
   - Adjust `MaskCalculator.coverageFraction` if necessary to accurately test the 80% threshold.

4. **Task 4: Mask Application**
   - Ensure the heart path is strictly used as a clipping mask (`canvas.clipPath`) *over* the tightly packed grid.
   - Verify the feathered edge (`dstIn` blend pass) in `_HeartPainter` respects the transparent background requirement (do not feather against black/navy, feather against alpha).

5. **Task 5: QA and Export Validation**
   - Validate transparency on generated export images (`card_image_renderer.dart`).
   - Test rendering with 1, 5, 20, and 150 countries to ensure dynamic scaling packs flags correctly without gaps or slivers.

