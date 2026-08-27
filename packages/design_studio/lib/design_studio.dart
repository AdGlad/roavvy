/// design_studio — the interactive Studio session/orchestration layer.
///
/// Public surface for both hosts (macOS design_lab, mobile Roavvy V2):
///  * [StudioController] — the UI-agnostic editing session (recipe mutations,
///    axes, locks, remix, alternatives, undo/redo, front/back + travel context).
///  * [LabShowcaseGenerator] / [LabStyle] etc. — portable showcase/alternative
///    generation over the design_forge engine.
///  * [RenderService] — portable render orchestration (cached CanvasRenderer).
///
/// Host-specific concerns (UI widgets, filesystem/bundle asset resolution,
/// platform integrations) are injected by the host and never live here.
library design_studio;

export 'src/lab_styles.dart';
export 'src/lab_showcase_generator.dart';
export 'src/render_service.dart';
export 'src/studio_controller.dart';
