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
enum RefineCategory { finish, layout, graphic, text, colour, edges, effects, print }

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
  static const List<(String, String)> garments = [
    ('#1F2B33', 'Black'),
    ('#F5F5F5', 'White'),
    ('#22303A', 'Navy'),
    ('#8A8F98', 'Grey'),
    ('#D8C9A3', 'Sand'),
    ('#6B7350', 'Olive'),
  ];

  /// One-tap named finishes: (label, effects, vintageGrade, colourStrategy?).
  static const List<(String, Effects, double, ColourStrategy?)> finishPresets = [
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
        (s, _gen.withStyle(s).reroll(base, DesignAxis.vibe, newSeed: 7000 + s.index)),
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
    final clipped =
        clip != null && clip.shapeId != 'none' && clip.shapeId != 'passportPage';
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
  void setGarment(String hex) {
    final p = current.palette ?? const Palette();
    applyLive(current.copyWith(
        palette: p.copyWith(
            garmentColour: hex, strategy: ColourStrategy.garmentAware)));
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
    return r.copyWith(
      composition: r.composition.copyWith(family: DesignFamily.frontRibbon),
      content: content,
    );
  }

  void setFrontArt(FrontArt art) {
    _frontArt = art;
    switch (art) {
      case FrontArt.ribbon:
        _frontFace = _ribbonOf(_hero);
      case FrontArt.complement:
        _frontFace = GarmentDesign.deriveBack(_hero,
            themeSeed: _nextSeed(), garmentColour: _hero.palette?.garmentColour);
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
    _sourceTrips = trips;
    rebuildContext();
  }

  /// Re-derive [_context] from the host's trips under the current Source + Year
  /// filter, then regenerate the hero. Countries = one flag per distinct country;
  /// Trips = one per visit.
  void rebuildContext() {
    final all = TravelHistory(designContext.trips);
    final range = DateRange.years(_yearLo, _yearHi);
    final filtered = all.inRange(range);
    final codes =
        _sourceTrips ? [for (final t in filtered.trips) t.cc] : filtered.countryCodes;
    if (codes.isEmpty) return; // never leave the design with no flags.
    _context = DesignContext(
      flagCodes: codes,
      scopeKey: designContext.scopeKey,
      trips: filtered.trips,
      dateRange: range,
    );
    _hero = _gen.generate(_context, seed: _nextSeed(), count: 1).first;
    _frontFace = _ribbonOf(_hero);
    notifyListeners();
  }

  // ── Save / review ───────────────────────────────────────────────────────────
  void save() {
    library?.toggleLike(current);
    _observe(current, PreferenceSignal.saved);
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
