/// Design Forge — Flutter/dart:ui rendering layer.
///
/// A headless, composable `ui.Canvas` pipeline that turns a `DesignRecipe`
/// (from `design_forge`) into a `ui.Image` + PNG bytes with NO widget tree.
library design_forge_render;

export 'src/asset_resolver.dart';
export 'src/clip/shape_geometry.dart';
export 'src/clip/text_mask.dart';
export 'src/contact_sheet.dart';
export 'src/effects/textures.dart';
export 'src/geometry/torn_mask.dart';
export 'src/render_target.dart';
export 'src/renderer.dart';
export 'src/stages/clip_stage.dart';
export 'src/stages/colour_stage.dart';
export 'src/stages/composition_stage.dart';
export 'src/stages/edge_treatment_stage.dart';
export 'src/stages/effects_stage.dart';
export 'src/stages/render_stage.dart';
export 'src/svg_flag_resolver.dart';
