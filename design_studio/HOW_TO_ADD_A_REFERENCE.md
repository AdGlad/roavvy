# Adding reference designs

Reference images teach the engine *abstract principles* (hierarchy, negative
space, texture, colour…) — they are never copied. This is the workflow from
dropping an image to influencing generation.

## 1. Drop the image

Put it in the bucket that matches your judgement:

```
design_studio/reference_images/liked/      ← emulate these
design_studio/reference_images/disliked/   ← avoid these
```

One image per file, descriptive stem, e.g. `grid-montage-europe-vintage-01.png`.
Images are git-ignored by default (bulky / possibly rights-encumbered).

## 2. Create the analysis record

Each image needs a sibling record at
`design_studio/reference_analysis/<same-stem>.json`. Two ways to create it —
use either or both (the analyzer merges, it doesn't clobber your edits):

### Option A — scaffold a blank stub (fast, no device)

```
dart run design_studio/tools/scaffold_references.dart
```

Writes a stub for every image without a record: `verdict` inferred from the
folder, provenance pre-filled, `features` left blank for you to complete.
Idempotent — existing records are untouched.

### Option B — auto-fill objective features (host decode)

```
flutter test test/features/merch/design_engine/reference/analyze_references_test.dart
```

Decodes each image (via Skia / `dart:ui`) and fills the **measurable** fields:
`dominantColors`, `focalHierarchy`, `legibility`, plus an `analysis` block
(focal concentration, visual-density hint, colourfulness, aspect). It **merges**
into any existing record, preserving your human-authored fields (`verdict`,
`tags`, `template`, `reasons`, …). Re-run any time you add images or tweak the
analyzer.

> On-device, the higher-fidelity path is the native Vision + CoreImage
> (`CIAreaAverage`) bridge already in the app; the host analyzer here is the
> zero-setup dev equivalent and writes `analysis.source = "host-dart-ui"`.

## 3. Fill in the subjective calls

Open the record and complete what a machine shouldn't decide: `verdict`
(if you disagree with the folder), `reasons`, `features.tags`,
`features.printStyleFeel`, and the composition read (`template`, `layoutMode`,
`density`, `clipShape`). Schema: `reference_analysis/reference_record.schema.json`.

## 4. Rebuild the Design DNA

Once records exist, the aggregated **Roavvy Design DNA** can be built from them
(`RoavvyDesignDna.aggregate(styleDnaList)`) instead of the principled default —
liked references define the target bands, disliked ones push bands away. That
DNA then steers generation priors and quality scoring.

---

**Rights:** only keep images you may keep. Third-party references default to
`provenance.rightsCleared = false` and should not be committed; commit a
specific one with `git add -f` only after clearing rights and recording them.
