# Active Tasks: M170 — Flag Grid: Density Repeats & Clip Shapes
Branch: milestone/m170-flag-grid-clip-shapes

## Goal
Users can choose a clip shape (none/heart/circle) and flag repeat count (×1–×9) in a new FlagShapeCustomiseScreen before designing a grid-template shirt.

## Tasks

- [ ] T1 — GridClipShape enum + flagRepeatCount to layout engine + GridFlagsCard
- [ ] T2 — _clipPathFor() + clip/feather pass in GridFlagsPainter
- [ ] T3 — Deprecate HeartFlagsCard: redirect + remove from carousel/ranker
- [ ] T4+T5 — FlagShapeCustomiseScreen + _ClipVariantCard
- [ ] T6 — Routing: grid template taps → FlagShapeCustomiseScreen
- [ ] T7 — LocalMockupPreviewScreen flagRepeatCount + clipShape params
- [ ] T8 — merchDefaultRepeatCount() smart defaults helper
- [ ] T9 — Unit tests: layout engine repeat + non-adjacency
- [ ] T10 — flutter analyze clean
