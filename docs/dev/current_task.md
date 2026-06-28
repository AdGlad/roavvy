# M170 — Flag Grid: Density Repeats & Clip Shapes

**Milestone:** M170
**Status:** Complete

## Done
- T1: `GridClipShape` enum + `flagRepeatCount` in `FlagGridLayoutEngine.compute()` with round-robin non-adjacency spread
- T2: `_clipPathFor()` + feathered edge in `_GridPainter`; `MaskCalculator.applyFeatheredEdge()` extracted to heart_layout_engine.dart
- T3: `GridFlagsCard` accepts `clipShape` + `flagRepeatCount`; `HeartFlagsCard` redirected to `GridFlagsCard(clipShape: heart)`
- T4: `CardImageRenderer.render()` wires `clipShape` + `flagRepeatCount` through
- T5: `FlagShapeCustomiseScreen` — 3-page PageView (Grid/Heart/Circle), Slider ×1–×9, 400ms debounce, smart defaults
- T6: `LocalMockupPreviewScreen` accepts `clipShape` + `flagRepeatCount`
- T7: `merch_option_list_widgets.dart` grid taps → `FlagShapeCustomiseScreen`
- T8: `MerchTemplateRanker` excludes deprecated `CardTemplateType.heart`
- T9: Unit tests for layout engine + non-adjacency algorithm
- T10: flutter analyze — 0 new warnings; 1498 tests pass
