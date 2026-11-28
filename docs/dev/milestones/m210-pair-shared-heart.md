# M210 — Pair Signature 2: Shared Heart

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M209 (split seam), M208 (brush edge)
**Status:** Draft built — awaiting owner Lab approval
**Pack:** `shared_heart.pack.json` (`countries: 2`)
**Size:** S–M

---

## 1. The design

Reference: `~/Downloads/1-heart-2-countries.jpg` (Venezuela + Puerto Rico). Stock art, style only.
- **One heart**, with flag A filling the left lobe and flag B the right, split down the middle. The seam is a slight hand-drawn curve.
- The heart edge is **scribbled dry brush**: bristle hatching spills past the outline (as in the reference, top-left lobe), and there is light scratched distress across both flags.
- Each flag keeps its focus: Puerto Rico's star triangle sits on its half.

## 2. Engine work

- Reuse the `heart` clip, the M209 `splitPair` seam, and the M208 brush mask used as an **edge scribble** around the clip outline (new `clip.edge: brush`).
- Distress: light WearRaster scratches (an envelope that stays below Curtain Split's level).

## 3. Definition of done

As M209: hard-fail free on the sample pairs, then the **owner approves**.

## As built (2026-11-28)

**Status:** Draft built. Zero hard QA failures; **the owner's approval in the Lab is still to come.**

- **Engine:**
  - `DesignRecipe.heartPair` (`HeartPair`, design_forge) with layout `shared`.
  - Pure-Dart geometry in `HeartPairLayout` (heart polygon, seam, per-flag crop and placement). The renderer and pair QA share it.
  - `HeartPairStage` (design_forge_render) runs after the Brush Flag stage.
  - The seam is drawn by the heart layout itself, not the M209 `splitPair` composition, which wasn't merged when this was built. The two could share seam code later.
- **Scribble edge:** new `BrushEdge.paintHatch`. The heart is painted as parallel round-ended brush strokes whose ends spill past the outline or stop short of it, with bristle tails and dry streaks. `BrushEdge.paintScratches` adds worn-print grain. This replaces the M208 spike edge for hearts, which looked sawtooth. Strokes never bridge more than a third of a gap, which fixes the outward spike in the top notch.
- **Emblems:**
  - `fitInHeart` shrinks a flag (to 55% at most) and slides its focus toward the roomiest part of the heart when the heart's curves would hide more than 20% of its `FlagFocus` emblem box.
  - Edge colours are extended past the flag, so the heart stays full.
  - A test checks that all 267 flags keep at least 75% of their emblem in both slots.
  - The `FlagFocus` table was not changed.
- **Pair QA:** a `PairGeometry.of` case reports the true crops (heart polygon in flag space) and the seam.
- **Pack `shared_heart`** (draft v1, square):
  - Strokes are 0.065 wide at −38°, with spill 0.45, tails 0.9 and streaks 0.4.
  - Scratches are 0.85, raised toward the reference's grunge.
  - The variation envelope covers seed, seam curve and lean, hatch angle (−48…−32), spill and scratches (0.7–1.0).
  - Locks are set on the six default lock pairs.
- **QA** (`signature_qa_cli_test`, heroes + 4 variations): 32 sample pairs → 0 fail; 50 random pairs → 0 fail. The soft warnings are:
  - garment contrast, as with every flag pack;
  - `pair_seam` on look-alike pairs (ID+MC, NL+LU, FR+IT…). The reference design has no seam line either, so this is left for the owner to decide.
- **Open items:**
  - The reference's grunge still includes speckle, which `paintScratches` does not draw (it only draws scuffs).
  - Flags shrunk for their emblem (GR, PA, TT) show extended edge colour in the heart's corners.
