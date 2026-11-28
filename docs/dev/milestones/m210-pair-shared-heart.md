# M210 — Pair Signature 2: Shared Heart

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M209 (split seam), M208 (brush edge)
**Status:** Todo
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
