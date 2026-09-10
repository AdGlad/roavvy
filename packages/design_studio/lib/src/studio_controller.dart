import 'dart:ui' show Rect;

import 'package:design_forge/design_forge.dart';
import 'package:flutter/foundation.dart';

import 'lab_showcase_generator.dart';
import 'lab_styles.dart';
import 'render_service.dart';

/// The shape a Flags design fills — the "Detail" sub-step under the Flags
/// subject (Grid = plain flags; the rest are clipped).
enum StudioDetail { grid, map, animals, plants, landmarks, heart, circle }

/// One **Direction Detail** choice: how the chosen Direction is expressed.
///
/// Contextual by construction — the list comes from what the engine can
/// actually do for the Direction on screen, so there is no universal set of
/// options and no choice offered that the renderer cannot draw. A Direction
/// with nothing meaningful to offer returns an empty list, and the step is
/// skipped rather than shown empty.
class DetailChoice {
  const DetailChoice({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  /// Stable identifier, used to select and to report what is selected.
  final String id;
  final String title;
  final String subtitle;
}

/// How the FRONT artwork is printed on the shirt (mobile parity). Full = the
/// centred full-front print; chest = a small chest print (left/right); none =
/// a blank front (the main design lives on the back).
enum FrontFit { full, chest, none }

/// Where the front artwork comes from: a flag ribbon (default), a generated
/// complement of the back, or a copy of the main (back) design.
enum FrontArt { ribbon, complement, matchBack }

/// The three Fine Tune panels. Deliberately few and stable: M17–M19 deepen
/// what sits inside them, so a control added later needs a group, not a new
/// screen.
enum FineTuneGroup { layout, graphics, colour, words }

extension FineTuneGroupLabel on FineTuneGroup {
  String get label => switch (this) {
        FineTuneGroup.layout => 'Layout & Composition',
        FineTuneGroup.graphics => 'Graphics',
        FineTuneGroup.colour => 'Colour, Effects & Print',
        FineTuneGroup.words => 'Words & Title',
      };
}

/// One option of a [FineTuneChoice] — a named arrangement, shown as a chip.
class FineTuneOption {
  const FineTuneOption(this.id, this.label, {this.sample, this.fontFamily});
  final String id;
  final String label;

  /// Text to show AS the option — a type specimen ("Aa") rather than a name.
  /// A face has to be seen to be picked, and at chip size a specimen carries
  /// far more than a full-design thumbnail would.
  final String? sample;

  /// The family [sample] is drawn in. Same host font name the renderer uses,
  /// so the specimen and the shirt agree.
  final String? fontFamily;
}

/// A pick-one control: the same capability contract as [FineTuneControl], but
/// a set of named arrangements rather than a range. Added here rather than in
/// a second system so the screen still renders whatever the controller hands
/// it, whether that is a slider or a row of chips.
class FineTuneChoice {
  const FineTuneChoice({
    required this.id,
    required this.label,
    required this.group,
    required this.options,
    required this.read,
    required this.write,
    this.helper = '',
    this.preview = false,
  });

  final String id;
  final String label;
  final String helper;
  final FineTuneGroup group;
  final List<FineTuneOption> options;

  /// Render each option as a live thumbnail of the design it would produce,
  /// rather than as a text chip. A colour grade or a print screen is a LOOK —
  /// "Riso" tells a wearer nothing until they can see it on their own artwork.
  final bool preview;

  /// The option currently in effect.
  final String Function(DesignRecipe r) read;

  /// Pure, like [FineTuneControl.write].
  final DesignRecipe Function(DesignRecipe r, String optionId) write;
}

/// One tunable parameter of the CURRENT design.
///
/// A description, not a widget: it names the recipe field behind it, the range
/// it moves in, and how to read and write it. The screen renders whatever list
/// it is given, so adding a control in a later milestone means adding an entry
/// here — never another branch in the UI.
class FineTuneControl {
  const FineTuneControl({
    required this.id,
    required this.label,
    required this.group,
    required this.read,
    required this.write,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.asPercent = true,
    this.unit = '',
    this.helper = '',
  });

  final String id;
  final String label;

  /// One line saying what the control does, in the customer's terms.
  final String helper;
  final FineTuneGroup group;

  /// Current value, read straight off the recipe.
  final double Function(DesignRecipe r) read;

  /// The recipe this control's value would produce — pure, so the caller
  /// decides whether it lands live or as an undo step.
  final DesignRecipe Function(DesignRecipe r, double v) write;

  final double min;
  final double max;
  final int? divisions;

  /// Shown as 0–100% rather than a raw number.
  final bool asPercent;
  final String unit;
}

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

  /// The countries that can go on this shirt right now — trip countries
  /// visited WITHIN the chosen year range when dated history exists, else the
  /// flat visited-country list. Deterministic order (first-visited / declared
  /// order), lowercase.
  ///
  /// Range-aware because the year range decides which travels the shirt
  /// represents: a list that still offered countries outside the chosen years
  /// would be offering something the design cannot include, and the picker
  /// would be describing a different shirt from the one on screen. Narrowing
  /// the range hides a country but does not deselect it, so widening again
  /// brings it back exactly as it was.
  List<String> get availableCountryCodes {
    if (!designContext.hasTrips) {
      return [for (final c in designContext.flagCodes) c.toLowerCase()];
    }
    final all = TravelHistory(designContext.trips);
    final span = all.span;
    // Before a range has been chosen, or when it covers everything, this is
    // just the whole history.
    if (span == null || _yearLo == 0) return all.countryCodes;
    return all.inRange(DateRange.years(_yearLo, _yearHi)).countryCodes;
  }

  /// Every country the traveller has been to, ignoring the year range and the
  /// current selection — what "All travelled" on the front ribbon means.
  ///
  /// NOT `designContext.flagCodes`: a context built from dated trips
  /// ([DesignContext.fromTrips]) carries its countries in `trips` and leaves
  /// `flagCodes` EMPTY, so reading that list made "All travelled" quietly
  /// identical to "Selected travels" for every real traveller.
  List<String> get allTravelledCodes {
    if (!designContext.hasTrips) {
      return [for (final c in designContext.flagCodes) c.toLowerCase()];
    }
    return TravelHistory(designContext.trips).countryCodes;
  }

  /// The current travel selection (a subset of [availableCountryCodes]). Map and
  /// List selection both read/write THIS single set, so they stay in sync.
  final Set<String> _selected = {};
  Set<String> get selectedCountryCodes => Set.unmodifiable(_selected);
  bool isSelected(String cc) => _selected.contains(cc.toLowerCase());

  /// The generator bound to the current subject — every generate/re-roll goes
  /// through this so the whole design stays within the chosen subject.
  /// A family chosen on the Detail step, overriding the Direction's default.
  /// Route pins `journeys`; choosing Timeline there must actually stick.
  DesignFamily? _detailFamily;

  LabShowcaseGenerator get _gen {
    final (g, t, _) = subjects[_subjectIndex];
    return generator.withGenre(g, template: _detailFamily ?? t);
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
    _rebuildFront();
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
    _rebuildFront();
    notifyListeners();
  }

  /// Deck pick [i] as it would appear on the shirt right now: the design
  /// itself, already wearing the garment colour and print scale chosen.
  ///
  /// Browsing renders the neighbouring pages before they are settled on, and a
  /// raw pick still carries whatever colour it was generated in — so without
  /// this the shirt visibly changes colour as a swipe lands. Wraps like
  /// [showInstant], so page −1 is the last design.
  ///
  /// Cheap and pure: it copies a recipe, it does not generate one.
  DesignRecipe instantPreviewAt(int i) {
    final deck = instantPicks;
    if (deck.isEmpty) return _hero;
    final index = i % deck.length;
    return _carryGarment(deck[index < 0 ? index + deck.length : index], _hero);
  }

  /// The chest face for deck pick [i] — the same derivation the live front
  /// uses, so Front/Back on a browsed shirt shows that shirt's own front
  /// rather than the one belonging to the design last settled on.
  DesignRecipe instantFrontAt(int i) => _ribbonOf(instantPreviewAt(i));

  /// Commit the pick on screen as the design being worked on — what Customise
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
  /// The Detail choices for the Direction on screen — empty when it has none.
  ///
  /// Every entry is backed by an existing engine capability:
  ///   * **Flags** — the clip subjects [StudioDetail] already applies.
  ///   * **Passport** — the two passport clip subjects in the genre's rotation
  ///     ([ClipShape.passportPage], [ClipShape.passportStampOutline]).
  ///   * **Route** and **Milestones** — the [DesignFamily]s their data genre
  ///     declares in [LabGenre.families].
  ///   * **World** and **Words** — nothing: World IS the word-cloud family and
  ///     Words IS the single typographic subject, so there is no sibling to
  ///     choose between. Both skip this step.
  List<DetailChoice> get detailChoices => switch (_subjectIndex) {
        0 => const [
            DetailChoice(
                id: 'grid', title: 'Grid', subtitle: 'Clean and modern'),
            DetailChoice(
                id: 'circle',
                title: 'Circle',
                subtitle: 'Circular composition'),
            DetailChoice(
                id: 'map', title: 'Map', subtitle: 'Flags in map layout'),
            DetailChoice(
                id: 'heart', title: 'Heart', subtitle: 'Flags in a heart'),
            DetailChoice(
                id: 'animals', title: 'Animals', subtitle: 'Native wildlife'),
            DetailChoice(
                id: 'plants', title: 'Plants', subtitle: 'Native flora'),
            DetailChoice(
                id: 'landmarks', title: 'Landmarks', subtitle: 'Famous places'),
          ],
        1 => const [
            DetailChoice(
                id: 'passportPage',
                title: 'Passport page',
                subtitle: 'Stamps on the page'),
            DetailChoice(
                id: 'passportStampOutline',
                title: 'Single stamp',
                subtitle: 'One bold stamp'),
          ],
        2 => const [
            DetailChoice(
                id: 'journeys',
                title: 'Route',
                subtitle: 'Paths you travelled'),
            DetailChoice(
                id: 'timeline', title: 'Timeline', subtitle: 'Trips in order'),
          ],
        5 => const [
            DetailChoice(
                id: 'badge', title: 'Badge', subtitle: 'Earned emblem'),
            DetailChoice(
                id: 'achievements',
                title: 'Achievements',
                subtitle: 'What you unlocked'),
            DetailChoice(id: 'stats', title: 'Stats', subtitle: 'Your numbers'),
          ],
        _ => const [],
      };

  /// Whether the Direction on screen has a Detail step at all.
  bool get detailApplies => detailChoices.isNotEmpty;

  /// Which Detail is currently in effect, or null before one is chosen.
  String? get currentDetailId {
    if (_subjectIndex == 0) return _detail.name;
    if (_subjectIndex == 1) return current.clip?.shapeId;
    return (_detailFamily ?? current.composition.family).name;
  }

  /// Apply the Detail choice named [id]. Unknown ids are ignored rather than
  /// guessed at — a Detail the engine cannot draw must never reach a design.
  void applyDetailChoice(String id) {
    if (!detailChoices.any((c) => c.id == id)) return;
    if (_subjectIndex == 0) {
      final d = StudioDetail.values.firstWhere((v) => v.name == id);
      applyDetail(d);
      return;
    }
    if (_subjectIndex == 1) {
      final shape = ClipShape.fromId(id);
      final code = _context.flagCodes.isNotEmpty
          ? _context.flagCodes.first.toLowerCase()
          : 'us';
      _commit(current.copyWith(clip: Clip.shape(shape, code: code)));
      return;
    }
    _applyDetailFamily(DesignFamily.fromId(id));
  }

  /// Re-cut the design onto a sibling family of the same Direction.
  ///
  /// Direction Detail chooses a creative subtype, so a new composition is the
  /// point — but the Vibe, the garment and the customer's title are not the
  /// subtype's to change, exactly as when the Direction itself changes.
  void _applyDetailFamily(DesignFamily family) {
    _detailFamily = family;
    final prev = current;
    final style = currentStyle;
    var gen = generator.withGenre(subjects[_subjectIndex].$1, template: family);
    if (style != null) gen = gen.withStyle(style);
    final pool = gen.generate(_context,
        seed: _selectionSeed(_context.flagCodes) + family.index,
        count: _preferences.sampleCount == 0 ? 1 : 6);
    _commit(
        _carryWords(_carryGarment(_orderByPreference(pool).first, prev), prev));
  }

  /// Direction: select the design SUBJECT directly by [index] into [subjects]
  /// (Flags / Passport / Route / World / Words / Milestones). Regenerates the
  /// design deterministically for the chosen subject while CARRYING the garment
  /// colour / artwork size / orientation forward — a Direction change never
  /// resets the Tier-1 controls or the active travel selection. Leaving Flags
  /// resets [detail] to Grid (Detail applies to Flags only).
  /// Change what the design is ABOUT.
  ///
  /// Direction is the one axis whose whole job is to redraw the artwork, so a
  /// new composition here is the point rather than a loss. What must survive
  /// is everything the customer chose that is not about the subject: the
  /// travels (untouched — this never rebuilds the context), the garment, and
  /// the two that a bare regeneration used to throw away — the Vibe they
  /// picked, and the title they typed.
  void selectSubject(int index) {
    if (index < 0 || index >= subjects.length || index == _subjectIndex) return;
    _subjectIndex = index;
    // A Detail belongs to the Direction that offered it.
    _detailFamily = null;
    if (index != 0) _detail = StudioDetail.grid;
    final prev = current;
    final style = currentStyle;
    final (g, t, _) = subjects[index];
    var gen = generator.withGenre(g, template: t);
    // Ask for the new subject IN the style already chosen, rather than
    // restyling afterwards — the generator composes the two properly.
    if (style != null) gen = gen.withStyle(style);
    final pool = gen.generate(_context,
        seed: _selectionSeed(_context.flagCodes) + index,
        count: _preferences.sampleCount == 0 ? 1 : 6);
    _commit(
        _carryWords(_carryGarment(_orderByPreference(pool).first, prev), prev));
  }

  /// Carry the customer's own words onto a freshly generated recipe. Their
  /// title belongs to them, not to whichever subject is on screen.
  DesignRecipe _carryWords(DesignRecipe next, DesignRecipe prev) {
    final title = (prev.content.meta['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return next;
    return next.copyWith(
      content: RecipeContent(
        flags: next.content.flags,
        entries: next.content.entries,
        source: next.content.source,
        meta: {...next.content.meta, 'title': title},
      ),
    );
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

  /// The Fine Tune controls that can actually change the design on screen.
  ///
  /// Contextual by derivation, not by a table of Direction/Vibe special cases:
  /// each control declares the recipe field it edits, and it is offered only
  /// when that field exists on THIS recipe. A design with no clip has no
  /// Graphics controls because there is no clip to scale or rotate — showing
  /// them greyed out would be offering something the renderer would ignore.
  ///
  /// M17–M19 extend this list; the screen renders whatever it is handed.
  List<FineTuneControl> fineTuneControls() {
    final r = current;
    final clip = r.clip;
    // 'none' is the absence of a clip wearing a name — Flags/Grid has one.
    final hasClip = clip != null && clip.shapeId != 'none';
    // Arranging needs more than one thing to arrange.
    final arranges = r.content.flags.length > 1;
    return [
      // Scale is honoured for every design — the renderer reads sizeClass
      // whatever the subject is.
      FineTuneControl(
        id: 'scale',
        label: 'Scale',
        helper: 'Size of the artwork.',
        group: FineTuneGroup.layout,
        min: 0,
        max: 2,
        divisions: 2,
        asPercent: false,
        read: (r) => r.composition.sizeClass.index.toDouble(),
        write: (r, v) => r.copyWith(
            composition:
                r.composition.copyWith(sizeClass: SizeClass.values[v.round()])),
      ),
      if (arranges)
        FineTuneControl(
          id: 'copies',
          label: 'Repeats',
          helper: 'How many times each country appears.',
          group: FineTuneGroup.layout,
          min: 1,
          max: 4,
          divisions: 3,
          asPercent: false,
          read: (r) => r.composition.copiesPerCountry.toDouble(),
          write: (r, v) => r.copyWith(
              composition: r.composition.copyWith(copiesPerCountry: v.round())),
        ),
      // Corner rounding, but only for a shape that HONOURS it. The shape
      // catalogue records this per shape, so applicability comes from the
      // engine's own metadata rather than a list of names kept in the UI.
      if (hasClip && (clipShapeMetaById(clip.shapeId)?.cornerRadius ?? false))
        FineTuneControl(
          id: 'clipCorner',
          helper: 'Roundness of the corners.',
          label: 'Corners',
          group: FineTuneGroup.graphics,
          read: (r) => r.clip!.cornerRadius,
          write: (r, v) => r.copyWith(clip: r.clip!.copyWith(cornerRadius: v)),
        ),
      // The damage sliders only mean something once an edge style is chosen:
      // with Clean there is nothing to fray or wear.
      if ((r.edgeTreatment?.edgeDamage ?? 0) > 0) ...[
        FineTuneControl(
          id: 'edgeDamage',
          helper: 'How torn the edge is.',
          label: 'Damage',
          group: FineTuneGroup.graphics,
          read: (r) => r.edgeTreatment!.edgeDamage,
          write: (r, v) => r.copyWith(
              edgeTreatment: r.edgeTreatment!.copyWith(edgeDamage: v)),
        ),
        FineTuneControl(
          id: 'edgeFray',
          helper: 'Loose threads along the tear.',
          label: 'Fray',
          group: FineTuneGroup.graphics,
          read: (r) => r.edgeTreatment!.frayAmount,
          write: (r, v) => r.copyWith(
              edgeTreatment: r.edgeTreatment!.copyWith(frayAmount: v)),
        ),
        FineTuneControl(
          id: 'edgeCorners',
          helper: 'Damage at the corners.',
          label: 'Corner wear',
          group: FineTuneGroup.graphics,
          read: (r) => r.edgeTreatment!.cornerDamage,
          write: (r, v) => r.copyWith(
              edgeTreatment: r.edgeTreatment!.copyWith(cornerDamage: v)),
        ),
      ],
      if (hasClip) ...[
        FineTuneControl(
          id: 'clipScale',
          helper: 'Size of the shape.',
          label: 'Size',
          group: FineTuneGroup.graphics,
          min: 0.5,
          max: 1.5,
          read: (r) => r.clip!.scale,
          write: (r, v) => r.copyWith(clip: r.clip!.copyWith(scale: v)),
        ),
        FineTuneControl(
          id: 'clipRotation',
          helper: 'Tilt of the shape.',
          label: 'Rotation',
          group: FineTuneGroup.graphics,
          min: -45,
          max: 45,
          asPercent: false,
          unit: '°',
          read: (r) => r.clip!.rotationDeg,
          write: (r, v) => r.copyWith(clip: r.clip!.copyWith(rotationDeg: v)),
        ),
        FineTuneControl(
          id: 'clipFeather',
          helper: 'Softness of the edge.',
          label: 'Softness',
          group: FineTuneGroup.graphics,
          read: (r) => r.clip!.feather,
          write: (r, v) => r.copyWith(clip: r.clip!.copyWith(feather: v)),
        ),
      ],
      FineTuneControl(
        id: 'vintageGrade',
        helper: 'How aged it looks.',
        label: 'Aged',
        group: FineTuneGroup.colour,
        read: (r) => r.palette?.vintageGrade ?? 0,
        write: (r, v) => r.copyWith(
            palette: (r.palette ?? const Palette()).copyWith(vintageGrade: v)),
      ),
      FineTuneControl(
        id: 'distress',
        helper: 'Worn and broken up.',
        label: 'Distressed',
        group: FineTuneGroup.colour,
        read: (r) => r.effects?.distress ?? 0,
        write: (r, v) => r.copyWith(
            effects: (r.effects ?? const Effects()).copyWith(distress: v)),
      ),
      FineTuneControl(
        id: 'grain',
        helper: 'Print texture.',
        label: 'Grain',
        group: FineTuneGroup.colour,
        read: (r) => r.effects?.grain ?? 0,
        write: (r, v) => r.copyWith(
            effects: (r.effects ?? const Effects()).copyWith(grain: v)),
      ),
      FineTuneControl(
        id: 'halftone',
        helper: 'Dot-screen printing.',
        label: 'Halftone',
        group: FineTuneGroup.colour,
        read: (r) => r.effects?.halftone ?? 0,
        write: (r, v) => r.copyWith(
            effects: (r.effects ?? const Effects()).copyWith(halftone: v)),
      ),
    ];
  }

  /// Pick-one controls for the current design.
  ///
  /// Only [FillAlgorithm], and only where the renderer actually consults it:
  /// the composition stage takes the chosen algorithm on the many-instance
  /// path, while one or two flags are drawn by dedicated code that ignores it.
  /// Offering an arrangement on a two-flag design would be a control that
  /// changes the recipe and nothing else.
  List<FineTuneChoice> fineTuneChoices() {
    final r = current;
    if (r.content.flags.length * r.composition.copiesPerCountry <= 2) {
      return const [];
    }
    return [
      FineTuneChoice(
        id: 'fill',
        label: 'Arrangement',
        helper: 'How the flags are laid out.',
        group: FineTuneGroup.layout,
        options: const [
          FineTuneOption('grid', 'Grid'),
          FineTuneOption('mosaic', 'Mosaic'),
          FineTuneOption('radial', 'Radial'),
          FineTuneOption('voronoi', 'Organic'),
          FineTuneOption('treemap', 'Treemap'),
          FineTuneOption('diagonalStripe', 'Stripes'),
          FineTuneOption('tornRegion', 'Torn'),
          FineTuneOption('noiseBlend', 'Blend'),
        ],
        read: (r) => (r.composition.fillAlgorithm ?? FillAlgorithm.grid).name,
        write: (r, id) => r.copyWith(
            composition: r.composition
                .copyWith(fillAlgorithm: FillAlgorithm.fromId(id))),
      ),
    ];
  }

  /// Graphic-level pick-one controls: how the artwork's own edge is cut, and
  /// which silhouette it is cut to.
  ///
  /// Separate from [fineTuneChoices] only in the group they belong to — the
  /// screen unions both and filters by group, so a later milestone adds to
  /// whichever list fits.
  List<FineTuneChoice> graphicChoices() {
    final r = current;
    final clip = r.clip;
    final hasClip = clip != null && clip.shapeId != 'none';
    return [
      FineTuneChoice(
        id: 'edge',
        label: 'Edge style',
        helper: "How the artwork's edge is cut.",
        group: FineTuneGroup.graphics,
        options: const [
          FineTuneOption('none', 'Clean'),
          FineTuneOption('lightlyWorn', 'Worn'),
          FineTuneOption('ragged', 'Ragged'),
          FineTuneOption('tornCorners', 'Torn'),
          FineTuneOption('frayed', 'Frayed'),
          FineTuneOption('deepRips', 'Ripped'),
          FineTuneOption('battleWorn', 'Battered'),
          FineTuneOption('asymmetricTear', 'Uneven'),
          FineTuneOption('heavyEdgeDamage', 'Heavy'),
        ],
        read: (r) {
          final e = r.edgeTreatment;
          if (e == null || e.edgeDamage == 0) return 'none';
          return e.style.name;
        },
        // 'Clean' is a treatment with nothing to tear, not a null one:
        // DesignRecipe.copyWith reads `edgeTreatment ?? this.edgeTreatment`,
        // so passing null KEEPS the current edge — an option that looked like
        // it turned tearing off and quietly did nothing.
        write: (r, id) => id == 'none'
            ? r.copyWith(
                edgeTreatment: const EdgeTreatment(
                  edgeDamage: 0,
                  frayAmount: 0,
                  cornerDamage: 0,
                  maxDepth: 0,
                ),
              )
            // Choosing a torn style brings damage with it. Copying the
            // current treatment would carry Clean's zeroes forward, so
            // picking "Ripped" after "Clean" would rip nothing.
            : r.copyWith(
                edgeTreatment: ((r.edgeTreatment?.edgeDamage ?? 0) > 0
                        ? r.edgeTreatment!
                        : const EdgeTreatment())
                    .copyWith(style: TearStyle.fromId(id))),
      ),
      // Which animal, plant or landmark — only when the clip IS one, and only
      // from the silhouettes bundled for the chosen countries.
      if (hasClip && silhouetteShapeIds.contains(clip.shapeId))
        FineTuneChoice(
          id: 'silhouette',
          label: 'Silhouette',
          helper: 'Which shape the flags fill.',
          group: FineTuneGroup.graphics,
          options: [
            for (final (kind, slug) in silhouetteOptions())
              if (kind.name == clip.shapeId)
                FineTuneOption(slug, silhouetteLabel(kind, slug)),
          ],
          read: (r) => r.clip?.code ?? '',
          write: (r, id) => r.copyWith(clip: r.clip!.copyWith(code: id)),
        ),
    ];
  }

  /// The groups that have something in them. An empty panel is not a panel.
  List<FineTuneGroup> fineTuneGroups() {
    final used = {
      for (final c in fineTuneControls()) c.group,
      for (final c in fineTuneChoices()) c.group,
      for (final c in graphicChoices()) c.group,
      for (final c in colourChoices()) c.group,
      for (final c in wordChoices()) c.group,
    };
    return [
      for (final g in FineTuneGroup.values)
        if (used.contains(g)) g
    ];
  }

  // ── M20: words and title ───────────────────────────────────────────────────

  /// Whether this design can carry a title at all.
  ///
  /// A `statementHero` composition draws the traveller's COUNT as the artwork
  /// ("28" over "COUNTRIES") and `TypographyStage` takes an entirely separate
  /// path for it — `meta['title']` is never read. Typing a title into such a
  /// design changes the recipe and nothing on the shirt, so Words & Title is
  /// not a step for it.
  bool get wordsApply => !current.composition.statementHero;

  /// The longest title the renderer lays out without shrinking it to nothing.
  ///
  /// `TypographyStage` fits the title to a band 16% of the frame high and then
  /// scales it down to fit the width. Past roughly this many characters the
  /// type is too small to read on a printed garment, so the field stops rather
  /// than letting someone buy an unreadable shirt.
  static const int maxTitleLength = 30;

  /// Plain-language names for the display faces, in the generator's own order.
  /// Copperplate is engraved rather than rounded — naming it for what it is
  /// beats borrowing a label from a face we do not have.
  static const List<String> titleFontLabels = [
    'Modern',
    'Bold',
    'Classic',
    'Engraved',
    'Condensed',
  ];

  /// Text controls for the CURRENT design.
  ///
  /// Same capability model as M16–M19. All three are gated on there BEING a
  /// title: with `meta['title']` empty, `TypographyStage` returns before it
  /// reads the face, the placement or the case, so a font picker over a
  /// title-less design is three controls that do nothing. The title field
  /// itself is always available (that is how a title gets added) — it is these
  /// treatments that wait for something to treat.
  ///
  /// Notably absent, and deliberately: TEXT COLOUR. The stage inks the title
  /// with `_legibleInk(background)` — a contrast tone derived from the garment,
  /// with no field on the recipe to override it. A row of colour swatches would
  /// be the most convincing inert control on the whole screen.
  /// Text SIZE and ROTATION are absent for the same reason: the size is fitted
  /// to the band and there is no rotation field.
  List<FineTuneChoice> wordChoices() {
    if (!wordsApply || currentTitle.trim().isEmpty) return const [];

    Typography typoOf(DesignRecipe r) => r.typography ?? const Typography();
    DesignRecipe write(DesignRecipe r, Typography t) =>
        r.copyWith(typography: t);

    return [
      FineTuneChoice(
        id: 'titleFont',
        label: 'Font style',
        helper: 'The face your title is set in.',
        group: FineTuneGroup.words,
        options: [
          for (var i = 0; i < LabShowcaseGenerator.titleFonts.length; i++)
            FineTuneOption(
              LabShowcaseGenerator.titleFonts[i],
              titleFontLabels[i],
              sample: 'Aa',
              fontFamily: LabShowcaseGenerator.titleFonts[i],
            ),
        ],
        read: (r) =>
            typoOf(r).titleStyle ?? LabShowcaseGenerator.titleFonts.first,
        write: (r, id) => write(r, Typography(
              titleStyle: id,
              textCase: typoOf(r).textCase,
              // A face is only visible once the title is placed. Choosing one
              // on a hidden title would look like it had done nothing.
              placement: typoOf(r).placement == TextPlacement.none
                  ? TextPlacement.bottom
                  : typoOf(r).placement,
            )),
      ),
      FineTuneChoice(
        id: 'textPlacement',
        label: 'Text position',
        helper: 'Where the title sits on the print.',
        group: FineTuneGroup.words,
        // `TextPlacement` has exactly three values and the renderer honours all
        // three — `none` is how a title is hidden without discarding the words.
        options: const [
          FineTuneOption('bottom', 'Bottom'),
          FineTuneOption('top', 'Top'),
          FineTuneOption('none', 'Hidden'),
        ],
        read: (r) => typoOf(r).placement.name,
        write: (r, id) => write(r, Typography(
              titleStyle: typoOf(r).titleStyle,
              textCase: typoOf(r).textCase,
              placement: TextPlacement.fromId(id),
            )),
      ),
      FineTuneChoice(
        id: 'textCase',
        label: 'Lettering',
        helper: 'How the words are cased.',
        group: FineTuneGroup.words,
        options: const [
          FineTuneOption('upper', 'UPPER'),
          FineTuneOption('title', 'Title'),
          FineTuneOption('lower', 'lower'),
          FineTuneOption('asIs', 'As typed'),
        ],
        read: (r) => typoOf(r).textCase.name,
        write: (r, id) => write(r, Typography(
              titleStyle: typoOf(r).titleStyle,
              textCase: TextCase.fromId(id),
              placement: typoOf(r).placement == TextPlacement.none
                  ? TextPlacement.bottom
                  : typoOf(r).placement,
            )),
      ),
    ];
  }

  // ── M19: colour, effects and print ─────────────────────────────────────────

  /// Duotone needs two accents or it does nothing.
  ///
  /// The renderer's duotone branch is `strategy == duotone && accents.length >= 2`,
  /// and every recipe the generator produces carries an EMPTY accent list — so a
  /// Duotone chip that wrote the strategy alone was a chip that changed the
  /// recipe id and left the artwork exactly as it was. The treatment supplies the
  /// pair it needs: a deep navy shadow lifting to the Roavvy orange, which is a
  /// real travel-poster duotone rather than a grey ramp.
  static const List<String> duotoneAccents = ['#14213D', '#E84C22'];

  /// Which colour treatment the design is currently wearing.
  static String _colourTreatmentOf(DesignRecipe r) {
    final p = r.palette ?? const Palette();
    switch (p.strategy) {
      case ColourStrategy.monochrome:
        return 'mono';
      case ColourStrategy.duotone:
        return 'duotone';
      case ColourStrategy.garmentAware:
        return 'garment';
      case ColourStrategy.flagDerived:
      case ColourStrategy.brand:
        // flagDerived and brand both mean "no colour filter" to the renderer,
        // so the aged grade is what separates the remaining looks.
        if (p.vintageGrade >= 0.55) return 'vintage';
        if (p.vintageGrade >= 0.15) return 'muted';
        return 'full';
    }
  }

  /// The whole-artwork effect currently in effect. Ordered most-dominant first:
  /// "Distressed" sets grain as well, so distress has to be read before it.
  static String _effectStyleOf(Effects fx) {
    if (fx.halftone > 0) return 'halftone';
    if (fx.distress > 0) return 'distressed';
    if (fx.grain > 0) return 'grain';
    if (fx.fade > 0) return 'faded';
    return 'none';
  }

  static String _printStyleOf(Effects fx) {
    if (fx.riso > 0) return 'riso';
    if (fx.newsprint > 0) return 'newsprint';
    if (fx.sunFaded > 0) return 'sunFaded';
    if (fx.photocopy > 0) return 'photocopy';
    return 'standard';
  }

  /// Colour, whole-artwork effects and print finish for the CURRENT design.
  ///
  /// Same capability model as M16–M18 — these are [FineTuneChoice]s in
  /// [FineTuneGroup.colour], so the panel that renders Layout and Graphics
  /// renders these too without knowing what they are. They are marked
  /// [FineTuneChoice.preview] because a colour grade or a print screen has to be
  /// SEEN to be chosen: the panel renders each option's own candidate recipe.
  ///
  /// Every option below writes a field the renderer actually reads. Notably
  /// absent: `Effects.cracks` and `Effects.acidWash` exist on the recipe and are
  /// read by nothing in `design_forge_render`, so a control for either would be
  /// inert — the same defect M17 found in `composition.jitter`.
  ///
  /// The three groups are kept disjoint so they compose rather than fight:
  /// colour writes only the palette, Effects writes only distress/grain/fade/
  /// halftone, and Print writes only riso/newsprint/sunFaded/photocopy. The
  /// Vibe's own effects (tie-dye, shatter, ripple) are carried through
  /// untouched by all three.
  List<FineTuneChoice> colourChoices() {
    final r = current;
    // The colour stage bails on a recipe it cannot grade; so does this screen.
    if (r.content.flags.isEmpty && r.typography == null && r.clip == null) {
      return const [];
    }

    return [
      FineTuneChoice(
        id: 'colourTreatment',
        label: 'Colour treatment',
        helper: 'How the artwork is coloured — not the shirt.',
        group: FineTuneGroup.colour,
        preview: true,
        options: [
          const FineTuneOption('full', 'Full colour'),
          const FineTuneOption('muted', 'Muted'),
          const FineTuneOption('vintage', 'Vintage'),
          const FineTuneOption('mono', 'Monochrome'),
          const FineTuneOption('duotone', 'Duotone'),
          // Garment-aware re-inks ADAPTIVE ink only. On a flag design the
          // renderer skips the branch entirely, so the chip would be a
          // decoration — it is offered only where it can be seen.
          if (r.inkIsAdaptive) const FineTuneOption('garment', 'Match shirt'),
        ],
        read: _colourTreatmentOf,
        write: (r, id) {
          final p = r.palette ?? const Palette();
          return switch (id) {
            'full' => r.copyWith(
                palette: p.copyWith(
                    strategy: ColourStrategy.flagDerived, vintageGrade: 0.0)),
            'muted' => r.copyWith(
                palette: p.copyWith(
                    strategy: ColourStrategy.flagDerived, vintageGrade: 0.35)),
            'vintage' => r.copyWith(
                palette: p.copyWith(
                    strategy: ColourStrategy.flagDerived, vintageGrade: 0.75)),
            'mono' => r.copyWith(
                palette: p.copyWith(
                    strategy: ColourStrategy.monochrome, vintageGrade: 0.0)),
            'duotone' => r.copyWith(
                palette: p.copyWith(
                  strategy: ColourStrategy.duotone,
                  accents: duotoneAccents,
                  vintageGrade: 0.0,
                )),
            'garment' => r.copyWith(
                palette: p.copyWith(
                    strategy: ColourStrategy.garmentAware, vintageGrade: 0.0)),
            _ => r,
          };
        },
      ),
      FineTuneChoice(
        id: 'effectStyle',
        label: 'Effects',
        helper: 'A treatment over the whole artwork.',
        group: FineTuneGroup.colour,
        preview: true,
        options: const [
          FineTuneOption('none', 'None'),
          FineTuneOption('faded', 'Faded'),
          FineTuneOption('distressed', 'Distressed'),
          FineTuneOption('grain', 'Grain'),
          FineTuneOption('halftone', 'Halftone'),
        ],
        read: (r) => _effectStyleOf(r.effects ?? const Effects()),
        write: (r, id) {
          final fx = r.effects ?? const Effects();
          // Only the four effect fields move; the print finish and the Vibe's
          // tie-dye / shatter / ripple ride through untouched.
          final next = switch (id) {
            'none' => fx.copyWith(distress: 0, grain: 0, fade: 0, halftone: 0),
            'faded' =>
              fx.copyWith(distress: 0, grain: 0, fade: 0.5, halftone: 0),
            'distressed' => fx.copyWith(
                distress: 0.55, grain: 0.35, fade: 0, halftone: 0),
            'grain' => fx.copyWith(distress: 0, grain: 0.6, fade: 0, halftone: 0),
            'halftone' => fx.copyWith(
                distress: 0, grain: 0, fade: 0, halftone: 0.8, halftoneScale: 5),
            _ => fx,
          };
          return r.copyWith(effects: next);
        },
      ),
      FineTuneChoice(
        id: 'printStyle',
        label: 'Print style',
        helper: 'How it looks coming off the press.',
        group: FineTuneGroup.colour,
        preview: true,
        options: const [
          FineTuneOption('standard', 'Standard'),
          FineTuneOption('riso', 'Riso'),
          FineTuneOption('newsprint', 'Newsprint'),
          FineTuneOption('sunFaded', 'Sun-faded'),
          FineTuneOption('photocopy', 'Photocopy'),
        ],
        read: (r) => _printStyleOf(r.effects ?? const Effects()),
        write: (r, id) {
          final fx = r.effects ?? const Effects();
          // Exactly one press finish at a time — they are alternative presses,
          // not layers, and stacking two just muddies the artwork.
          final next = fx.copyWith(
            riso: id == 'riso' ? 0.9 : 0.0,
            newsprint: id == 'newsprint' ? 0.8 : 0.0,
            sunFaded: id == 'sunFaded' ? 0.7 : 0.0,
            photocopy: id == 'photocopy' ? 0.8 : 0.0,
          );
          return r.copyWith(effects: next);
        },
      ),
    ];
  }

  /// The design as it was before the current continuous edit began.
  DesignRecipe? _editBase;

  /// A Fine Tune change made in one go — a chip tap rather than a drag. One
  /// decision, one undo step.
  void commitFineTune(DesignRecipe next) => _commit(next);

  /// Start a continuous edit (a slider touched). The drag itself edits live;
  /// this remembers where to undo back to.
  void beginEdit() => _editBase ??= current;

  /// End it: everything the drag did becomes ONE undo step, rather than one
  /// per frame.
  void endEdit() {
    final base = _editBase;
    _editBase = null;
    if (base == null || base.recipeId == current.recipeId) return;
    _history.add(base);
    _observe(current, PreferenceSignal.styleChosen);
  }

  /// Put the Fine Tune parameters back where the design started, leaving the
  /// travels, Direction, Detail, Vibe, garment and title exactly as they are.
  ///
  /// A reset of the dials, not of the design: it re-cuts the current subject
  /// in the current style and keeps only the tuned fields from that, so
  /// nothing the customer chose earlier in the flow is touched.
  /// Put the Fine Tune dials back to what this design was generated with.
  ///
  /// Scoped to [only] when a single group is on screen: the Colour screen's
  /// Reset must not quietly undo the Layout and Graphics work done two steps
  /// earlier. `null` resets every group, which is what the M16 overview — the
  /// one screen that shows them all — means by the word.
  ///
  /// Nothing outside Fine Tune moves either way: the countries, the Direction
  /// and its Detail, the Vibe, the title text and the GARMENT colour are the
  /// wearer's choices, not dial positions.
  void resetFineTune({FineTuneGroup? only}) {
    bool wants(FineTuneGroup g) => only == null || only == g;

    final prev = current;
    var gen = _gen;
    final style = currentStyle;
    if (style != null) gen = gen.withStyle(style);
    final fresh = gen
        .generate(_context, seed: _selectionSeed(_context.flagCodes), count: 1)
        .first;

    var next = prev;
    if (wants(FineTuneGroup.layout)) {
      next = next.copyWith(
        composition: next.composition.copyWith(
          sizeClass: fresh.composition.sizeClass,
          copiesPerCountry: fresh.composition.copiesPerCountry,
          fillAlgorithm: fresh.composition.fillAlgorithm,
        ),
      );
    }
    if (wants(FineTuneGroup.colour)) {
      next = next.copyWith(
        // A generated recipe may carry no effects at all; that IS the default,
        // so reset must take it rather than keep what the sliders did.
        effects: fresh.effects ?? const Effects(),
        // The strategy and its accents are colour-treatment state too — without
        // them a design stays in Duotone with the "Full colour" chip lit. The
        // garment colour is carried forward: it is the wearer's blank, not a
        // finish.
        palette: (next.palette ?? const Palette()).copyWith(
          vintageGrade: fresh.palette?.vintageGrade ?? 0,
          strategy: fresh.palette?.strategy ?? ColourStrategy.flagDerived,
          accents: fresh.palette?.accents ?? const [],
        ),
      );
    }
    if (wants(FineTuneGroup.graphics)) {
      final clip = next.clip;
      if (clip != null && fresh.clip != null) {
        next = next.copyWith(
          clip: clip.copyWith(
            scale: fresh.clip!.scale,
            rotationDeg: fresh.clip!.rotationDeg,
            feather: fresh.clip!.feather,
          ),
        );
      }
    }
    if (wants(FineTuneGroup.words)) {
      // The TREATMENT returns to the generated default; the words themselves
      // are what the wearer wrote and are left alone. A design generated
      // without typography resets to having none, which is its default.
      next = next.copyWith(typography: fresh.typography ?? const Typography());
    }
    _commit(next);
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
  Rect frontPrintRect() => frontPrintRectFor(_frontFit);

  /// The print rect a given [fit] would use, at the CURRENT chest side.
  ///
  /// Exposed so the Front Design step can draw each option from the same
  /// geometry the printer is handed, rather than from a picture of it.
  Rect frontPrintRectFor(FrontFit fit) {
    switch (fit) {
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
      final all = allTravelledCodes;
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

  /// The seed the complement front was derived with.
  ///
  /// Kept so the complement can be RE-derived from a changed back without
  /// becoming a different design every time: rerolling on each rebuild would
  /// mean toggling one country in Travels handed back an unrecognisable front.
  int? _complementSeed;

  /// Rebuild the front face from the back, honouring the chosen [FrontArt].
  ///
  /// The front used to be rebuilt as a ribbon unconditionally wherever the back
  /// changed — so going back to Travels and toggling a single country silently
  /// threw away a Match-back or Complement front. The front follows the back;
  /// it does not get replaced by it.
  void _rebuildFront() {
    switch (_frontArt) {
      case FrontArt.ribbon:
        _frontFace = _ribbonOf(_hero);
      case FrontArt.complement:
        _frontFace = GarmentDesign.deriveBack(_hero,
            themeSeed: _complementSeed ??= _nextSeed(),
            garmentColour: _hero.palette?.garmentColour);
      case FrontArt.matchBack:
        _frontFace = _hero;
    }
  }

  void setFrontArt(FrontArt art) {
    _frontArt = art;
    // A fresh pick of Complement earns a fresh interpretation; a rebuild
    // caused by the back changing keeps the one already on screen.
    if (art == FrontArt.complement) _complementSeed = _nextSeed();
    _rebuildFront();
    notifyListeners();
  }

  void setRibbonCoverage(bool all) {
    _ribbonAllCountries = all;
    _rebuildFront();
    notifyListeners();
  }

  /// Put the FRONT back to how a design arrives — chest, left, flag ribbon of
  /// the countries chosen for this design.
  ///
  /// The completed back is not touched: not its artwork, not its words, not the
  /// garment. Front configuration is view/print state beside the back design,
  /// never a modification of it.
  void resetFront() {
    _frontFit = FrontFit.chest;
    _chestRight = false;
    _frontArt = FrontArt.ribbon;
    _ribbonAllCountries = false;
    _complementSeed = null;
    _rebuildFront();
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
    _applyTravelToFaces();
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

  /// Re-cut the design for a changed travel selection.
  ///
  /// Customise EDITS the design already on the shirt — someone who liked a
  /// design enough to customise it, then removed a country, must still be
  /// looking at that design. So only the travel-dependent half of the recipe
  /// moves: the flags, and the dated entries behind passport stamps and
  /// timelines, both taken from a freshly generated recipe because building
  /// them correctly is the generator's job. Everything creative — the family,
  /// the clip, the palette treatment, the effects, the typography, the title —
  /// is carried over from what was on screen.
  ///
  /// This replaced a full regeneration that took the best of a fresh pool. It
  /// gave a well-made design, but not the one being edited: changing one
  /// country silently swapped the shirt out from under the customer.
  void _applyTravelToFaces() {
    final prev = _hero;
    final recut = _gen
        .generate(_context, seed: _selectionSeed(_context.flagCodes), count: 1)
        .first;
    _hero = prev.copyWith(
      content: RecipeContent(
        // Travel-dependent, so taken from the recut.
        flags: recut.content.flags,
        entries: recut.content.entries,
        source: recut.content.source,
        // Meta is where the customer's own words live — the title above all.
        // Taking the recut's wholesale silently wiped a title the moment a
        // country was toggled. Theirs wins; the recut only fills gaps.
        meta: {...recut.content.meta, ...prev.content.meta},
      ),
    );
    _rebuildFront();
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

  /// The design became a real order.
  ///
  /// Keeps it in the wardrobe permanently and tags it as printed, so
  /// re-ordering never means re-designing. Called once the order actually
  /// exists, never at the moment of handing off to checkout — an abandoned
  /// checkout is not a shirt.
  void markOrdered() {
    library?.markGarmentOrdered(garment);
    notifyListeners();
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
