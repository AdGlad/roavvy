import 'dart:ui' show Rect;

import 'package:design_forge/design_forge.dart';
import 'package:flutter/foundation.dart';

import 'lab_showcase_generator.dart';
import 'lab_styles.dart';
import 'render_service.dart';

/// The shape a Flags design fills — the "Detail" sub-step under the Flags
/// subject (Grid = plain flags; the rest are clipped).
enum StudioDetail { grid, map, animals, plants, landmarks, heart, circle }

/// How the FRONT artwork is printed on the shirt (mobile parity). Full = the
/// centred full-front print; chest = a small chest print (left/right); none =
/// a blank front (the main design lives on the back).
enum FrontFit { full, chest, none }

/// Where the front artwork comes from: a flag ribbon (default), a generated
/// complement of the back, or a copy of the main (back) design.
enum FrontArt { ribbon, complement, matchBack }

/// The Refine ("Fine Tune") categories — the storyboard's category menu.
enum RefineCategory {
  finish,
  layout,
  graphic,
  text,
  colour,
  edges,
  effects,
  print
}

extension RefineCategoryLabel on RefineCategory {
  String get label => switch (this) {
        RefineCategory.finish => 'Finish',
        RefineCategory.layout => 'Layout',
        RefineCategory.graphic => 'Graphic',
        RefineCategory.text => 'Text',
        RefineCategory.colour => 'Colour',
        RefineCategory.edges => 'Edges',
        RefineCategory.effects => 'Effects',
        RefineCategory.print => 'Print',
      };
}

/// **StudioController** — the portable, UI-agnostic interactive editing session
/// for the Roavvy T-Shirt Studio (M0 extraction from the macOS Lab's
/// `StudioCanvasScreen`). It is the single shared "session/orchestration" layer
/// that both hosts (macOS `design_lab`, mobile Roavvy V2) drive, so the Studio
/// behaves identically everywhere.
///
/// It owns: the two garment faces (hero/back + front), the effective travel
/// [DesignContext], the creative axes + alternatives + locks, undo history,
/// front-print coordination, and preference learning. It performs every recipe
/// mutation through [generator] ([LabShowcaseGenerator]) and never renders or
/// touches the filesystem itself — rendering is exposed via [service]
/// ([RenderService]); flag/silhouette asset resolution is injected into those.
///
/// A [ChangeNotifier]: hosts listen and rebuild; there is no Flutter widget or
/// platform dependency here.
class StudioController extends ChangeNotifier {
  StudioController({
    required this.generator,
    required this.service,
    required this.designContext,
    this.initialSeed = 1,
    DesignPreferences preferences = DesignPreferences.neutral,
    this.learner = const PreferenceLearner(),
    this.library,
    this.savePreferences,
    this.onPreferencesChanged,
    this.unavailableGarments = const {},
  }) : _preferences = preferences {
    _init();
  }

  /// The generator that seeds the hero and performs every re-roll.
  final LabShowcaseGenerator generator;

  /// Render orchestration (cached CanvasRenderer). Held for hosts to render the
  /// current design/faces; the controller itself never rasterises.
  final RenderService service;

  /// The ORIGINAL travel/flag context supplied by the host (full trip set).
  final DesignContext designContext;

  final int initialSeed;
  final PreferenceLearner learner;

  /// Optional reproducible library — ♥ Save likes into it, tray ✕ rejects.
  final PersistentDesignLibrary? library;

  /// Injected persistence sink (host wires this to disk / Drift / etc.). Keeps
  /// filesystem behaviour OUT of the shared package.
  final void Function(DesignPreferences)? savePreferences;

  /// Called with the new preferences after each update so the host can sync.
  final ValueChanged<DesignPreferences>? onPreferencesChanged;

  /// Garment colours (by [garments] label) the studio may show but cannot sell.
  ///
  /// Injected by the host, because whether a shirt can be made is a fact about
  /// a supplier, and this package deliberately knows nothing about one. Empty
  /// means everything in the palette is orderable.
  final Set<String> unavailableGarments;

  // ── Static catalogue (shared between hosts) ────────────────────────────────
  /// The Direction axis subjects: (genre, pinned family, label).
  static const List<(LabGenre, DesignFamily?, String)> subjects = [
    (LabGenre.flags, null, 'Flags'),
    (LabGenre.passport, null, 'Passport'),
    (LabGenre.travelLog, DesignFamily.journeys, 'Route'),
    (LabGenre.travelLog, DesignFamily.wordCloud, 'World'),
    (LabGenre.typography, null, 'Words'),
    (LabGenre.milestones, null, 'Milestones'),
  ];

  /// Garment (blank) colours: (hex, name).
  /// The garment colours a design may be made in — the exact eight the blank
  /// is stocked in (Gildan 64000 Softstyle), with their real hexes.
  ///
  /// This list is the product's colour range, not a designer's palette: every
  /// entry has to be a shirt that can actually be printed and shipped, and
  /// nothing printable may be missing. Keep it in step with the supplier.
  static const List<(String, String)> garments = [
    ('#0E0E0E', 'Black'),
    ('#0F1830', 'Navy'),
    ('#424848', 'Dark Heather'),
    ('#FF1B2B', 'Red'),
    ('#2665CC', 'Royal'),
    ('#FF5723', 'Orange'),
    ('#D1D2D6', 'Sport Grey'),
    ('#FFFFFF', 'White'),
  ];

  /// One-tap named finishes: (label, effects, vintageGrade, colourStrategy?).
  static const List<(String, Effects, double, ColourStrategy?)> finishPresets =
      [
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

  /// Artwork COLOUR treatments — how the design's ink is coloured, NOT the blank
  /// garment colour (that is [garments] / [setGarment]). Each maps a plain-language
  /// label to an engine [ColourStrategy] (+ a vintage grade for the aged look), so
  /// the palette state written here is always real engine state, never UI-only.
  /// (label, strategy, vintageGrade).
  static const List<(String, ColourStrategy, double)> colourTreatments = [
    ('Flag colours', ColourStrategy.flagDerived, 0.0),
    ('Monochrome', ColourStrategy.monochrome, 0.0),
    ('Duotone', ColourStrategy.duotone, 0.0),
    ('Match shirt', ColourStrategy.garmentAware, 0.0),
    ('Vintage', ColourStrategy.flagDerived, 0.55),
  ];

  static const Set<String> silhouetteShapeIds = {
    'animalSilhouette',
    'plantSilhouette',
    'landmarkSilhouette',
  };

  // ── Session state ──────────────────────────────────────────────────────────
  late DesignRecipe _hero;
  late DesignRecipe _frontFace;
  DesignRecipe get hero => _hero;
  DesignRecipe get frontFace => _frontFace;

  /// A view onto whichever face is active, so every mutator edits the visible one.
  DesignRecipe get current => _onFront ? _frontFace : _hero;
  set _current(DesignRecipe v) {
    if (_onFront) {
      _frontFace = v;
    } else {
      _hero = v;
    }
  }

  /// The recipe shown in the (back) hero = whichever face is active.
  DesignRecipe get heroRecipe => current;

  final List<DesignRecipe> _history = [];
  List<DesignRecipe> get history => List.unmodifiable(_history);

  final Set<DesignAxis> _locked = {};
  Set<DesignAxis> get locked => Set.unmodifiable(_locked);

  DesignPreferences _preferences;
  DesignPreferences get preferences => _preferences;

  DesignAxis? _activeAxis;
  DesignAxis? get activeAxis => _activeAxis;

  List<DesignRecipe> _alternatives = const [];
  List<DesignRecipe> get alternatives => List.unmodifiable(_alternatives);

  List<String> _titleIdeas = const [];
  List<String> get titleIdeas => List.unmodifiable(_titleIdeas);

  int _seedBump = 1000;
  int _nextSeed() => _seedBump++;

  int _subjectIndex = 0;
  int get subjectIndex => _subjectIndex;

  StudioDetail _detail = StudioDetail.grid;
  StudioDetail get detail => _detail;

  bool _onFront = false;
  bool get onFront => _onFront;

  FrontFit _frontFit = FrontFit.chest;
  FrontFit get frontFit => _frontFit;

  bool _chestRight = false;
  bool get chestRight => _chestRight;

  FrontArt _frontArt = FrontArt.ribbon;
  FrontArt get frontArt => _frontArt;

  bool _ribbonAllCountries = false;
  bool get ribbonAllCountries => _ribbonAllCountries;

  /// The EFFECTIVE context (re-derived when the Source / Year filter changes).
  late DesignContext _context;
  DesignContext get context => _context;

  bool _sourceTrips = false;
  bool get sourceTrips => _sourceTrips;

  int _yearLo = 0;
  int _yearHi = 0;
  int get yearLo => _yearLo;
  int get yearHi => _yearHi;

  bool get hasTrips => designContext.hasTrips;
  DateRange? get span => designContext.history.span;

  /// The distinct visited countries the user can choose from — trip countries
  /// when dated history exists, else the flat visited-country list. Deterministic
  /// order (first-visited / declared order), lowercase.
  List<String> get availableCountryCodes => designContext.hasTrips
      ? TravelHistory(designContext.trips).countryCodes
      : [for (final c in designContext.flagCodes) c.toLowerCase()];

  /// The current travel selection (a subset of [availableCountryCodes]). Map and
  /// List selection both read/write THIS single set, so they stay in sync.
  final Set<String> _selected = {};
  Set<String> get selectedCountryCodes => Set.unmodifiable(_selected);
  bool isSelected(String cc) => _selected.contains(cc.toLowerCase());

  /// The generator bound to the current subject — every generate/re-roll goes
  /// through this so the whole design stays within the chosen subject.
  LabShowcaseGenerator get _gen {
    final (g, t, _) = subjects[_subjectIndex];
    return generator.withGenre(g, template: t);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void _init() {
    final i = subjects.indexWhere((s) => s.$1 == generator.genre);
    if (i >= 0) _subjectIndex = i;
    _context = designContext;
    final span = _context.history.span;
    if (span != null) {
      _yearLo = span.start!.year;
      _yearHi = span.end!.year;
    }
    _selected
      ..clear()
      ..addAll(availableCountryCodes);
    _hero = _pickHero();
    _frontFace = _ribbonOf(_hero);
  }

  /// Emit the "initial hero viewed" soft-positive signal. Hosts call this once
  /// after the first frame (kept out of [_init] so no listener fires mid-build).
  void markViewed() => _observe(current, PreferenceSignal.viewed);

  DesignRecipe _pickHero() {
    if (_preferences.sampleCount == 0) {
      return generator.generate(_context, seed: initialSeed, count: 1).first;
    }
    final pool = generator.generate(_context, seed: initialSeed, count: 6);
    return _orderByPreference(pool).first;
  }

  List<DesignRecipe> _orderByPreference(List<DesignRecipe> recipes) {
    if (_preferences.sampleCount == 0) return recipes;
    const scorer = PreferenceScorer();
    final scored = [...recipes]..sort((a, b) =>
        scorer.score(b, _preferences).compareTo(scorer.score(a, _preferences)));
    return scored;
  }

  // ── Instant: ready-to-wear picks ────────────────────────────────────────────

  /// How many ready-made designs the Instant step offers.
  static const int instantCount = 8;

  List<DesignRecipe>? _instantPicks;
  int _instantIndex = 0;

  /// A set of finished designs chosen for this traveller — the opening offer,
  /// before any of the workflow is touched.
  ///
  /// Built from [LabSmartGenerator] once preferences exist, so the deck is
  /// preference-weighted and diversity-constrained rather than eight variations
  /// on one idea. With nothing learned yet it walks the SUBJECTS instead
  /// (Flags, Passport, Route, World, Words, Milestones), which gives a first-run
  /// traveller the same breadth by construction.
  ///
  /// Deterministic for a given context + seed, and built once per session so
  /// swiping back and forth never re-rolls what you already saw.
  List<DesignRecipe> get instantPicks {
    final cached = _instantPicks;
    if (cached != null) return cached;

    final picks = <DesignRecipe>[];
    if (_preferences.sampleCount > 0) {
      picks.addAll(LabSmartGenerator(
        preferences: _preferences,
        silhouettesByShape: generator.silhouettesByShape,
        continents: generator.continents,
        countryNames: generator.countryNames,
        outputCount: instantCount,
      ).generate(_context, seed: initialSeed, count: instantCount));
    }
    // Top up (and, on a first run, fill) by walking the subjects so the deck is
    // never a single family repeated.
    for (var i = 0;
        picks.length < instantCount && i < subjects.length * 3;
        i++) {
      final (g, t, _) = subjects[i % subjects.length];
      final made = generator
          .withGenre(g, template: t)
          .generate(_context, seed: initialSeed + i * 7 + 1, count: 1);
      for (final r in made) {
        if (picks.every((p) => p.recipeId != r.recipeId)) picks.add(r);
      }
    }
    final deck = picks.take(instantCount).toList();
    _instantPicks = deck;
    return deck;
  }

  /// Whether a garment colour can actually be bought, by its palette label.
  ///
  /// A colour that fails this is still shown — someone may want to see their
  /// design on it — but it must be visibly unavailable at the point of choice
  /// rather than silently designable and refused at the till.
  bool canOrderGarment(String name) => !unavailableGarments.contains(name);

  /// The palette label for a garment hex, or null if it is not in the palette.
  String? garmentLabelFor(String? hex) {
    if (hex == null) return null;
    for (final (h, name) in garments) {
      if (h.toUpperCase() == hex.toUpperCase()) return name;
    }
    return null;
  }

  /// True when the design currently on screen can be ordered as it stands.
  bool get canOrderCurrent =>
      canOrderGarment(garmentLabelFor(_hero.palette?.garmentColour) ?? '');

  /// A short, human name for a design — what the Instant deck calls each pick.
  ///
  /// Reads the design itself rather than storing a label, so a pick is named
  /// the same wherever it appears. The printed title wins when the design has
  /// one: that is what the wearer chose to call it.
  String instantName(DesignRecipe r) {
    final title = (r.content.meta['title'] as String?)?.trim();
    if (title != null && title.isNotEmpty) return title;

    final shape = r.clip?.shapeId;
    if (shape == 'passportPage' || shape == 'passportStampOutline') {
      return 'Passport stamps';
    }
    if (shape != null && silhouetteShapeIds.contains(shape)) {
      return 'Silhouette';
    }
    if (shape == 'countryOutline' || shape == 'continentOutline') return 'Map';
    if (shape == 'text') return 'Word';

    return switch (r.composition.family) {
      DesignFamily.timeline => 'Timeline',
      DesignFamily.journeys => 'Route',
      DesignFamily.wordCloud => 'World in words',
      DesignFamily.badge => 'Badge',
      DesignFamily.achievements => 'Milestone',
      DesignFamily.stats => 'Travel stats',
      DesignFamily.frontRibbon => 'Chest ribbon',
      DesignFamily.singleHero => 'Single flag',
      DesignFamily.duoBlend => 'Two flags',
      _ => 'Flag grid',
    };
  }

  /// Which pick is on the shirt right now.
  int get instantIndex => _instantIndex;

  /// Show pick [i] — swiping the Instant deck.
  ///
  /// Browsing is not choosing: this sets the visible design WITHOUT pushing undo
  /// history or teaching the preference model, so flicking through eight shirts
  /// doesn't bury the design you started on or skew what you are shown next.
  /// Acting on one ([takeInstant]) is what counts as a choice.
  void showInstant(int i) {
    final deck = instantPicks;
    if (deck.isEmpty) return;
    final index = i % deck.length;
    _instantIndex = index < 0 ? index + deck.length : index;
    _hero = _carryGarment(deck[_instantIndex], _hero);
    _frontFace = _ribbonOf(_hero);
    notifyListeners();
  }

  /// Commit the pick on screen as the design being worked on — what Configure
  /// and Buy both act through. Undoable, and it teaches the preference model.
  void takeInstant() {
    final deck = instantPicks;
    if (deck.isEmpty) return;
    _observe(_hero, PreferenceSignal.styleChosen);
  }

  /// The single learning choke-point: fold [signal] into preferences + persist.
  void _observe(DesignRecipe recipe, PreferenceSignal signal) {
    _preferences = learner.observe(_preferences, recipe, signal);
    savePreferences?.call(_preferences);
    onPreferencesChanged?.call(_preferences);
    notifyListeners();
  }

  /// Commit [next] as the new current face, pushing the outgoing onto undo.
  void _commit(DesignRecipe next) {
    if (next.recipeId == current.recipeId) return;
    _history.add(current);
    _current = next;
    notifyListeners();
    _observe(next, PreferenceSignal.styleChosen);
  }

  /// Live parameter edit — update in place WITHOUT pushing history.
  void applyLive(DesignRecipe next) {
    if (next.recipeId == current.recipeId) return;
    _current = next;
    notifyListeners();
  }

  // ── Axes / deck ─────────────────────────────────────────────────────────────
  void _rerollAxis(DesignAxis axis) {
    _commit(_gen.reroll(current, axis, newSeed: _nextSeed()));
    focusAxis(axis);
  }

  void focusAxis(DesignAxis axis) {
    _activeAxis = axis;
    _alternatives = axis == DesignAxis.direction
        ? _subjectAlternatives()
        : _orderByPreference([
            for (var i = 0; i < 4; i++)
              _gen.reroll(current, axis, newSeed: _nextSeed()),
          ]);
    notifyListeners();
  }

  List<DesignRecipe> _subjectAlternatives() => [
        for (var i = 0; i < subjects.length; i++)
          generator
              .withGenre(subjects[i].$1, template: subjects[i].$2)
              .generate(_context, seed: initialSeed + i, count: 1)
              .first,
      ];

  /// The 13 NAMED style options for the Vibe picker (current design restyled).
  List<(LabStyle, DesignRecipe)> vibeStyleOptions() {
    final base = current;
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

  LabStyle? get currentStyle =>
      labStyleFromProvenance(current.provenance?.generator);

  void onStyleTap(LabStyle style, DesignRecipe styled) {
    _commit(styled);
    notifyListeners();
  }

  String get currentTitle => (current.content.meta['title'] as String?) ?? '';

  void setTitle(String v) {
    final c = current.content;
    final meta = {...c.meta};
    if (v.trim().isEmpty) {
      meta.remove('title');
    } else {
      meta['title'] = v;
    }
    applyLive(current.copyWith(
        content: RecipeContent(
            flags: c.flags, source: c.source, entries: c.entries, meta: meta)));
  }

  /// Apply / replace / remove the design title as an UNDOABLE step (unlike the
  /// live-typing [setTitle], which edits in place). An empty value removes the
  /// title. Used when a title is applied at a boundary — a suggestion tap, field
  /// submit, or the Remove action — so Words changes participate in recipe undo.
  void commitTitle(String v) {
    final c = current.content;
    final meta = {...c.meta};
    if (v.trim().isEmpty) {
      meta.remove('title');
    } else {
      meta['title'] = v.trim();
    }
    _commit(current.copyWith(
        content: RecipeContent(
            flags: c.flags, source: c.source, entries: c.entries, meta: meta)));
  }

  List<String> _titleSuggestions() {
    final seen = <String>{};
    final out = <String>[];
    for (var i = 0; i < 12 && out.length < 6; i++) {
      final t = _gen
          .reroll(current, DesignAxis.words, newSeed: _nextSeed())
          .content
          .meta['title'] as String?;
      if (t != null && t.trim().isNotEmpty && seen.add(t)) out.add(t);
    }
    return out;
  }

  /// Regenerate the title suggestions (Suggest button).
  void suggestTitles() {
    _titleIdeas = _titleSuggestions();
    notifyListeners();
  }

  /// Words chip → open the title editor (no blind re-roll).
  void focusWords() {
    _activeAxis = DesignAxis.words;
    _titleIdeas = _titleSuggestions();
    notifyListeners();
  }

  void _cycleSubject() {
    _subjectIndex = (_subjectIndex + 1) % subjects.length;
    _commit(_gen.generate(_context, seed: _nextSeed(), count: 1).first);
    focusAxis(DesignAxis.direction);
  }

  /// Deck tap: Direction switches SUBJECT; Words opens the editor; else re-roll.
  void onChipTap(DesignAxis axis) {
    if (axis == DesignAxis.direction) {
      _cycleSubject();
    } else if (axis == DesignAxis.words) {
      focusWords();
    } else {
      _rerollAxis(axis);
    }
  }

  /// Whether the Detail sub-step applies — only the Flags subject fills a shape.
  bool get detailApplies => _subjectIndex == 0;

  /// Direction: select the design SUBJECT directly by [index] into [subjects]
  /// (Flags / Passport / Route / World / Words / Milestones). Regenerates the
  /// design deterministically for the chosen subject while CARRYING the garment
  /// colour / artwork size / orientation forward — a Direction change never
  /// resets the Tier-1 controls or the active travel selection. Leaving Flags
  /// resets [detail] to Grid (Detail applies to Flags only).
  void selectSubject(int index) {
    if (index < 0 || index >= subjects.length || index == _subjectIndex) return;
    _subjectIndex = index;
    if (index != 0) _detail = StudioDetail.grid;
    final (g, t, _) = subjects[index];
    final pool = generator.withGenre(g, template: t).generate(_context,
        seed: _selectionSeed(_context.flagCodes) + index,
        count: _preferences.sampleCount == 0 ? 1 : 6);
    _commit(_carryGarment(_orderByPreference(pool).first, current));
  }

  void onAlternativeTap(int index, DesignRecipe alt) {
    if (_activeAxis == DesignAxis.direction && index < subjects.length) {
      _subjectIndex = index;
    }
    _commit(alt);
  }

  String get subjectLabel => subjects[_subjectIndex].$3;

  void dismissAlternative(int index) {
    if (index < 0 || index >= _alternatives.length) return;
    final alt = _alternatives[index];
    library?.toggleReject(alt);
    _observe(alt, PreferenceSignal.rejected);
    _alternatives = [..._alternatives]..removeAt(index);
    notifyListeners();
  }

  void toggleLock(DesignAxis axis) {
    if (!_locked.add(axis)) _locked.remove(axis);
    notifyListeners();
  }

  /// Remix: re-roll every UNLOCKED axis at once, holding locks identical.
  void surprise() {
    _commit(_gen.rerollUnlocked(current, locked: _locked));
    if (_activeAxis != null && !_locked.contains(_activeAxis)) {
      focusAxis(_activeAxis!);
    }
  }

  void undo() {
    if (_history.isEmpty) return;
    _current = _history.removeLast();
    if (_activeAxis != null) {
      _alternatives = _orderByPreference([
        for (var i = 0; i < 4; i++)
          _gen.reroll(current, _activeAxis!, newSeed: _nextSeed()),
      ]);
    }
    notifyListeners();
  }

  // ── Detail / silhouettes ────────────────────────────────────────────────────
  void applyDetail(StudioDetail d) {
    _detail = d;
    final code = _context.flagCodes.isNotEmpty
        ? _context.flagCodes.first.toLowerCase()
        : 'us';
    final clip = switch (d) {
      StudioDetail.grid => Clip.shape(ClipShape.none),
      StudioDetail.map => Clip.shape(ClipShape.countryOutline, code: code),
      StudioDetail.animals => _silhouetteClip(ClipShape.animalSilhouette, code),
      StudioDetail.plants => _silhouetteClip(ClipShape.plantSilhouette, code),
      StudioDetail.landmarks =>
        _silhouetteClip(ClipShape.landmarkSilhouette, code),
      StudioDetail.heart => Clip.shape(ClipShape.heart),
      StudioDetail.circle => Clip.shape(ClipShape.circle),
    };
    _commit(current.copyWith(clip: clip));
  }

  Clip _silhouetteClip(ClipShape shape, String code) {
    final slugs = generator.silhouettesByShape[shape] ?? const <String>[];
    final slug = slugs.firstWhere((s) => s.startsWith('${code}_'),
        orElse: () => slugs.isNotEmpty ? slugs.first : code);
    return Clip.shape(shape, code: slug);
  }

  /// Every silhouette available for the SELECTED countries (pick a specific one).
  List<(ClipShape, String)> silhouetteOptions() {
    const kinds = [
      ClipShape.animalSilhouette,
      ClipShape.plantSilhouette,
      ClipShape.landmarkSilhouette,
    ];
    final codes = _context.flagCodes.map((c) => c.toLowerCase()).toSet();
    final out = <(ClipShape, String)>[];
    for (final k in kinds) {
      for (final slug in generator.silhouettesByShape[k] ?? const []) {
        final cc = slug.split('_').first;
        if (codes.isEmpty || codes.contains(cc)) out.add((k, slug));
      }
    }
    return out;
  }

  /// EVERY bundled silhouette (across all kinds), independent of the current
  /// travel selection — so the complete inventory stays reachable in the picker.
  /// [silhouetteOptions] is the country-scoped subset of this.
  List<(ClipShape, String)> allSilhouetteOptions() {
    const kinds = [
      ClipShape.animalSilhouette,
      ClipShape.plantSilhouette,
      ClipShape.landmarkSilhouette,
    ];
    final out = <(ClipShape, String)>[];
    for (final k in kinds) {
      for (final slug in generator.silhouettesByShape[k] ?? const []) {
        out.add((k, slug));
      }
    }
    return out;
  }

  String silhouetteLabel(ClipShape kind, String slug) {
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

  // ── Refine setters ──────────────────────────────────────────────────────────
  Effects get fx => current.effects ?? const Effects();
  void setFx(Effects fx) => applyLive(current.copyWith(effects: fx));
  void setComp(Composition c) => applyLive(current.copyWith(composition: c));
  void setClip(Clip c) => applyLive(current.copyWith(clip: c));

  /// The active outer-[EdgeTreatment] (torn/ragged edges), defaulted when the
  /// recipe carries none, so Fine Tune can surface + edit it live.
  EdgeTreatment get edges => current.edgeTreatment ?? const EdgeTreatment();
  void setEdges(EdgeTreatment e) =>
      applyLive(current.copyWith(edgeTreatment: e));

  /// The active [Typography] (title case / placement), defaulted so the Text
  /// category can edit it without needing the recipe to pre-populate one.
  Typography get typography => current.typography ?? const Typography();
  void setTypography(Typography t) =>
      applyLive(current.copyWith(typography: t));

  /// Advanced COLOUR knob: the aged/vintage grade alone (0..1), applied live to
  /// the palette without touching the strategy — complements the discrete
  /// [colourTreatments] with a continuous control.
  void setVintageGrade(double grade) {
    final pal = current.palette ?? const Palette();
    applyLive(current.copyWith(palette: pal.copyWith(vintageGrade: grade)));
  }

  void applyFinishPreset((String, Effects, double, ColourStrategy?) p) {
    final pal = current.palette ?? const Palette();
    _commit(current.copyWith(
      effects: p.$2,
      palette: pal.copyWith(vintageGrade: p.$3, strategy: p.$4 ?? pal.strategy),
    ));
  }

  /// Which Refine categories apply to the current design (contextual).
  List<RefineCategory> refineCategories() {
    final genre = subjects[_subjectIndex].$1;
    final clip = current.clip;
    final clipped = clip != null &&
        clip.shapeId != 'none' &&
        clip.shapeId != 'passportPage';
    final isPassport = genre == LabGenre.passport;
    return [
      RefineCategory.finish,
      if (_subjectIndex == 0) RefineCategory.layout,
      if (clipped || isPassport) RefineCategory.graphic,
      if (genre == LabGenre.typography) RefineCategory.text,
      RefineCategory.colour,
      RefineCategory.edges,
      RefineCategory.effects,
      RefineCategory.print,
    ];
  }

  // ── Tier-1 fixed controls ───────────────────────────────────────────────────
  void setSize(SizeClass s) =>
      setComp(current.composition.copyWith(sizeClass: s));
  void setOrientation(Orientation o) =>
      setComp(current.composition.copyWith(orientation: o));

  /// Set the blank GARMENT colour. Applied to BOTH faces (a t-shirt is one
  /// colour front and back) as a live palette edit — no layout re-roll, no
  /// history step, so each face keeps its own design.
  void setGarment(String hex) {
    DesignRecipe withGarment(DesignRecipe r) {
      final p = r.palette ?? const Palette();
      return r.copyWith(
          palette: p.copyWith(
              garmentColour: hex, strategy: ColourStrategy.garmentAware));
    }

    _hero = withGarment(_hero);
    _frontFace = withGarment(_frontFace);
    notifyListeners();
  }

  /// The active artwork colour treatment, matched against [colourTreatments].
  ColourStrategy get colourStrategy =>
      current.palette?.strategy ?? ColourStrategy.flagDerived;
  double get vintageGrade => current.palette?.vintageGrade ?? 0.0;

  /// Apply an artwork COLOUR treatment (see [colourTreatments]) — writes only the
  /// palette strategy + vintage grade, carrying the layout, effects (Vibe) and
  /// garment colour forward untouched. Undoable (participates in recipe history),
  /// unlike the live garment control [setGarment].
  void setColourTreatment((String, ColourStrategy, double) t) {
    final pal = current.palette ?? const Palette();
    _commit(current.copyWith(
        palette: pal.copyWith(strategy: t.$2, vintageGrade: t.$3)));
  }

  void setSide(bool onFront) {
    if (_onFront == onFront) return;
    _onFront = onFront;
    notifyListeners();
  }

  // ── Front print ─────────────────────────────────────────────────────────────
  void setFrontFit(FrontFit fit) {
    _frontFit = fit;
    notifyListeners();
  }

  void setChestSide(bool right) {
    _chestRight = right;
    notifyListeners();
  }

  /// The front artwork's print rect as fractions of the shirt-front image
  /// (mobile parity: `product_mockup_specs.dart`). Left/right chest map as mobile
  /// does — `left_chest` sits on the viewer's right. [Rect.zero] = blank front.
  Rect frontPrintRect() {
    switch (_frontFit) {
      case FrontFit.full:
        return const Rect.fromLTWH(0.25, 0.22, 0.50, 0.40);
      case FrontFit.chest:
        return _chestRight
            ? const Rect.fromLTWH(0.27, 0.25, 0.18, 0.25)
            : const Rect.fromLTWH(0.55, 0.25, 0.18, 0.25);
      case FrontFit.none:
        return Rect.zero;
    }
  }

  String get frontLabel {
    switch (_frontFit) {
      case FrontFit.full:
        return 'Full';
      case FrontFit.chest:
        return _chestRight ? 'Right chest' : 'Left chest';
      case FrontFit.none:
        return 'Blank';
    }
  }

  /// A flag-ribbon (frontRibbon family) recipe derived from [r]. When
  /// [_ribbonAllCountries] is set the ribbon shows every country in the context.
  DesignRecipe _ribbonOf(DesignRecipe r) {
    var content = r.content;
    if (_ribbonAllCountries) {
      final all = _context.flagCodes;
      if (all.isNotEmpty) {
        content = RecipeContent(
          flags: [for (final c in all) FlagRef(c)],
          source: r.content.source,
          entries: r.content.entries,
          meta: r.content.meta,
        );
      }
    }
    // The front is the wordmark over the flags and nothing else — the back's
    // printed title does not belong on a chest badge. The Words step can still
    // add one here deliberately; it just isn't carried over by default.
    final meta = {...content.meta}..remove('title');
    return r.copyWith(
      composition: r.composition.copyWith(family: DesignFamily.frontRibbon),
      content: RecipeContent(
        flags: content.flags,
        source: content.source,
        entries: content.entries,
        meta: meta,
      ),
    );
  }

  void setFrontArt(FrontArt art) {
    _frontArt = art;
    switch (art) {
      case FrontArt.ribbon:
        _frontFace = _ribbonOf(_hero);
      case FrontArt.complement:
        _frontFace = GarmentDesign.deriveBack(_hero,
            themeSeed: _nextSeed(),
            garmentColour: _hero.palette?.garmentColour);
      case FrontArt.matchBack:
        _frontFace = _hero;
    }
    notifyListeners();
  }

  void setRibbonCoverage(bool all) {
    _ribbonAllCountries = all;
    _frontFace = _ribbonOf(_hero);
    notifyListeners();
  }

  // ── Travel context (Source / Year) ──────────────────────────────────────────
  /// Live update of the year-range bounds (slider drag) — no regeneration.
  void previewYear(int lo, int hi) {
    _yearLo = lo;
    _yearHi = hi;
    notifyListeners();
  }

  void setSource(bool trips) {
    if (_sourceTrips == trips) return;
    _sourceTrips = trips;
    rebuildContext();
    notifyListeners();
  }

  /// Commit a new year range (slider change-end) — filter + regenerate. Use
  /// [previewYear] during the drag to update labels cheaply without a re-render.
  void setYearRange(int lo, int hi) {
    _yearLo = lo;
    _yearHi = hi;
    rebuildContext();
  }

  // ── Country selection (Map & List share this one set) ───────────────────────
  void toggleCountry(String cc) {
    final c = cc.toLowerCase();
    if (!_selected.remove(c)) _selected.add(c);
    _applySelection();
  }

  void setSelectedCountries(Iterable<String> codes) {
    _selected
      ..clear()
      ..addAll(codes.map((c) => c.toLowerCase()));
    _applySelection();
  }

  void selectAllCountries() => setSelectedCountries(availableCountryCodes);

  void clearCountries() {
    _selected.clear();
    _applySelection();
  }

  /// Apply a selection change: regenerate when it still yields ≥1 country, and
  /// always notify so the Map/List reflect the (possibly empty) selection.
  void _applySelection() {
    rebuildContext();
    notifyListeners();
  }

  /// The effective country codes feeding the design, under the current selection
  /// + Source + Year filter. Countries = one flag per distinct country; Trips =
  /// one per visit. Flat visited data (no trips) ignores Source/Year.
  List<String> _effectiveCodes() {
    if (!designContext.hasTrips) {
      return [
        for (final c in availableCountryCodes)
          if (_selected.contains(c)) c
      ];
    }
    final range = DateRange.years(_yearLo, _yearHi);
    final kept = [
      for (final t in TravelHistory(designContext.trips).inRange(range).trips)
        if (_selected.contains(t.cc)) t,
    ];
    if (_sourceTrips) return [for (final t in kept) t.cc];
    final seen = <String>{};
    final out = <String>[];
    for (final t in kept) {
      if (seen.add(t.cc)) out.add(t.cc);
    }
    return out;
  }

  /// Re-derive [_context] from the current selection + Source + Year filter, then
  /// deterministically regenerate the hero — carrying the garment/size/orientation
  /// so a travel change never resets the Tier-1 controls or the front/back side.
  void rebuildContext() {
    final codes = _effectiveCodes();
    if (codes.isEmpty) return; // never leave the design with no flags.
    final List<Trip> trips;
    final DateRange range;
    if (designContext.hasTrips) {
      range = DateRange.years(_yearLo, _yearHi);
      trips = [
        for (final t in TravelHistory(designContext.trips).inRange(range).trips)
          if (_selected.contains(t.cc)) t,
      ];
    } else {
      range = DateRange.all;
      trips = const [];
    }
    _context = DesignContext(
      flagCodes: codes,
      scopeKey: designContext.scopeKey,
      trips: trips,
      dateRange: range,
    );
    _regenerateFaces();
  }

  /// A deterministic seed for the current effective selection: the same set of
  /// countries (+ Source + Year) always yields the same design, independent of
  /// how many re-rolls happened before.
  int _selectionSeed(List<String> codes) {
    var h = initialSeed & 0x7fffffff;
    h = (h * 31 + (_sourceTrips ? 1 : 0)) & 0x7fffffff;
    h = (h * 31 + _yearLo) & 0x7fffffff;
    h = (h * 31 + _yearHi) & 0x7fffffff;
    for (final c in codes) {
      for (final u in c.codeUnits) {
        h = (h * 31 + u) & 0x7fffffff;
      }
    }
    return h;
  }

  void _regenerateFaces() {
    final prev = _hero;
    final pool = _gen.generate(_context,
        seed: _selectionSeed(_context.flagCodes),
        count: _preferences.sampleCount == 0 ? 1 : 6);
    _hero = _carryGarment(_orderByPreference(pool).first, prev);
    _frontFace = _ribbonOf(_hero);
    notifyListeners();
  }

  /// Carry the current garment colour / artwork size / orientation onto a freshly
  /// generated recipe so travel changes preserve the persistent Tier-1 state.
  DesignRecipe _carryGarment(DesignRecipe next, DesignRecipe prev) {
    final prevGarment = prev.palette?.garmentColour;
    final nextPal = next.palette ?? const Palette();
    final palette = prevGarment == null
        ? nextPal
        : nextPal.copyWith(
            garmentColour: prevGarment, strategy: prev.palette?.strategy);
    return next.copyWith(
      palette: palette,
      composition: next.composition.copyWith(
        sizeClass: prev.composition.sizeClass,
        orientation: prev.composition.orientation,
      ),
    );
  }

  // ── Save / review ───────────────────────────────────────────────────────────
  void save() {
    library?.toggleLike(current);
    _observe(current, PreferenceSignal.saved);
  }

  /// The current design as ONE two-face garment: [back] = the hero (main
  /// artwork), [front] = the front face (chest ribbon/config), sharing the
  /// garment colour. This is the reproducible unit the Review step saves and
  /// hands to commerce — both `recipeId`s + the colour fully determine the print,
  /// so it re-renders identically later (see [GarmentDesign.garmentId]).
  GarmentDesign get garment => GarmentDesign(
        front: _frontFace,
        back: _hero,
        garmentColour: _hero.palette?.garmentColour,
        themeSeed: initialSeed,
      );

  /// Save the whole two-face [garment] into the reproducible [library] at the
  /// Review step. Idempotent by garment identity — repeated Save keeps a single
  /// entry rather than creating duplicates. Distinct from [save] (the single-face
  /// ♥ toggle the macOS Lab uses); this persists BOTH printed sides so the design
  /// reproduces deterministically.
  void saveGarment() {
    library?.saveGarment(garment);
    _observe(current, PreferenceSignal.saved);
  }

  /// Reopen a previously saved [GarmentDesign] (M9). Restores BOTH printed faces
  /// so the design renders identically to when it was saved: the persisted front
  /// + back recipes and garment colour fully determine the print, so a
  /// save → leave Studio → reopen cycle reproduces the same [garment] identity
  /// ([GarmentDesign.garmentId]) and the same front/back artwork. Lands on the
  /// back (main) face, matching a fresh Review.
  void loadGarment(GarmentDesign g) {
    final back = g.back ?? g.front;
    final front = g.front ?? g.back;
    if (back == null || front == null) return;
    _hero = back;
    _frontFace = front;
    _onFront = false;
    notifyListeners();
  }

  String get garmentName {
    final hex = current.palette?.garmentColour;
    for (final (h, name) in garments) {
      if (h == hex) return name;
    }
    return '—';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// At-a-glance spec chips for the Review summary.
  List<String> reviewSpec() {
    final comp = current.composition;
    final n = _context.flagCodes.length;
    return [
      '$n ${n == 1 ? 'country' : 'countries'}',
      subjectLabel,
      if (_subjectIndex == 0) _cap(_detail.name),
      if (currentStyle != null) currentStyle!.label,
      _cap(comp.sizeClass.name),
      _cap(comp.orientation.name),
      garmentName,
      'Front: $frontLabel',
    ];
  }
}
