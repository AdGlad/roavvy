import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;

import 'studio_v2_stage.dart';
import 'widgets/garment_preview.dart';

/// **Studio V2 shell** (M1) — the permanent visual hierarchy for the whole V2
/// workflow. The live t-shirt is the hero and is ALWAYS visible; a persistent
/// Tier-1 control bar (garment colour · orientation · artwork size · front/back)
/// stays reachable at every stage; below sits a contextual workspace that later
/// milestones populate per stage.
///
/// Two independent histories:
///  * **Workflow navigation** (which [StudioStage] is shown) — owned here.
///  * **Design recipe** undo/redo — owned by the shared [StudioController].
/// The app bar surfaces them as *separate* actions; they are never conflated.
///
/// This shell implements NO creative workflow logic yet (Travels/Direction/Vibe/
/// Words/Fine-Tune are later milestones) — only the frame and its guarantees.
class StudioV2Screen extends StatefulWidget {
  const StudioV2Screen({super.key, required this.controller});

  /// The shared session (recipe, front/back, colour, orientation, size, undo).
  final StudioController controller;

  @override
  State<StudioV2Screen> createState() => StudioV2ScreenState();
}

class StudioV2ScreenState extends State<StudioV2Screen> {
  StudioController get _c => widget.controller;

  static const _stages = StudioStage.values;

  /// Current workflow stage (NOT the recipe). Default = Instant.
  StudioStage _stage = StudioStage.instant;

  /// Workflow back-stack — entirely separate from recipe undo history.
  final List<StudioStage> _navHistory = [];

  // ── Test-facing ──
  StudioStage get stage => _stage;
  bool get canWorkflowBack => _navHistory.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ── Workflow navigation (stage) — never mutates the recipe ──────────────────
  void _goToStage(StudioStage s) {
    if (s == _stage) return;
    setState(() {
      _navHistory.add(_stage);
      _stage = s;
    });
  }

  void _next() {
    final i = _stages.indexOf(_stage);
    if (i < _stages.length - 1) _goToStage(_stages[i + 1]);
  }

  void _workflowBack() {
    if (_navHistory.isEmpty) return;
    setState(() => _stage = _navHistory.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final canBack = canWorkflowBack;
    final canUndo = _c.history.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181D),
        foregroundColor: Colors.white,
        // Workflow Back (stage) — NOT recipe undo.
        leading: IconButton(
          key: const Key('v2-workflow-back'),
          tooltip: 'Back a step',
          icon: const Icon(Icons.arrow_back),
          onPressed: canBack ? _workflowBack : null,
        ),
        title: Text('Studio V2  ·  ${_stage.label}',
            style: const TextStyle(fontSize: 15)),
        actions: [
          // Recipe Undo — a SEPARATE action from workflow Back.
          IconButton(
            key: const Key('v2-recipe-undo'),
            tooltip: canUndo ? 'Undo design change' : 'Nothing to undo',
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? _c.undo : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Hero: the live shirt, occupying the majority of the screen ──
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF0E0F12),
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: GarmentPreview(
                key: const Key('v2-garment-preview'),
                service: _c.service,
                recipe: _c.current,
              ),
            ),
          ),
          _tier1Bar(),
          _workspace(),
          _stageStrip(),
        ],
      ),
    );
  }

  // ── Tier-1 persistent controls (survive all later creative changes) ─────────
  Widget _tier1Bar() {
    final comp = _c.current.composition;
    final garment = _c.current.palette?.garmentColour;
    return Container(
      color: const Color(0xFF1B1E24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _label('Colour'),
          for (final (hex, name) in StudioController.garments)
            _swatch(hex, name, garment == hex),
          _divider(),
          _label('Aspect'),
          for (final (o, lbl) in const [
            (Orientation.portrait, 'Portrait'),
            (Orientation.landscape, 'Landscape'),
            (Orientation.square, 'Square'),
          ])
            _pill('aspect-${o.name}', lbl, comp.orientation == o,
                () => _c.setOrientation(o)),
          _divider(),
          // Artwork print scale S/M/L — NOT physical garment fit (XS–XXL lives at
          // cart/checkout, a later milestone).
          _label('Size'),
          for (final (s, lbl) in const [
            (SizeClass.small, 'S'),
            (SizeClass.medium, 'M'),
            (SizeClass.large, 'L'),
          ])
            _pill('size-${s.name}', lbl, comp.sizeClass == s,
                () => _c.setSize(s)),
          _divider(),
          _label('Side'),
          _pill('side-back', 'Back', !_c.onFront, () => _c.setSide(false)),
          _pill('side-front', 'Front', _c.onFront, () => _c.setSide(true)),
        ]),
      ),
    );
  }

  // ── Contextual workspace — placeholder per stage (populated later) ──────────
  Widget _workspace() {
    return Container(
      key: const Key('v2-workspace'),
      width: double.infinity,
      color: const Color(0xFF121317),
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_stage.label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  color: Colors.tealAccent)),
          const SizedBox(height: 6),
          Text(_stage.blurb,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 4),
          const Text('Controls for this step arrive in a later milestone.',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  // ── Stage strip: current-stage indicator + jump-to-stage + Next ─────────────
  Widget _stageStrip() {
    return Container(
      color: const Color(0xFF16181D),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final s = _stages[i];
                final on = s == _stage;
                return GestureDetector(
                  key: Key('v2-stage-${s.name}'),
                  onTap: () => _goToStage(s),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: on
                          ? Colors.tealAccent.withValues(alpha: 0.18)
                          : const Color(0xFF23262C),
                      border: Border.all(
                          color:
                              on ? Colors.tealAccent : const Color(0xFF3A3D44)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(s.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: on ? Colors.tealAccent : Colors.white70)),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('v2-next'),
          onPressed: _stage == _stages.last ? null : _next,
          child: const Text('Next'),
        ),
      ]),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child:
            Text(s, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      );

  Widget _divider() => Container(
      width: 1,
      height: 20,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _pill(String id, String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          key: Key('v2-$id'),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.tealAccent.withValues(alpha: 0.2)
                  : const Color(0xFF23262C),
              border: Border.all(
                  color: selected ? Colors.tealAccent : const Color(0xFF3A3D44)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.tealAccent : Colors.white70)),
          ),
        ),
      );

  Widget _swatch(String hex, String name, bool selected) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          key: Key('v2-garment-$name'),
          onTap: () => _c.setGarment(hex),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(int.parse('FF${hex.substring(1)}', radix: 16)),
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? Colors.tealAccent : Colors.white24,
                  width: selected ? 2 : 1),
            ),
          ),
        ),
      );
}
