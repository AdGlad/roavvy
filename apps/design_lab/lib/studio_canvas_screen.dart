import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;

import 'preference_survey.dart';

/// M3 — **Studio Canvas** prototype (docs/product/tshirt-creation-experience.md §9).
///
/// A single-screen, shirt-first flow that validates the proposed 6-phase
/// customer experience on top of the M2 single-axis re-roll engine:
///
///  * **Instant hero** — the shirt is generated on open and stays large + always
///    visible; every interaction re-renders it live.
///  * **Decision deck** — five chips (Direction / Vibe / Focus / Colour / Words),
///    one per [DesignAxis]. Tapping a chip re-rolls only that axis via
///    [LabShowcaseGenerator.reroll] with a fresh seed, so the rest of the design
///    is untouched.
///  * **Alternatives tray** — for the most-recently-touched axis, a strip of
///    thumbnails produced by [reroll] with different seeds. Tapping one commits
///    it; until then the change is non-destructive.
///  * **Lock** — long-press a chip (or tap its lock badge) to pin that axis;
///    the global "Surprise me" then calls [LabShowcaseGenerator.rerollUnlocked]
///    so locked axes stay byte-identical.
///  * **Breadcrumb / undo** — every commit pushes the previous recipe onto a
///    history stack; the back control restores it instantly from the stored
///    recipe (no regeneration).
///
/// This is a UX prototype living only in the macOS Design Lab — it does not
/// touch the production mobile app or the generator itself.
class StudioCanvasScreen extends StatefulWidget {
  const StudioCanvasScreen({
    super.key,
    required this.generator,
    required this.service,
    required this.designContext,
    this.initialSeed = 1,
    this.preferences = DesignPreferences.neutral,
    this.learner = const PreferenceLearner(),
    this.library,
    this.persistence,
    this.onPreferencesChanged,
  });

  /// The generator that both seeds the hero and performs every re-roll. Its
  /// config (style/genre/silhouettes) must match the hero for faithful splices.
  final LabShowcaseGenerator generator;

  /// Renders recipes to cached preview/print images.
  final RenderService service;

  /// The travel/flag context the hero is generated from.
  final DesignContext designContext;

  /// Master seed for the opening hero.
  final int initialSeed;

  // ── M4: preference learning (docs/product/tshirt-creation-experience.md §19) ──
  //
  // The Studio Canvas learns from the customer's creative decisions the same way
  // the batch Lab does: every authoring action feeds a [PreferenceSignal] into
  // the shared [PreferenceLearner], and explicit ♥/✕ actions also update the
  // reproducible [PersistentDesignLibrary]. All of this is additive — the flow
  // works identically when these are left at their defaults / null.

  /// Starting preferences (seeded from whatever the Lab has already learned).
  final DesignPreferences preferences;

  /// The learner that folds each signal into [preferences].
  final PreferenceLearner learner;

  /// Optional reproducible library — ♥ Save likes into it, tray ✕ rejects.
  final PersistentDesignLibrary? library;

  /// Optional disk persistence — preferences are saved after every update.
  final PreferencePersistence? persistence;

  /// Called with the new preferences after each update so the host (main.dart)
  /// can keep its in-memory copy in sync when the customer returns.
  final ValueChanged<DesignPreferences>? onPreferencesChanged;

  @override
  State<StudioCanvasScreen> createState() => StudioCanvasScreenState();
}

/// Public so widget tests can reach the current recipe / lock state via a
/// [GlobalKey]. The UX itself never depends on this being public.
class StudioCanvasScreenState extends State<StudioCanvasScreen> {
  /// Display labels + icons for the five creative axes (the decision deck).
  static const List<(DesignAxis, String, IconData)> _deck = [
    (DesignAxis.direction, 'Direction', Icons.explore),
    (DesignAxis.vibe, 'Vibe', Icons.auto_awesome),
    (DesignAxis.focus, 'Focus', Icons.crop_free),
    (DesignAxis.colour, 'Colour', Icons.palette),
    (DesignAxis.words, 'Words', Icons.title),
  ];

  // ── Session controller (shared design_studio orchestration layer) ───────────
  // All recipe/session state + mutations live in [StudioController] (portable,
  // no Flutter widget). This screen is a thin macOS host: it creates the
  // controller from its injected deps, rebuilds on notifications, and renders.
  late final StudioController _c;

  /// Whether the contextual Refine panel (Tier-3 form controls) is open (UI-only).
  bool _showAdjust = false;

  /// The active Refine category (UI-only view state).
  RefineCategory _refineCat = RefineCategory.finish;

  @override
  void initState() {
    super.initState();
    _c = StudioController(
      generator: widget.generator,
      service: widget.service,
      designContext: widget.designContext,
      initialSeed: widget.initialSeed,
      preferences: widget.preferences,
      learner: widget.learner,
      library: widget.library,
      savePreferences: widget.persistence == null
          ? null
          : (p) => widget.persistence!.savePreferences(p),
      onPreferencesChanged: widget.onPreferencesChanged,
    )..addListener(_onControllerChanged);
    // The initial hero being shown is a soft positive signal; emit after the
    // first frame so a listener never fires mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.markViewed();
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ── Test-facing read-only accessors (delegate to the controller) ────────────
  DesignRecipe get currentRecipe => _c.current;
  DesignContext get effectiveContext => _c.context;
  Set<DesignAxis> get lockedAxes => _c.locked;
  int get historyLength => _c.history.length;
  List<DesignRecipe> get alternatives => _c.alternatives;
  DesignAxis? get activeAxis => _c.activeAxis;
  DesignPreferences get currentPreferences => _c.preferences;

  // ── Thin forwarders so the build methods below read as before ───────────────
  DesignRecipe get _current => _c.current;
  DesignRecipe get _hero => _c.hero;
  DesignRecipe get _frontFace => _c.frontFace;
  DesignRecipe get _heroRecipe => _c.heroRecipe;
  bool get _onFront => _c.onFront;
  FrontFit get _frontFit => _c.frontFit;
  bool get _chestRight => _c.chestRight;
  FrontArt get _frontArt => _c.frontArt;
  bool get _ribbonAllCountries => _c.ribbonAllCountries;
  int get _subjectIndex => _c.subjectIndex;
  StudioDetail get _detail => _c.detail;
  DesignAxis? get _activeAxis => _c.activeAxis;
  List<DesignRecipe> get _alternatives => _c.alternatives;
  List<String> get _titleIdeas => _c.titleIdeas;
  List<DesignRecipe> get _history => _c.history;
  Set<DesignAxis> get _locked => _c.locked;
  LabStyle? get _currentStyle => _c.currentStyle;
  String get _currentTitle => _c.currentTitle;
  String get _subjectLabel => _c.subjectLabel;
  Effects get _fx => _c.fx;
  bool get _sourceTrips => _c.sourceTrips;
  int get _yearLo => _c.yearLo;
  int get _yearHi => _c.yearHi;

  void _save() => _c.save();
  void _surprise() => _c.surprise();
  void _undo() => _c.undo();
  void _setSize(SizeClass s) => _c.setSize(s);
  void _setOrientation(Orientation o) => _c.setOrientation(o);
  void _setGarment(String hex) => _c.setGarment(hex);
  void _onChipTap(DesignAxis a) => _c.onChipTap(a);
  void _onAlternativeTap(int i, DesignRecipe alt) => _c.onAlternativeTap(i, alt);
  void _onStyleTap(LabStyle s, DesignRecipe r) => _c.onStyleTap(s, r);
  void _applyDetail(StudioDetail d) => _c.applyDetail(d);
  void _applyFinishPreset((String, Effects, double, ColourStrategy?) p) =>
      _c.applyFinishPreset(p);
  void _dismissAlternative(int i) => _c.dismissAlternative(i);
  void _toggleLock(DesignAxis a) => _c.toggleLock(a);
  void _setFrontArt(FrontArt a) => _c.setFrontArt(a);
  void _setRibbonCoverage(bool b) => _c.setRibbonCoverage(b);
  void _setTitle(String v) => _c.setTitle(v);
  void _setFx(Effects fx) => _c.setFx(fx);
  void _setComp(Composition comp) => _c.setComp(comp);
  void _setClip(Clip clip) => _c.setClip(clip);
  void _applyLive(DesignRecipe r) => _c.applyLive(r);
  List<(LabStyle, DesignRecipe)> _vibeStyleOptions() => _c.vibeStyleOptions();
  List<(ClipShape, String)> _silhouetteOptions() => _c.silhouetteOptions();
  String _silhouetteLabel(ClipShape k, String slug) =>
      _c.silhouetteLabel(k, slug);
  List<String> _reviewSpec() => _c.reviewSpec();
  Rect _frontPrintRect() => _c.frontPrintRect();
  List<RefineCategory> _refineCategories() => _c.refineCategories();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Canvas'),
        backgroundColor: const Color(0xFF16181D),
        actions: [
          IconButton(
            key: const Key('studio-adjust-toggle'),
            tooltip: 'Fine tune (Refine)',
            color: _showAdjust ? Colors.tealAccent : null,
            icon: const Icon(Icons.tune),
            onPressed: () => setState(() => _showAdjust = !_showAdjust),
          ),
          IconButton(
            key: const Key('studio-save'),
            tooltip: 'Save to favourites',
            icon: const Icon(Icons.favorite_border),
            onPressed: _save,
          ),
          IconButton(
            key: const Key('studio-review'),
            tooltip: 'Review & save',
            icon: const Icon(Icons.checklist),
            onPressed: _showReview,
          ),
          IconButton(
            key: const Key('studio-undo'),
            tooltip: _history.isEmpty ? 'Nothing to undo' : 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _history.isEmpty ? null : _undo,
          ),
          TextButton.icon(
            key: const Key('studio-surprise'),
            icon: const Icon(Icons.casino, size: 18),
            label: const Text('Remix'),
            onPressed: _surprise,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _breadcrumb(),
          // Tier-1 fixed controls — always available, survive Style/Direction.
          _formatBar(),
          // Instant hero — the shirt is the star, always visible + centred. The
          // back shows the full main design; the front shows the artwork placed
          // on a shirt-front at the chosen print position (mobile parity).
          Expanded(
            child: Container(
              color: const Color(0xFF0E0F12),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: _onFront
                  ? _GarmentFrontPreview(
                      key: const Key('studio-hero'),
                      service: widget.service,
                      design: _frontFace,
                      printRect: _frontPrintRect(),
                      garmentColour: _current.palette?.garmentColour,
                    )
                  : _HeroCanvas(
                      key: const Key('studio-hero'),
                      service: widget.service,
                      recipe: _heroRecipe,
                    ),
            ),
          ),
          if (_activeAxis == DesignAxis.vibe)
            _vibeStyleTray()
          else if (_activeAxis == DesignAxis.words)
            _wordsPanel()
          else if (_activeAxis != null)
            _alternativesTray(),
          // Detail sub-step: only for the Flags subject — the shape flags fill.
          if (_c.hasTrips) _travelRow(),
          if (_subjectIndex == 0) _detailRow(),
          if (_showAdjust) _adjustPanel(),
          _decisionDeck(),
        ],
      ),
    );
  }

  /// The Flags "Detail" sub-row (Grid / Map / Animals / Landmarks / Heart /
  /// Circle) — the shape the flags fill. Shown only when the subject is Flags.
  Widget _detailRow() {
    const items = [
      (StudioDetail.grid, 'Grid'),
      (StudioDetail.map, 'Map'),
      (StudioDetail.animals, 'Animals'),
      (StudioDetail.plants, 'Plants'),
      (StudioDetail.landmarks, 'Landmarks'),
      (StudioDetail.heart, 'Heart'),
      (StudioDetail.circle, 'Circle'),
    ];
    return Container(
      color: const Color(0xFF16181D),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          const Text('Detail',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (d, label) in items)
                  ChoiceChip(
                    key: Key('studio-detail-${d.name}'),
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: _detail == d,
                    onSelected: (_) => _applyDetail(d),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finishRow() => Row(children: [
        _miniLabel('Finish'),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in StudioController.finishPresets)
                ActionChip(
                  key: Key('studio-finish-${p.$1}'),
                  label: Text(p.$1, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _applyFinishPreset(p),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ]);

  /// The contextual **Refine** panel (storyboard "Fine Tune"): a category menu
  /// across the top, then a focused body for the active category — instead of one
  /// long scroll. The category set is contextual to the current subject/detail so
  /// advanced controls never permanently clutter the Studio, and NO control is
  /// dropped: every axis of the old single panel lives under exactly one category.
  Widget _adjustPanel() {
    final cats = _refineCategories();
    // Clamp locally without mutating state during build.
    final cat = cats.contains(_refineCat) ? _refineCat : cats.first;
    return Container(
      color: const Color(0xFF16181D),
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _refineMenu(cats, cat),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _refineBody(cat),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _refineMenu(List<RefineCategory> cats, RefineCategory active) =>
      SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (_, index) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final c = cats[i];
            final on = c == active;
            return GestureDetector(
              key: Key('studio-refine-${c.name}'),
              onTap: () => setState(() => _refineCat = c),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: on
                      ? Colors.tealAccent.withValues(alpha: 0.18)
                      : const Color(0xFF23262C),
                  border: Border.all(
                      color: on ? Colors.tealAccent : const Color(0xFF3A3D44)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(c.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: on ? Colors.tealAccent : Colors.white70)),
              ),
            );
          },
        ),
      );

  /// The focused control body for one Refine category. Each branch owns exactly
  /// the controls the old single panel grouped under that heading.
  List<Widget> _refineBody(RefineCategory cat) {
    switch (cat) {
      case RefineCategory.finish:
        return [_finishRow()];
      case RefineCategory.layout:
        return _layoutControls();
      case RefineCategory.graphic:
        return _graphicControls();
      case RefineCategory.text:
        return _textControls();
      case RefineCategory.colour:
        return _colourControls();
      case RefineCategory.edges:
        return _edgeControls();
      case RefineCategory.effects:
        return _effectControls();
      case RefineCategory.print:
        return _printControls();
    }
  }

  /// Grid arrangement — Flags subject.
  List<Widget> _layoutControls() {
    final comp = _current.composition;
    return [
      _fillDropdown(comp),
      _adjSlider('Copies', comp.copiesPerCountry.toDouble(),
          (v) => _setComp(comp.copyWith(copiesPerCountry: v.round().clamp(1, 8))),
          max: 8),
      _adjSlider(
          'Scatter', comp.jitter, (v) => _setComp(comp.copyWith(jitter: v))),
    ];
  }

  /// Shape / clip / silhouette / passport — the "Graphic" bucket.
  List<Widget> _graphicControls() {
    final rows = <Widget>[];
    final genre = StudioController.subjects[_subjectIndex].$1;

    if (genre == LabGenre.passport && _current.clip != null) {
      final clip = _current.clip!;
      rows
        // Passport stamp size (mobile parity: 50–150%). The renderer reads
        // clip.scale as the passport stampScale (clip_stage._resolveInk path).
        ..add(_adjSlider('Stamp size', clip.scale <= 0 ? 1.0 : clip.scale,
            (v) => _setClip(clip.copyWith(scale: v)),
            min: 0.5, max: 1.5))
        ..add(_adjSlider('Scatter', clip.scatter,
            (v) => _setClip(clip.copyWith(scatter: v))))
        // Multi = each stamp in its country's flag colours; Mono = a single ink
        // (auto black/white for the chosen t-shirt colour).
        ..add(_choiceRow(
            'Colour',
            const ['Multi', 'Mono'],
            (clip.ink == null || clip.ink == 'flag') ? 'Multi' : 'Mono',
            (v) => _setClip(clip.copyWith(ink: v == 'Multi' ? 'flag' : 'mono'))))
        ..add(_choiceRow(
            'Stamps',
            const ['entryExit', 'entryOnly', 'exitOnly'],
            clip.stampMode ?? 'entryExit',
            (v) => _setClip(clip.copyWith(stampMode: v))));
    }

    // Full silhouette list for the selected countries — pick a specific one.
    final silClip = _current.clip;
    if (silClip != null && StudioController.silhouetteShapeIds.contains(silClip.shapeId)) {
      final options = _silhouetteOptions();
      if (options.isNotEmpty) {
        final value = options.any((o) => o.$2 == silClip.code)
            ? silClip.code
            : options.first.$2;
        rows.add(Row(children: [
          const SizedBox(
              width: 82,
              child: Text('Pick',
                  style: TextStyle(fontSize: 11, color: Colors.white70))),
          Expanded(
            child: DropdownButton<String>(
              key: const Key('studio-silhouette-pick'),
              isExpanded: true,
              value: value,
              dropdownColor: const Color(0xFF23262C),
              style: const TextStyle(fontSize: 12, color: Colors.white),
              items: [
                for (final (k, slug) in options)
                  DropdownMenuItem(
                      value: slug, child: Text(_silhouetteLabel(k, slug))),
              ],
              onChanged: (slug) {
                if (slug == null) return;
                final kind = options.firstWhere((o) => o.$2 == slug).$1;
                _setClip(Clip.shape(kind, code: slug));
              },
            ),
          ),
        ]));
      }
    }

    // Shape transforms for a clipped Detail (map / silhouette / heart / circle /
    // text) — passport has its own scatter above.
    final clip = _current.clip;
    if (clip != null &&
        clip.shapeId != 'none' &&
        clip.shapeId != 'passportPage') {
      rows
        ..add(_adjSlider('Size', clip.scale,
            (v) => _setClip(clip.copyWith(scale: v)),
            min: 0.25, max: 1.4))
        ..add(_adjSlider('Rotation', clip.rotationDeg,
            (v) => _setClip(clip.copyWith(rotationDeg: v)),
            min: -45, max: 45))
        ..add(_adjSlider('Corner', clip.cornerRadius,
            (v) => _setClip(clip.copyWith(cornerRadius: v))))
        ..add(_adjSlider('Feather', clip.feather,
            (v) => _setClip(clip.copyWith(feather: v))));
    }
    return rows;
  }

  /// Custom text — type your own word for a text (flag-filled letters) subject.
  List<Widget> _textControls() {
    final clip = _current.clip;
    final text = clip?.shapeId == 'text' ? (clip?.text ?? '') : '';
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TextFormField(
          key: const Key('studio-text-input'),
          initialValue: text,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Your word (ROAM / a name)',
            hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          onChanged: (v) {
            final base =
                clip?.shapeId == 'text' ? clip! : const Clip(shapeId: 'text');
            _setClip(base.copyWith(text: v));
          },
        ),
      ),
    ];
  }

  List<Widget> _colourControls() {
    final pal = _current.palette ?? const Palette();
    return [
      _choiceRow(
          'Treatment',
          const ['flagDerived', 'monochrome', 'duotone', 'garmentAware'],
          pal.strategy.name,
          (v) => _applyLive(_current.copyWith(
              palette: pal.copyWith(strategy: ColourStrategy.fromId(v))))),
      _adjSlider('Vintage', pal.vintageGrade,
          (v) => _applyLive(
              _current.copyWith(palette: pal.copyWith(vintageGrade: v)))),
    ];
  }

  /// Torn / ripped edges. Touching any control opts the design into a torn edge
  /// (materialised from defaults); set Damage to 0 for a clean edge.
  List<Widget> _edgeControls() {
    final edge = _current.edgeTreatment ?? const EdgeTreatment();
    return [
      _choiceRow(
          'Style',
          const ['ragged', 'frayed', 'tornCorners', 'deepRips'],
          edge.style.name,
          (v) => _applyLive(_current.copyWith(
              edgeTreatment: edge.copyWith(style: TearStyle.fromId(v))))),
      _adjSlider('Damage', edge.edgeDamage,
          (v) => _applyLive(
              _current.copyWith(edgeTreatment: edge.copyWith(edgeDamage: v)))),
      _adjSlider('Corners', edge.cornerDamage,
          (v) => _applyLive(_current.copyWith(
              edgeTreatment: edge.copyWith(cornerDamage: v)))),
      _adjSlider('Fray', edge.frayAmount,
          (v) => _applyLive(
              _current.copyWith(edgeTreatment: edge.copyWith(frayAmount: v)))),
    ];
  }

  List<Widget> _effectControls() {
    final fx = _fx;
    return [
      _adjSlider('Distress', fx.distress,
          (v) => _setFx(fx.copyWith(distress: v))),
      _adjSlider('Grain', fx.grain, (v) => _setFx(fx.copyWith(grain: v))),
      _adjSlider('Fade', fx.fade, (v) => _setFx(fx.copyWith(fade: v))),
      _adjSlider('Cracks', fx.cracks, (v) => _setFx(fx.copyWith(cracks: v))),
      _adjSlider('Acid wash', fx.acidWash,
          (v) => _setFx(fx.copyWith(acidWash: v))),
      _adjSlider('Tie-dye', fx.tieDye, (v) => _setFx(fx.copyWith(tieDye: v))),
      _adjSlider('Shatter', fx.shatter, (v) => _setFx(fx.copyWith(shatter: v))),
      _adjSlider('Shatter spikes', fx.shatterSpikes,
          (v) => _setFx(fx.copyWith(shatterSpikes: v))),
      _adjSlider('Halftone', fx.halftone,
          (v) => _setFx(fx.copyWith(halftone: v))),
      _adjSlider('Halftone scale', fx.halftoneScale,
          (v) => _setFx(fx.copyWith(halftoneScale: v)),
          min: 2, max: 12),
      _adjSlider('Ripple', fx.rippleAmp,
          (v) => _setFx(fx.copyWith(rippleAmp: v))),
      _adjSlider('Ripple freq', fx.rippleFreq,
          (v) => _setFx(fx.copyWith(rippleFreq: v)),
          min: 1, max: 16),
    ];
  }

  List<Widget> _printControls() {
    final fx = _fx;
    return [
      _adjSlider('Riso', fx.riso, (v) => _setFx(fx.copyWith(riso: v))),
      _adjSlider('Newsprint', fx.newsprint,
          (v) => _setFx(fx.copyWith(newsprint: v))),
      _adjSlider('Sun-faded', fx.sunFaded,
          (v) => _setFx(fx.copyWith(sunFaded: v))),
      _adjSlider('Photocopy', fx.photocopy,
          (v) => _setFx(fx.copyWith(photocopy: v))),
    ];
  }

  Widget _adjSlider(String label, double value, ValueChanged<double> onChanged,
          {double min = 0.0, double max = 1.0}) =>
      Row(children: [
        SizedBox(
            width: 82,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ]);

  Widget _fillDropdown(Composition comp) => Row(children: [
        const SizedBox(
            width: 82,
            child: Text('Fill',
                style: TextStyle(fontSize: 11, color: Colors.white70))),
        DropdownButton<FillAlgorithm>(
          key: const Key('studio-adjust-fill'),
          value: comp.fillAlgorithm ?? FillAlgorithm.grid,
          dropdownColor: const Color(0xFF23262C),
          style: const TextStyle(fontSize: 12, color: Colors.white),
          items: [
            for (final f in FillAlgorithm.values)
              DropdownMenuItem(value: f, child: Text(f.name)),
          ],
          onChanged: (f) {
            if (f != null) _setComp(comp.copyWith(fillAlgorithm: f));
          },
        ),
      ]);

  Widget _choiceRow(String label, List<String> options, String selected,
          ValueChanged<String> onSelected) =>
      Row(children: [
        SizedBox(
            width: 82,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70))),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: [
              for (final o in options)
                ChoiceChip(
                  key: Key('studio-adjust-$label-$o'),
                  label: Text(o, style: const TextStyle(fontSize: 11)),
                  selected: selected == o,
                  onSelected: (_) => onSelected(o),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ]);

  Widget _formatBar() {
    final comp = _current.composition;
    final garment = _current.palette?.garmentColour;
    return Container(
      color: const Color(0xFF1B1E24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _miniLabel('Aspect'),
          for (final (o, lbl) in const [
            (Orientation.portrait, 'Portrait'),
            (Orientation.landscape, 'Landscape'),
            (Orientation.square, 'Square'),
          ])
            _pill('aspect-${o.name}', lbl, comp.orientation == o,
                () => _setOrientation(o)),
          _divider(),
          _miniLabel('Size'),
          for (final (s, lbl) in const [
            (SizeClass.small, 'S'),
            (SizeClass.medium, 'M'),
            (SizeClass.large, 'L'),
          ])
            _pill('size-${s.name}', lbl, comp.sizeClass == s, () => _setSize(s)),
          _divider(),
          _miniLabel('Colour'),
          for (final (hex, name) in StudioController.garments)
            _swatch(hex, name, garment == hex),
          _divider(),
          _miniLabel('Side'),
          // The hero/main design lives on the BACK by default; the FRONT is the
          // small chest ribbon (or a complement).
          _pill('side-back', 'Back', !_onFront,
              () => _c.setSide(false)),
          _pill('side-front', 'Front', _onFront,
              () => _c.setSide(true)),
          // Front-only: the print fit (full / chest / none), the chest side, and
          // where the front artwork comes from.
          if (_onFront) ...[
            _divider(),
            _miniLabel('Front'),
            _pill('front-fit-full', 'Full', _frontFit == FrontFit.full,
                () => _c.setFrontFit(FrontFit.full)),
            _pill('front-fit-chest', 'Chest', _frontFit == FrontFit.chest,
                () => _c.setFrontFit(FrontFit.chest)),
            _pill('front-fit-none', 'None', _frontFit == FrontFit.none,
                () => _c.setFrontFit(FrontFit.none)),
            if (_frontFit == FrontFit.chest) ...[
              const SizedBox(width: 6),
              _pill('front-chest-left', 'Left', !_chestRight,
                  () => _c.setChestSide(false)),
              _pill('front-chest-right', 'Right', _chestRight,
                  () => _c.setChestSide(true)),
            ],
            _divider(),
            _miniLabel('Art'),
            _pill('front-art-ribbon', 'Ribbon',
                _frontArt == FrontArt.ribbon, () => _setFrontArt(FrontArt.ribbon)),
            _pill('front-art-complement', 'Complement',
                _frontArt == FrontArt.complement,
                () => _setFrontArt(FrontArt.complement)),
            _pill('front-art-match', 'Match back',
                _frontArt == FrontArt.matchBack,
                () => _setFrontArt(FrontArt.matchBack)),
            // Ribbon coverage (mobile "Selected vs All").
            if (_frontArt == FrontArt.ribbon) ...[
              const SizedBox(width: 6),
              _pill('front-ribbon-selected', 'Selected', !_ribbonAllCountries,
                  () => _setRibbonCoverage(false)),
              _pill('front-ribbon-all', 'All', _ribbonAllCountries,
                  () => _setRibbonCoverage(true)),
            ],
          ],
        ]),
      ),
    );
  }

  /// Travel-data controls (only when the context carries trips): Source
  /// (Countries vs Trips) + a year-range filter. Mirrors the mobile Flag-source
  /// and trip-year controls.
  Widget _travelRow() {
    final span = _c.span!;
    final minY = span.start!.year, maxY = span.end!.year;
    return Container(
      color: const Color(0xFF16181D),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(children: [
        const Text('Trips',
            style: TextStyle(fontSize: 11, color: Colors.white38)),
        const SizedBox(width: 10),
        _pill('source-countries', 'Countries', !_sourceTrips,
            () => _c.setSource(false)),
        _pill('source-trips', 'Trips', _sourceTrips,
            () => _c.setSource(true)),
        const SizedBox(width: 10),
        if (maxY > minY)
          Expanded(
            child: RangeSlider(
              values: RangeValues(_yearLo.toDouble(), _yearHi.toDouble()),
              min: minY.toDouble(),
              max: maxY.toDouble(),
              divisions: maxY - minY,
              labels: RangeLabels('$_yearLo', '$_yearHi'),
              onChanged: (v) =>
                  _c.previewYear(v.start.round(), v.end.round()),
              onChangeEnd: (_) => _c.rebuildContext(),
            ),
          )
        else
          Text('$minY',
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
    );
  }

  Widget _miniLabel(String s) => Padding(
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
          key: Key('studio-$id'),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.tealAccent.withValues(alpha: 0.2)
                  : const Color(0xFF23262C),
              border: Border.all(
                  color:
                      selected ? Colors.tealAccent : const Color(0xFF3A3D44)),
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
          key: Key('studio-garment-$name'),
          onTap: () => _setGarment(hex),
          child: Container(
            width: 22,
            height: 22,
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

  Widget _breadcrumb() {
    return Container(
      color: const Color(0xFF16181D),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            _history.isEmpty
                ? 'Fresh design'
                : '${_history.length} step${_history.length == 1 ? '' : 's'} back available',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const Spacer(),
          if (_locked.isNotEmpty)
            Text(
              'Locked: ${_locked.map(_labelFor).join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.tealAccent),
            ),
        ],
      ),
    );
  }

  static String _labelFor(DesignAxis a) =>
      _deck.firstWhere((e) => e.$1 == a).$2;

  /// The "Pick a Vibe" tray — 13 NAMED style thumbnails (the current design in
  /// each [LabStyle]), the storyboard's signature "primary choices feel creative
  /// and visual" step. The current style is highlighted; tapping restyles live.
  Widget _vibeStyleTray() {
    final options = _vibeStyleOptions();
    final current = _currentStyle;
    return Container(
      color: const Color(0xFF1A1D22),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pick a vibe  ·  tap a style',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 6),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (style, styled) = options[i];
                final on = style == current;
                return GestureDetector(
                  key: Key('studio-vibe-${style.name}'),
                  onTap: () => _onStyleTap(style, styled),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 92,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: on
                                  ? Colors.tealAccent
                                  : const Color(0xFF2A2D33),
                              width: on ? 2 : 1),
                          color: const Color(0xFFF2F2F2),
                        ),
                        child: _HeroCanvas(
                          service: widget.service,
                          recipe: styled,
                          longSide: 84,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(style.label,
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  on ? Colors.tealAccent : Colors.white60)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The "Add your words" editor (storyboard step 5): an editable printed-title
  /// field plus tappable AI/offline title suggestions. Editing is live; "Suggest
  /// titles" regenerates the ideas.
  Widget _wordsPanel() {
    return Container(
      color: const Color(0xFF1A1D22),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add your words  ·  your story in words',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextFormField(
                key: const Key('studio-title-input'),
                initialValue: _currentTitle,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Your title (e.g. WANDERED FAR & WIDE)',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onChanged: _setTitle,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: const Key('studio-suggest-titles'),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Suggest', style: TextStyle(fontSize: 12)),
              onPressed: _c.suggestTitles,
            ),
          ]),
          if (_titleIdeas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < _titleIdeas.length; i++)
                  ActionChip(
                    key: Key('studio-title-idea-$i'),
                    label: Text(_titleIdeas[i],
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () => _setTitle(_titleIdeas[i]),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _alternativesTray() {
    final axis = _activeAxis!;
    return Container(
      color: const Color(0xFF1A1D22),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_labelFor(axis)} alternatives  ·  tap to keep',
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 6),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _alternatives.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final alt = _alternatives[i];
                return Stack(
                  children: [
                    GestureDetector(
                      key: Key('studio-alt-$i'),
                      onTap: () => _onAlternativeTap(i, alt),
                      child: Container(
                        width: 96,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF2A2D33)),
                          color: const Color(0xFFF2F2F2),
                        ),
                        child: _HeroCanvas(
                          service: widget.service,
                          recipe: alt,
                          longSide: 96,
                        ),
                      ),
                    ),
                    // Subtle explicit reject: prefer an explicit ✕ over inferring
                    // dislike from what the customer didn't pick.
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        key: Key('studio-alt-dismiss-$i'),
                        onTap: () => _dismissAlternative(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _decisionDeck() {
    // The three-phase spine (Instant → Make It Yours → Fine Tune): the hero above
    // is the Instant design; this deck is Make It Yours; the Fine-tune (Refine)
    // button opens the deeper controls. Labelling it keeps the creative choices
    // reading as a guided journey rather than a flat control row.
    return Container(
      color: const Color(0xFF16181D),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text('MAKE IT YOURS',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                    letterSpacing: 1.5)),
            const Spacer(),
            TextButton.icon(
              key: const Key('studio-finetune'),
              icon: const Icon(Icons.tune, size: 15),
              label: const Text('Fine tune', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor:
                      _showAdjust ? Colors.tealAccent : Colors.white54),
              onPressed: () => setState(() => _showAdjust = !_showAdjust),
            ),
          ]),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (axis, label, icon) in _deck)
                _AxisChip(
                  key: Key('studio-chip-${axis.key}'),
                  label: axis == DesignAxis.direction ? _subjectLabel : label,
                  icon: icon,
                  locked: _locked.contains(axis),
                  active: _activeAxis == axis,
                  onTap: () => _onChipTap(axis),
                  onToggleLock: () => _toggleLock(axis),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Review & Save (storyboard step 8): front + back preview, an at-a-glance
  /// spec summary, Save to Library, and an explicit Add-to-cart placeholder
  /// (commerce lives in the mobile app / milestone M8, not the Lab).
  void _showReview() {
    final garment = _current.palette?.garmentColour;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16181D),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review & save',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              _reviewThumbChild(
                'Front',
                _GarmentFrontPreview(
                  service: widget.service,
                  design: _frontFace,
                  printRect: _frontPrintRect(),
                  garmentColour: garment,
                ),
              ),
              const SizedBox(width: 12),
              _reviewThumb('Back', _hero),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _reviewSpec())
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF23262C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                  ),
              ],
            ),
            if (_currentTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('“$_currentTitle”',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('studio-review-save'),
                  icon: const Icon(Icons.favorite, size: 18),
                  label: const Text('Save to library'),
                  onPressed: () {
                    _save();
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('studio-review-cart'),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  // Commerce is a mobile/production (M8) concern — the Lab
                  // prototype stops at Save, so this is explicitly disabled.
                  onPressed: null,
                  label: const Text('Add to cart (mobile)'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _reviewThumb(String label, DesignRecipe recipe) => _reviewThumbChild(
      label, _HeroCanvas(service: widget.service, recipe: recipe, longSide: 132));

  Widget _reviewThumbChild(String label, Widget child) => Expanded(
        child: Column(
          children: [
            Container(
              height: 132,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2A2D33)),
                color: const Color(0xFFF2F2F2),
              ),
              child: child,
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
      );
}

/// A decision-deck chip: tap re-rolls its axis; long-press (or the lock badge)
/// pins it. The badge doubles as the lock-state indicator.
class _AxisChip extends StatelessWidget {
  const _AxisChip({
    super.key,
    required this.label,
    required this.icon,
    required this.locked,
    required this.active,
    required this.onTap,
    required this.onToggleLock,
  });

  final String label;
  final IconData icon;
  final bool locked;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onToggleLock,
      child: InputChip(
        avatar: Icon(icon, size: 16, color: active ? Colors.tealAccent : null),
        label: Text(label),
        onPressed: onTap,
        showCheckmark: false,
        selected: active,
        selectedColor: const Color(0xFF23343A),
        deleteIcon: Icon(
          locked ? Icons.lock : Icons.lock_open,
          size: 16,
          color: locked ? Colors.tealAccent : Colors.white38,
        ),
        onDeleted: onToggleLock,
        tooltip: 'Tap to re-roll · long-press to ${locked ? 'unlock' : 'lock'}',
      ),
    );
  }
}

/// Renders a recipe to a cached image (via [RenderService]) and shows it. Loads
/// asynchronously; shows a spinner until the first frame is ready. Re-loads when
/// the recipe identity changes so the hero updates live.
class _HeroCanvas extends StatefulWidget {
  const _HeroCanvas({
    super.key,
    required this.service,
    required this.recipe,
    this.longSide = 900,
  });

  final RenderService service;
  final DesignRecipe recipe;
  final int longSide;

  @override
  State<_HeroCanvas> createState() => _HeroCanvasState();
}

class _HeroCanvasState extends State<_HeroCanvas> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _HeroCanvas old) {
    super.didUpdateWidget(old);
    if (old.recipe.recipeId != widget.recipe.recipeId) _load();
  }

  Future<void> _load() async {
    final img = await widget.service.imageFor(widget.recipe, widget.longSide);
    if (mounted) setState(() => _image = img);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return RawImage(image: img, fit: BoxFit.contain);
  }
}

/// Previews the shirt **front**: the [design] placed on a shirt-front-shaped
/// area at [printRect] (fractions of the front image), so the artwork lands in
/// the same place the mobile app prints it. [printRect] == [Rect.zero] renders a
/// blank front. The board is filled with [garmentColour] so the preview reads as
/// the actual garment.
class _GarmentFrontPreview extends StatelessWidget {
  const _GarmentFrontPreview({
    super.key,
    required this.service,
    required this.design,
    required this.printRect,
    this.garmentColour,
  });

  final RenderService service;
  final DesignRecipe design;
  final Rect printRect;
  final String? garmentColour;

  static Color _parse(String? hex) {
    var h = hex?.replaceAll('#', '').trim();
    if (h == null) return const Color(0xFFF2F2F2);
    if (h.length == 6) h = 'ff$h';
    final v = h.length == 8 ? int.tryParse(h, radix: 16) : null;
    return v == null ? const Color(0xFFF2F2F2) : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final blank = printRect == Rect.zero;
    return AspectRatio(
      // Portrait, roughly a T-shirt front's proportions.
      aspectRatio: 0.82,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: _parse(garmentColour),
              border: Border.all(color: const Color(0xFF2A2D33)),
            ),
            child: blank
                ? const Center(
                    child: Text('Blank front',
                        style: TextStyle(fontSize: 11, color: Colors.black26)),
                  )
                : Stack(children: [
                    Positioned(
                      left: printRect.left * w,
                      top: printRect.top * h,
                      width: printRect.width * w,
                      height: printRect.height * h,
                      child: _HeroCanvas(
                          service: service, recipe: design, longSide: 256),
                    ),
                  ]),
          );
        },
      ),
    );
  }
}
