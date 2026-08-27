// Backward-compat shim. The render-orchestration service now lives in the
// shared `design_studio` package (M0 extraction); this file re-exports it so
// existing Lab imports (`package:design_lab/render_service.dart`) keep working.
export 'package:design_studio/design_studio.dart';
