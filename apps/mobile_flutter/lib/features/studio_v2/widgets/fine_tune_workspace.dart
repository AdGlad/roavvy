import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Typography;

/// **Fine Tune** workspace (M7) — the optional power-user surface. Every control
/// reads and writes the shared [StudioController] refine API directly (no
/// duplicated design state); the only local state is which category is expanded
/// (pure view state). The live shirt above stays the hero.
///
/// Categories are *contextual* — only the ones [StudioController.refineCategories]
/// returns for the CURRENT recipe are shown, and each is collapsed by default
/// (progressive disclosure). Controls map 1:1 onto engine state:
///  * **Finish**  — one-tap named finishes ([StudioController.finishPresets] via
///    [StudioController.applyFinishPreset], undoable).
///  * **Layout**  — [FillAlgorithm], [Density], copies-per-country and scatter
///    (live [StudioController.setComp]).
///  * **Graphic** — clip size / rotation / corner / feather (live
///    [StudioController.setClip]).
///  * **Text**    — title case / placement / statement hero (live).
///  * **Colour**  — [StudioController.colourTreatments] (undoable) + a continuous
///    vintage-grade knob (live [StudioController.setVintageGrade]).
///  * **Edges**   — [TearStyle] + damage/depth/fray/corner/asymmetry (live
///    [StudioController.setEdges]).
///  * **Effects** — distress / grain / fade / cracks / acid wash / tie-dye /
///    shatter / halftone / ripple (live [StudioController.setFx]).
///  * **Print**   — Riso / Newsprint / Sun-faded / Photocopy print looks (live).
///
/// Continuous parameters are *live* edits (no history step, matching the existing
/// [StudioController.setFx]/`setComp`/`setClip` semantics); discrete Finish and
/// Colour choices are committed and so participate in recipe Undo. Each category
/// offers a Reset that returns just that category to its engine default.
class FineTuneWorkspace extends StatefulWidget {
  const FineTuneWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<FineTuneWorkspace> createState() => _FineTuneWorkspaceState();
}

class _FineTuneWorkspaceState extends State<FineTuneWorkspace> {
  StudioController get _c => widget.controller;

  /// View-only: which categories are expanded. Not design state.
  final Set<RefineCategory> _open = {};

  static String _slug(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  @override
  Widget build(BuildContext context) {
    final cats = _c.refineCategories();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'FINE TUNE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Precise, optional controls — only what applies to this '
            'design. Tap a section to open it.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          for (final cat in cats) _category(cat),
        ],
      ),
    );
  }

  Widget _category(RefineCategory cat) {
    final open = _open.contains(cat);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E24),
        border: Border.all(color: const Color(0xFF2C2F36)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: Key('v2-ft-cat-${cat.name}'),
            behavior: HitTestBehavior.opaque,
            onTap:
                () => setState(() => open ? _open.remove(cat) : _open.add(cat)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _body(cat),
            ),
        ],
      ),
    );
  }

  Widget _body(RefineCategory cat) => switch (cat) {
    RefineCategory.finish => _finish(),
    RefineCategory.layout => _layout(),
    RefineCategory.graphic => _graphic(),
    RefineCategory.text => _text(),
    RefineCategory.colour => _colour(),
    RefineCategory.edges => _edges(),
    RefineCategory.effects => _effects(),
    RefineCategory.print => _print(),
  };

  // ── Finish (one-tap presets — undoable) ─────────────────────────────────────
  Widget _finish() {
    final fx = _c.fx;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in StudioController.finishPresets)
          _chip(
            'v2-ft-finish-${_slug(p.$1)}',
            p.$1,
            selected:
                '${fx.toJson()}' == '${p.$2.toJson()}' &&
                (p.$4 == null || _c.colourStrategy == p.$4),
            onTap: () => _c.applyFinishPreset(p),
          ),
      ],
    );
  }

  // ── Layout (flags) ──────────────────────────────────────────────────────────
  Widget _layout() {
    final comp = _c.current.composition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sub('Pattern'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in FillAlgorithm.values)
              _chip(
                'v2-ft-fill-${a.name}',
                _fillLabel(a),
                selected: comp.fillAlgorithm == a,
                onTap: () => _c.setComp(comp.copyWith(fillAlgorithm: a)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _sub('Density'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in Density.values)
              _chip(
                'v2-ft-density-${d.name}',
                _cap(d.name),
                selected: comp.density == d,
                onTap: () => _c.setComp(comp.copyWith(density: d)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _stepper(
          'Copies per country',
          'v2-ft-copies',
          comp.copiesPerCountry,
          1,
          6,
          (v) => _c.setComp(comp.copyWith(copiesPerCountry: v)),
        ),
        _slider(
          'Scatter',
          'v2-ft-jitter',
          comp.jitter,
          0,
          1,
          (v) => _c.setComp(comp.copyWith(jitter: v)),
        ),
        _reset(
          'v2-ft-reset-layout',
          () => _c.setComp(
            comp.copyWith(
              fillAlgorithm: FillAlgorithm.grid,
              density: Density.balanced,
              copiesPerCountry: 1,
              jitter: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Graphic (clipped subjects) ──────────────────────────────────────────────
  Widget _graphic() {
    final clip = _c.current.clip ?? const Clip(shapeId: 'none');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _slider(
          'Size',
          'v2-ft-clip-scale',
          clip.scale,
          0.3,
          1.0,
          (v) => _c.setClip(clip.copyWith(scale: v)),
        ),
        _slider(
          'Rotation',
          'v2-ft-clip-rotation',
          clip.rotationDeg,
          -45,
          45,
          (v) => _c.setClip(clip.copyWith(rotationDeg: v)),
        ),
        _slider(
          'Corner radius',
          'v2-ft-clip-corner',
          clip.cornerRadius,
          0,
          1,
          (v) => _c.setClip(clip.copyWith(cornerRadius: v)),
        ),
        _slider(
          'Feather',
          'v2-ft-clip-feather',
          clip.feather,
          0,
          1,
          (v) => _c.setClip(clip.copyWith(feather: v)),
        ),
        _reset(
          'v2-ft-reset-graphic',
          () => _c.setClip(
            clip.copyWith(
              scale: 1,
              rotationDeg: 0,
              cornerRadius: 0,
              feather: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Text (typography) ───────────────────────────────────────────────────────
  Widget _text() {
    final t = _c.typography;
    final comp = _c.current.composition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sub('Case'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in TextCase.values)
              _chip(
                'v2-ft-case-${c.name}',
                _caseLabel(c),
                selected: t.textCase == c,
                onTap:
                    () => _c.setTypography(
                      Typography(
                        titleStyle: t.titleStyle,
                        textCase: c,
                        placement: t.placement,
                      ),
                    ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _sub('Title position'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in TextPlacement.values)
              _chip(
                'v2-ft-textpos-${p.name}',
                _cap(p.name),
                selected: t.placement == p,
                onTap:
                    () => _c.setTypography(
                      Typography(
                        titleStyle: t.titleStyle,
                        textCase: t.textCase,
                        placement: p,
                      ),
                    ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _chip(
          'v2-ft-statement',
          'Lead with the count',
          selected: comp.statementHero,
          onTap:
              () =>
                  _c.setComp(comp.copyWith(statementHero: !comp.statementHero)),
        ),
        _reset('v2-ft-reset-text', () {
          _c.setTypography(const Typography());
          _c.setComp(comp.copyWith(statementHero: false));
        }),
      ],
    );
  }

  // ── Colour (advanced) ───────────────────────────────────────────────────────
  Widget _colour() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sub('Treatment'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in StudioController.colourTreatments)
              _chip(
                'v2-ft-colour-${_slug(t.$1)}',
                t.$1,
                selected:
                    _c.colourStrategy == t.$2 &&
                    ((t.$3 >= 0.3) == (_c.vintageGrade >= 0.3)),
                onTap: () => _c.setColourTreatment(t),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _slider(
          'Vintage grade',
          'v2-ft-vintage',
          _c.vintageGrade,
          0,
          1,
          _c.setVintageGrade,
        ),
        _reset('v2-ft-reset-colour', () => _c.setVintageGrade(0)),
      ],
    );
  }

  // ── Edges (torn/ragged) ─────────────────────────────────────────────────────
  Widget _edges() {
    final e = _c.edges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sub('Style'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in TearStyle.values)
              _chip(
                'v2-ft-tear-${s.name}',
                _tearLabel(s),
                selected: e.style == s,
                onTap: () => _c.setEdges(e.copyWith(style: s)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _slider(
          'Damage',
          'v2-ft-edge-damage',
          e.edgeDamage,
          0,
          1,
          (v) => _c.setEdges(e.copyWith(edgeDamage: v)),
        ),
        _slider(
          'Rip depth',
          'v2-ft-edge-depth',
          e.maxDepth,
          0,
          0.5,
          (v) => _c.setEdges(e.copyWith(maxDepth: v)),
        ),
        _slider(
          'Fray',
          'v2-ft-edge-fray',
          e.frayAmount,
          0,
          1,
          (v) => _c.setEdges(e.copyWith(frayAmount: v)),
        ),
        _slider(
          'Corner damage',
          'v2-ft-edge-corner',
          e.cornerDamage,
          0,
          1,
          (v) => _c.setEdges(e.copyWith(cornerDamage: v)),
        ),
        _slider(
          'Asymmetry',
          'v2-ft-edge-asym',
          e.asymmetry,
          0,
          1,
          (v) => _c.setEdges(e.copyWith(asymmetry: v)),
        ),
        _reset('v2-ft-reset-edges', () => _c.setEdges(const EdgeTreatment())),
      ],
    );
  }

  // ── Effects (surface treatments; print looks are their own category) ────────
  Widget _effects() {
    final fx = _c.fx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _slider(
          'Distress',
          'v2-ft-fx-distress',
          fx.distress,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(distress: v)),
        ),
        _slider(
          'Grain',
          'v2-ft-fx-grain',
          fx.grain,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(grain: v)),
        ),
        _slider(
          'Fade',
          'v2-ft-fx-fade',
          fx.fade,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(fade: v)),
        ),
        _slider(
          'Cracks',
          'v2-ft-fx-cracks',
          fx.cracks,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(cracks: v)),
        ),
        _slider(
          'Acid wash',
          'v2-ft-fx-acidwash',
          fx.acidWash,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(acidWash: v)),
        ),
        _slider(
          'Tie-dye',
          'v2-ft-fx-tiedye',
          fx.tieDye,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(tieDye: v)),
        ),
        _slider(
          'Shatter',
          'v2-ft-fx-shatter',
          fx.shatter,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(shatter: v)),
        ),
        _slider(
          'Spikes',
          'v2-ft-fx-spikes',
          fx.shatterSpikes,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(shatterSpikes: v)),
        ),
        _slider(
          'Halftone',
          'v2-ft-fx-halftone',
          fx.halftone,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(halftone: v)),
        ),
        _slider(
          'Halftone scale',
          'v2-ft-fx-halftonescale',
          fx.halftoneScale,
          2,
          12,
          (v) => _c.setFx(fx.copyWith(halftoneScale: v)),
        ),
        _slider(
          'Ripple',
          'v2-ft-fx-ripple',
          fx.rippleAmp,
          0,
          1,
          (v) => _c.setFx(fx.copyWith(rippleAmp: v)),
        ),
        _slider(
          'Ripple frequency',
          'v2-ft-fx-ripplefreq',
          fx.rippleFreq,
          2,
          20,
          (v) => _c.setFx(fx.copyWith(rippleFreq: v)),
        ),
        _reset(
          'v2-ft-reset-effects',
          () => _c.setFx(
            fx.copyWith(
              distress: 0,
              grain: 0,
              fade: 0,
              cracks: 0,
              acidWash: 0,
              tieDye: 0,
              shatter: 0,
              shatterSpikes: 0,
              halftone: 0,
              rippleAmp: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Print (mutually-distinct print looks) ───────────────────────────────────
  Widget _print() {
    final fx = _c.fx;
    Effects only(String which) => fx.copyWith(
      riso: which == 'riso' ? 0.9 : 0,
      newsprint: which == 'newsprint' ? 0.9 : 0,
      sunFaded: which == 'sunFaded' ? 0.6 : 0,
      photocopy: which == 'photocopy' ? 0.9 : 0,
    );
    final none =
        fx.riso == 0 &&
        fx.newsprint == 0 &&
        fx.sunFaded == 0 &&
        fx.photocopy == 0;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(
          'v2-ft-print-none',
          'None',
          selected: none,
          onTap: () => _c.setFx(only('none')),
        ),
        _chip(
          'v2-ft-print-riso',
          'Riso',
          selected: fx.riso > 0,
          onTap: () => _c.setFx(only('riso')),
        ),
        _chip(
          'v2-ft-print-newsprint',
          'Newsprint',
          selected: fx.newsprint > 0,
          onTap: () => _c.setFx(only('newsprint')),
        ),
        _chip(
          'v2-ft-print-sunfaded',
          'Sun-faded',
          selected: fx.sunFaded > 0,
          onTap: () => _c.setFx(only('sunFaded')),
        ),
        _chip(
          'v2-ft-print-photocopy',
          'Photocopy',
          selected: fx.photocopy > 0,
          onTap: () => _c.setFx(only('photocopy')),
        ),
      ],
    );
  }

  // ── Shared control widgets ──────────────────────────────────────────────────
  Widget _sub(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      s.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        color: Colors.white38,
      ),
    ),
  );

  Widget _chip(
    String id,
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    key: Key(id),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color:
            selected
                ? Colors.tealAccent.withValues(alpha: 0.2)
                : const Color(0xFF23262C),
        border: Border.all(
          color: selected ? Colors.tealAccent : const Color(0xFF3A3D44),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.tealAccent : Colors.white70,
        ),
      ),
    ),
  );

  Widget _slider(
    String label,
    String id,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        Expanded(
          child: Slider(
            key: Key(id),
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: Colors.tealAccent,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );

  Widget _stepper(
    String label,
    String id,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        _iconBtn(
          '$id-dec',
          Icons.remove,
          value > min ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
        _iconBtn(
          '$id-inc',
          Icons.add,
          value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    ),
  );

  Widget _iconBtn(String id, IconData icon, VoidCallback? onTap) =>
      GestureDetector(
        key: Key(id),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF23262C),
            border: Border.all(color: const Color(0xFF3A3D44)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? Colors.white24 : Colors.white70,
          ),
        ),
      );

  Widget _reset(String id, VoidCallback onTap) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        key: Key(id),
        onTap: onTap,
        child: const Text(
          'Reset',
          style: TextStyle(
            fontSize: 12,
            color: Colors.tealAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  // ── Labels ──────────────────────────────────────────────────────────────────
  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _fillLabel(FillAlgorithm a) => switch (a) {
    FillAlgorithm.grid => 'Grid',
    FillAlgorithm.treemap => 'Treemap',
    FillAlgorithm.diagonalStripe => 'Diagonal',
    FillAlgorithm.voronoi => 'Voronoi',
    FillAlgorithm.tornRegion => 'Torn region',
    FillAlgorithm.noiseBlend => 'Noise blend',
    FillAlgorithm.radial => 'Radial',
    FillAlgorithm.mosaic => 'Mosaic',
  };

  static String _tearLabel(TearStyle s) => switch (s) {
    TearStyle.lightlyWorn => 'Lightly worn',
    TearStyle.ragged => 'Ragged',
    TearStyle.tornCorners => 'Torn corners',
    TearStyle.battleWorn => 'Battle-worn',
    TearStyle.deepRips => 'Deep rips',
    TearStyle.frayed => 'Frayed',
    TearStyle.asymmetricTear => 'Asymmetric',
    TearStyle.heavyEdgeDamage => 'Heavy damage',
  };

  static String _caseLabel(TextCase c) => switch (c) {
    TextCase.upper => 'UPPER',
    TextCase.title => 'Title',
    TextCase.lower => 'lower',
    TextCase.asIs => 'As is',
  };
}
