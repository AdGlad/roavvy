import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:flutter/material.dart' hide Orientation;

import 'lab_generator.dart';
import 'lab_styles.dart';
import 'preference_survey.dart';
import 'render_service.dart';

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

  /// Front + back recipes. [_current] is a view onto whichever side is active,
  /// so every existing mutator edits the visible side. The back is materialised
  /// (via [GarmentDesign.deriveBack]) the first time it's viewed.
  late DesignRecipe _front;
  DesignRecipe? _back;
  DesignRecipe get _current => _onBack ? _back! : _front;
  set _current(DesignRecipe v) {
    if (_onBack) {
      _back = v;
    } else {
      _front = v;
    }
  }

  final List<DesignRecipe> _history = [];
  final Set<DesignAxis> _locked = {};

  /// Preferences learned from this session's authoring, seeded from the host.
  late DesignPreferences _preferences;

  /// The axis whose alternatives the tray currently shows (null on open).
  DesignAxis? _activeAxis;
  List<DesignRecipe> _alternatives = const [];

  /// Suggested titles for the Words editor (regenerated on open / Suggest).
  List<String> _titleIdeas = const [];

  /// Monotonic source of fresh per-axis seeds so each tap yields a new look.
  int _seedBump = 1000;
  int _nextSeed() => _seedBump++;

  /// The Direction axis = the SUBJECT. Each entry is a (genre, pinned family,
  /// label); the Direction chip cycles these and regenerates the hero for that
  /// subject (Flags/Maps/Animals/Landmarks all live under Flags via the Detail
  /// sub-step, which arrives in a later chunk).
  static const List<(LabGenre, DesignFamily?, String)> _subjects = [
    (LabGenre.flags, null, 'Flags'),
    (LabGenre.passport, null, 'Passport'),
    (LabGenre.travelLog, DesignFamily.journeys, 'Route'),
    (LabGenre.travelLog, DesignFamily.wordCloud, 'World'),
    (LabGenre.typography, null, 'Words'),
    (LabGenre.milestones, null, 'Milestones'),
  ];
  int _subjectIndex = 0;

  /// The Flags "Detail" — the shape the flags fill. Only meaningful when the
  /// subject is Flags; a live clip edit (not a re-roll).
  _StudioDetail _detail = _StudioDetail.grid;

  /// Whether the contextual Refine panel (Tier-3 form controls) is open.
  bool _showAdjust = false;

  /// The active Refine category (storyboard "Fine Tune" menu). The panel shows
  /// one focused category at a time instead of one long scroll, and the category
  /// set is contextual to the current subject/detail.
  _RefineCategory _refineCat = _RefineCategory.finish;

  /// Front/Back view. The Back is a complementary design derived from the front
  /// (shared theme/palette) on first view, then independently editable.
  bool _onBack = false;

  /// The recipe shown in the hero = whichever side is active.
  DesignRecipe get _heroRecipe => _current;

  /// The generator bound to the current subject — every generate/re-roll goes
  /// through this so the whole design stays within the chosen subject.
  LabShowcaseGenerator get _gen {
    final (g, t, _) = _subjects[_subjectIndex];
    return widget.generator.withGenre(g, template: t);
  }

  // ── Test-facing read-only accessors ──
  DesignRecipe get currentRecipe => _current;
  Set<DesignAxis> get lockedAxes => Set.unmodifiable(_locked);
  int get historyLength => _history.length;
  List<DesignRecipe> get alternatives => List.unmodifiable(_alternatives);
  DesignAxis? get activeAxis => _activeAxis;

  /// Test-facing: the preferences learned so far this session.
  DesignPreferences get currentPreferences => _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences;
    final i = _subjects.indexWhere((s) => s.$1 == widget.generator.genre);
    if (i >= 0) _subjectIndex = i;
    // Instant hero: pick a design from the default context, rendered large. When
    // the customer already has preferences, bias the opening hero toward them
    // (task §19.3); otherwise keep the deterministic first design.
    _front = _pickHero();
    // The initial hero being shown is a soft positive signal. Emit it after the
    // first frame so preference/library updates never run during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _observe(_current, PreferenceSignal.viewed);
    });
  }

  /// Choose the opening hero. Neutral preferences → the deterministic first
  /// design (unchanged behaviour). Learned preferences → the best-scoring of a
  /// small pool under [PreferenceScorer], so learning visibly feeds back.
  DesignRecipe _pickHero() {
    if (_preferences.sampleCount == 0) {
      return widget.generator
          .generate(widget.designContext, seed: widget.initialSeed, count: 1)
          .first;
    }
    final pool = widget.generator
        .generate(widget.designContext, seed: widget.initialSeed, count: 6);
    return _orderByPreference(pool).first;
  }

  /// Order candidates best-first by preference score (stable when neutral).
  List<DesignRecipe> _orderByPreference(List<DesignRecipe> recipes) {
    if (_preferences.sampleCount == 0) return recipes;
    const scorer = PreferenceScorer();
    final scored = [...recipes]..sort((a, b) =>
        scorer.score(b, _preferences).compareTo(scorer.score(a, _preferences)));
    return scored;
  }

  /// Fold [signal] on [recipe] into the learned preferences, persist, and
  /// notify the host. The single choke-point for every learning update.
  void _observe(DesignRecipe recipe, PreferenceSignal signal) {
    final updated = widget.learner.observe(_preferences, recipe, signal);
    setState(() => _preferences = updated);
    widget.persistence?.savePreferences(updated);
    widget.onPreferencesChanged?.call(updated);
  }

  /// Commit [next] as the new hero, pushing the outgoing hero onto the undo
  /// stack. No-op (no history entry) if the recipe is unchanged.
  void _commit(DesignRecipe next) {
    if (next.recipeId == _current.recipeId) return;
    setState(() {
      _history.add(_current);
      _current = next;
    });
    // Committing a decision (a chip re-roll, an alternative pick, or Surprise-me)
    // is the customer actively choosing this look → a styleChosen signal.
    _observe(next, PreferenceSignal.styleChosen);
  }

  /// Deck tap: re-roll just [axis] with a fresh seed, focus its tray.
  void _rerollAxis(DesignAxis axis) {
    final next = _gen.reroll(_current, axis, newSeed: _nextSeed());
    _commit(next);
    _focusAxis(axis);
  }

  /// Rebuild the alternatives tray for [axis] (a strip of 4 re-rolls of the
  /// current hero on that axis, each a non-destructive candidate).
  void _focusAxis(DesignAxis axis) {
    setState(() {
      _activeAxis = axis;
      _alternatives = axis == DesignAxis.direction
          ? _subjectAlternatives()
          : _orderByPreference([
              for (var i = 0; i < 4; i++)
                _gen.reroll(_current, axis, newSeed: _nextSeed()),
            ]);
    });
  }

  /// One hero per subject (Direction) so the tray previews the whole subject set.
  List<DesignRecipe> _subjectAlternatives() => [
        for (var i = 0; i < _subjects.length; i++)
          widget.generator
              .withGenre(_subjects[i].$1, template: _subjects[i].$2)
              .generate(widget.designContext,
                  seed: widget.initialSeed + i, count: 1)
              .first,
      ];

  /// The 13 NAMED style options for the Vibe picker: each is the current design
  /// restyled into one [LabStyle] (only the Vibe/finish axis is spliced, so the
  /// subject/colour/words and all Tier-1 choices are preserved). Seeds are fixed
  /// per style so the thumbnails are stable across rebuilds.
  List<(LabStyle, DesignRecipe)> _vibeStyleOptions() {
    final base = _current;
    return [
      for (final s in LabStyle.values)
        (
          s,
          _gen
              .withStyle(s)
              .reroll(base, DesignAxis.vibe, newSeed: 7000 + s.index)
        ),
    ];
  }

  /// The style the current design is wearing (from its provenance stamp), so the
  /// Vibe picker can highlight it. Null if it wasn't Lab-generated.
  LabStyle? get _currentStyle =>
      labStyleFromProvenance(_current.provenance?.generator);

  /// Pick a NAMED style from the Vibe tray — commit the restyle and keep the tray
  /// open so the customer can keep trying vibes.
  void _onStyleTap(LabStyle style, DesignRecipe styled) {
    _commit(styled);
    setState(() {}); // refresh the tray's selected highlight
  }

  /// The printed title (content.meta['title']) — the customer's words.
  String get _currentTitle => (_current.content.meta['title'] as String?) ?? '';

  /// Set / clear the printed title, live (no history push per keystroke).
  void _setTitle(String v) {
    final c = _current.content;
    final meta = {...c.meta};
    if (v.trim().isEmpty) {
      meta.remove('title');
    } else {
      meta['title'] = v;
    }
    _applyLive(_current.copyWith(
        content: RecipeContent(
            flags: c.flags,
            source: c.source,
            entries: c.entries,
            meta: meta)));
  }

  /// A handful of distinct AI/offline title ideas (each a Words-axis re-roll),
  /// powering the storyboard's "Suggest titles".
  List<String> _titleSuggestions() {
    final seen = <String>{};
    final out = <String>[];
    for (var i = 0; i < 12 && out.length < 6; i++) {
      final t = _gen
          .reroll(_current, DesignAxis.words, newSeed: _nextSeed())
          .content
          .meta['title'] as String?;
      if (t != null && t.trim().isNotEmpty && seen.add(t)) out.add(t);
    }
    return out;
  }

  /// Words chip → open the title editor (no blind re-roll). The editor offers a
  /// text field + tappable suggestions.
  void _focusWords() {
    setState(() {
      _activeAxis = DesignAxis.words;
      _titleIdeas = _titleSuggestions();
    });
  }

  /// Direction chip → advance to the next subject and regenerate the hero.
  void _cycleSubject() {
    setState(() => _subjectIndex = (_subjectIndex + 1) % _subjects.length);
    _commit(
        _gen.generate(widget.designContext, seed: _nextSeed(), count: 1).first);
    _focusAxis(DesignAxis.direction);
  }

  /// Deck tap: Direction switches SUBJECT; every other chip re-rolls its axis.
  void _onChipTap(DesignAxis axis) {
    if (axis == DesignAxis.direction) {
      _cycleSubject();
    } else if (axis == DesignAxis.words) {
      _focusWords();
    } else {
      _rerollAxis(axis);
    }
  }

  /// Tray tap: keep the alternative. For Direction, also adopt its subject so
  /// subsequent re-rolls stay within it.
  void _onAlternativeTap(int index, DesignRecipe alt) {
    if (_activeAxis == DesignAxis.direction && index < _subjects.length) {
      setState(() => _subjectIndex = index);
    }
    _commit(alt);
  }

  /// The label shown on the Direction chip = the current subject.
  String get _subjectLabel => _subjects[_subjectIndex].$3;

  /// Apply a Flags "Detail" — swap the clip shape the flags fill, keeping every
  /// other axis identical (a live, non-destructive clip edit).
  void _applyDetail(_StudioDetail d) {
    setState(() => _detail = d);
    final code = widget.designContext.flagCodes.isNotEmpty
        ? widget.designContext.flagCodes.first.toLowerCase()
        : 'us';
    final clip = switch (d) {
      _StudioDetail.grid => Clip.shape(ClipShape.none),
      _StudioDetail.map => Clip.shape(ClipShape.countryOutline, code: code),
      _StudioDetail.animals =>
        _silhouetteClip(ClipShape.animalSilhouette, code),
      _StudioDetail.plants =>
        _silhouetteClip(ClipShape.plantSilhouette, code),
      _StudioDetail.landmarks =>
        _silhouetteClip(ClipShape.landmarkSilhouette, code),
      _StudioDetail.heart => Clip.shape(ClipShape.heart),
      _StudioDetail.circle => Clip.shape(ClipShape.circle),
    };
    _commit(_current.copyWith(clip: clip));
  }

  /// Pick a silhouette slug for [code] (prefer one for this country) → a clip.
  Clip _silhouetteClip(ClipShape shape, String code) {
    final slugs = widget.generator.silhouettesByShape[shape] ?? const <String>[];
    final slug = slugs.firstWhere((s) => s.startsWith('${code}_'),
        orElse: () => slugs.isNotEmpty ? slugs.first : code);
    return Clip.shape(shape, code: slug);
  }

  static const _silhouetteShapeIds = {
    'animalSilhouette',
    'plantSilhouette',
    'landmarkSilhouette',
  };

  /// Every silhouette (animal / plant / landmark) available for the SELECTED
  /// countries — so the user can pick a specific one from the full list rather
  /// than the auto-picked default. A country may contribute several.
  List<(ClipShape, String)> _silhouetteOptions() {
    const kinds = [
      ClipShape.animalSilhouette,
      ClipShape.plantSilhouette,
      ClipShape.landmarkSilhouette,
    ];
    final codes =
        widget.designContext.flagCodes.map((c) => c.toLowerCase()).toSet();
    final out = <(ClipShape, String)>[];
    for (final k in kinds) {
      for (final slug in widget.generator.silhouettesByShape[k] ?? const []) {
        final cc = slug.split('_').first;
        if (codes.isEmpty || codes.contains(cc)) out.add((k, slug));
      }
    }
    return out;
  }

  String _silhouetteLabel(ClipShape kind, String slug) {
    final parts = slug.split('_');
    final cc = parts.first.toUpperCase();
    final name = parts
        .skip(1)
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    final kindLabel = switch (kind) {
      ClipShape.animalSilhouette => 'animal',
      ClipShape.plantSilhouette => 'plant',
      ClipShape.landmarkSilhouette => 'landmark',
      _ => '',
    };
    return '$cc · $name ($kindLabel)';
  }

  // ── A3: Adjust panel (Tier-3 contextual form controls) ──────────────────────
  // Live parameter edits: update the hero in place without pushing history (a
  // refinement, not a decision) so dragging a slider doesn't flood undo.
  void _applyLive(DesignRecipe next) {
    if (next.recipeId == _current.recipeId) return;
    setState(() => _current = next);
  }

  Effects get _fx => _current.effects ?? const Effects();
  void _setFx(Effects fx) => _applyLive(_current.copyWith(effects: fx));
  void _setComp(Composition c) => _applyLive(_current.copyWith(composition: c));
  void _setClip(Clip c) => _applyLive(_current.copyWith(clip: c));

  /// ♥ Save: the customer loves the current hero. Strong-ish positive signal +
  /// a like in the reproducible library so the full recipe can be re-rendered.
  void _save() {
    widget.library?.toggleLike(_current);
    _observe(_current, PreferenceSignal.saved);
  }

  /// Tray ✕: the customer explicitly dislikes this alternative. Emit an explicit
  /// reject (preferred over inferring), reject it in the library, and drop the
  /// tile so the strip stays subtle.
  void _dismissAlternative(int index) {
    if (index < 0 || index >= _alternatives.length) return;
    final alt = _alternatives[index];
    widget.library?.toggleReject(alt);
    _observe(alt, PreferenceSignal.rejected);
    setState(() {
      _alternatives = [..._alternatives]..removeAt(index);
    });
  }

  /// Long-press / badge tap: pin or unpin an axis for "Surprise me".
  void _toggleLock(DesignAxis axis) {
    setState(() {
      if (!_locked.add(axis)) _locked.remove(axis);
    });
  }

  /// Surprise me: re-roll every UNLOCKED axis at once, holding locks identical.
  void _surprise() {
    final next = _gen.rerollUnlocked(_current, locked: _locked);
    _commit(next);
    if (_activeAxis != null && !_locked.contains(_activeAxis)) {
      _focusAxis(_activeAxis!);
    }
  }

  /// Undo: restore the previous hero instantly from the stored recipe.
  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _current = _history.removeLast();
      if (_activeAxis != null) {
        _alternatives = _orderByPreference([
          for (var i = 0; i < 4; i++)
            _gen.reroll(_current, _activeAxis!, newSeed: _nextSeed()),
        ]);
      }
    });
  }

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
          // Instant hero — the shirt is the star, always visible + centred.
          Expanded(
            child: Container(
              color: const Color(0xFF0E0F12),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: _HeroCanvas(
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
      (_StudioDetail.grid, 'Grid'),
      (_StudioDetail.map, 'Map'),
      (_StudioDetail.animals, 'Animals'),
      (_StudioDetail.plants, 'Plants'),
      (_StudioDetail.landmarks, 'Landmarks'),
      (_StudioDetail.heart, 'Heart'),
      (_StudioDetail.circle, 'Circle'),
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

  /// One-tap named finishes (the old editor's "Restyle" strip): each applies a
  /// bundled Effects (+ colour intent) over the current design, non-destructively.
  static const _finishPresets = <(String, Effects, double, ColourStrategy?)>[
    ('Clean', Effects(), 0.0, ColourStrategy.flagDerived),
    ('Vintage', Effects(fade: 0.35, grain: 0.3), 0.6, null),
    ('Retro', Effects(halftone: 0.5, halftoneScale: 5), 0.2, null),
    ('Halftone', Effects(halftone: 0.9, halftoneScale: 5), 0.0, null),
    ('Distress', Effects(distress: 0.55, grain: 0.4), 0.0, null),
    ('Tie-dye', Effects(tieDye: 0.9), 0.0, null),
    ('Shatter', Effects(shatter: 0.6, shatterSpikes: 0.4), 0.0, null),
    ('Riso', Effects(riso: 0.9), 0.0, null),
    ('Mono', Effects(), 0.0, ColourStrategy.monochrome),
  ];

  void _applyFinishPreset((String, Effects, double, ColourStrategy?) p) {
    final pal = _current.palette ?? const Palette();
    _commit(_current.copyWith(
      effects: p.$2,
      palette: pal.copyWith(vintageGrade: p.$3, strategy: p.$4 ?? pal.strategy),
    ));
  }

  Widget _finishRow() => Row(children: [
        _miniLabel('Finish'),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _finishPresets)
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

  /// Which Refine categories apply to the current design. Finish/Colour/Edges/
  /// Effects/Print are universal; Layout is Flags-only; Graphic appears when the
  /// artwork is clipped or is a passport collage; Text appears on the Words
  /// subject. Order matches the storyboard's Fine-Tune menu.
  List<_RefineCategory> _refineCategories() {
    final genre = _subjects[_subjectIndex].$1;
    final clip = _current.clip;
    final clipped =
        clip != null && clip.shapeId != 'none' && clip.shapeId != 'passportPage';
    final isPassport = genre == LabGenre.passport;
    return [
      _RefineCategory.finish,
      if (_subjectIndex == 0) _RefineCategory.layout,
      if (clipped || isPassport) _RefineCategory.graphic,
      if (genre == LabGenre.typography) _RefineCategory.text,
      _RefineCategory.colour,
      _RefineCategory.edges,
      _RefineCategory.effects,
      _RefineCategory.print,
    ];
  }

  Widget _refineMenu(List<_RefineCategory> cats, _RefineCategory active) =>
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
  List<Widget> _refineBody(_RefineCategory cat) {
    switch (cat) {
      case _RefineCategory.finish:
        return [_finishRow()];
      case _RefineCategory.layout:
        return _layoutControls();
      case _RefineCategory.graphic:
        return _graphicControls();
      case _RefineCategory.text:
        return _textControls();
      case _RefineCategory.colour:
        return _colourControls();
      case _RefineCategory.edges:
        return _edgeControls();
      case _RefineCategory.effects:
        return _effectControls();
      case _RefineCategory.print:
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
    final genre = _subjects[_subjectIndex].$1;

    if (genre == LabGenre.passport && _current.clip != null) {
      final clip = _current.clip!;
      rows
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
    if (silClip != null && _silhouetteShapeIds.contains(silClip.shapeId)) {
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

  // ── A4: Tier-1 fixed Format & Colour bar (always available, never reset by a
  // Style/Direction change) ──────────────────────────────────────────────────
  void _setSize(SizeClass s) =>
      _setComp(_current.composition.copyWith(sizeClass: s));
  void _setOrientation(Orientation o) =>
      _setComp(_current.composition.copyWith(orientation: o));
  void _setGarment(String hex) {
    final p = _current.palette ?? const Palette();
    _applyLive(_current.copyWith(
        palette: p.copyWith(
            garmentColour: hex, strategy: ColourStrategy.garmentAware)));
  }

  static const _garments = <(String, String)>[
    ('#1F2B33', 'Black'),
    ('#F5F5F5', 'White'),
    ('#22303A', 'Navy'),
    ('#8A8F98', 'Grey'),
    ('#D8C9A3', 'Sand'),
    ('#6B7350', 'Olive'),
  ];

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
          for (final (hex, name) in _garments)
            _swatch(hex, name, garment == hex),
          _divider(),
          _miniLabel('Side'),
          _pill('side-front', 'Front', !_onBack,
              () => setState(() => _onBack = false)),
          _pill('side-back', 'Back', _onBack, () {
            setState(() {
              _back ??= GarmentDesign.deriveBack(_front,
                  themeSeed: _front.seed,
                  garmentColour: _front.palette?.garmentColour);
              _onBack = true;
            });
          }),
        ]),
      ),
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
              onPressed: () => setState(() => _titleIdeas = _titleSuggestions()),
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
    return Container(
      color: const Color(0xFF16181D),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Wrap(
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
    );
  }
}

/// The shape a Flags design fills — the "Detail" sub-step under the Flags
/// subject (Grid = plain flags; the rest are clipped).
enum _StudioDetail { grid, map, animals, plants, landmarks, heart, circle }

/// The Refine ("Fine Tune") categories — the storyboard's category menu. Each
/// groups a contextual slice of the Tier-3 control set so advanced controls are
/// disclosed by category rather than as one long, always-cluttering panel.
enum _RefineCategory { finish, layout, graphic, text, colour, edges, effects, print }

extension _RefineCategoryLabel on _RefineCategory {
  String get label => switch (this) {
        _RefineCategory.finish => 'Finish',
        _RefineCategory.layout => 'Layout',
        _RefineCategory.graphic => 'Graphic',
        _RefineCategory.text => 'Text',
        _RefineCategory.colour => 'Colour',
        _RefineCategory.edges => 'Edges',
        _RefineCategory.effects => 'Effects',
        _RefineCategory.print => 'Print',
      };
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
