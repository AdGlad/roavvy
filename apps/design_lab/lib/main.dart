import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/material.dart';

import 'flag_source.dart';
import 'lab_generator.dart';
import 'lab_styles.dart';
import 'preference_survey.dart';
import 'recipe_editor.dart';
import 'render_service.dart';

void main() => runApp(const DesignLabApp());

class DesignLabApp extends StatelessWidget {
  const DesignLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roavvy Design Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0F12),
      ),
      home: const LabHome(),
    );
  }
}

class LabHome extends StatefulWidget {
  const LabHome({super.key});
  @override
  State<LabHome> createState() => _LabHomeState();
}

enum _GeneratorMode { style, smart }

class _LabHomeState extends State<LabHome> {
  // Rebuilt when the style changes or once silhouette/continent assets are
  // indexed (see _boot) so the rotation can offer the country's own silhouettes.
  LabStyle _style = LabStyle.showcase;
  // Data-driven template (null = the flag/clip showcase). Timeline/journeys/
  // wordCloud render from the travel history + date range.
  DesignFamily? _template;
  LabShowcaseGenerator _generator = const LabShowcaseGenerator();

  FlagSource? _source;
  RenderService? _service;
  List<String> _allCodes = [];
  Map<ClipShape, List<String>> _silhouettesByShape = {};
  List<String> _continents = [];
  Map<String, String> _countryNames = const {};
  final Set<String> _selectedFlags = {'us', 'gb'};
  String _flagQuery = '';

  int _baseSeed = 1;
  int _count = 48;

  List<DesignRecipe> _recipes = [];
  late PersistentDesignLibrary _lib;
  _ViewMode _view = _ViewMode.batch;
  DesignRecipe? _inspected;

  // ── Recommendation system (Steps 3–6) ──
  _GeneratorMode _mode = _GeneratorMode.style;
  DesignPreferences _preferences = DesignPreferences.neutral;
  SimulatedTravelContext _travelProfile = const SimulatedTravelContext();
  PreferencePersistence? _persistence;
  _LeftTab _leftTab = _LeftTab.generate;
  // Variation drill-down (Step 5)
  List<RecipeVariation>? _variations;

  String _status = 'Locating flag assets…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _boot() {
    final source = FlagSource.locate();
    if (source == null) {
      setState(() => _status =
          'Could not find flag SVGs. Expected apps/mobile_flutter/assets/flags/svg.');
      return;
    }
    _source = source;
    _service = RenderService(source.resolver());
    _allCodes = source.codes();
    // Simulated "visited countries" universe (macOS has no real travel history):
    // a deterministic roster with trips across the year range. The Trips slider
    // populates the flag selection from whoever was visited in the window.
    _allTrips = _simulatedTrips(_visitedRoster());
    final byKind = source.silhouettesByKind();
    _silhouettesByShape = {
      ClipShape.animalSilhouette: byKind['animal'] ?? const [],
      ClipShape.plantSilhouette: byKind['plant'] ?? const [],
      ClipShape.landmarkSilhouette: byKind['landmark'] ?? const [],
      ClipShape.passportStampOutline: source.passportStampSlugs(),
    };
    _continents = source.continents();
    _countryNames = source.countryNames();
    _rebuildGenerator();
    // The reproducible design library (liked + used-for-t-shirt), persisted
    // locally as full recipes so any kept design can be re-rendered later.
    _lib = PersistentDesignLibrary(
        _FileDesignStore(File('${source.labOutputDir.path}/library.json')));
    _lib.load().then((_) {
      if (mounted) setState(() {});
    });
    // Load persisted preferences + travel profile.
    _persistence = PreferencePersistence(source.labOutputDir);
    _persistence!.loadPreferences().then((p) {
      if (p != null && mounted) setState(() => _preferences = p);
    });
    _persistence!.loadProfile().then((p) {
      if (p != null && mounted) setState(() => _travelProfile = p);
    });
    setState(() => _status = '${_allCodes.length} flags loaded');
    _generate();
  }

  void _rebuildGenerator() {
    _generator = LabShowcaseGenerator(
      style: _style,
      template: _template,
      silhouettesByShape: _silhouettesByShape,
      continents: _continents,
      countryNames: _countryNames,
    );
  }

  Future<void> _toggleLike(DesignRecipe r) async {
    final wasLiked = _lib.library.isLiked(r.recipeId);
    await _lib.toggleLike(r);
    // Step 6: feed preference signal.
    if (!wasLiked) {
      _updatePreferencesFromSignal(r, PreferenceSignal.saved);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleTshirt(DesignRecipe r) async {
    final wasUsed = _lib.library.isUsedForTshirt(r.recipeId);
    await _lib.setUsedForTshirt(r, !wasUsed);
    // Step 6: strongest positive signal.
    if (!wasUsed) {
      _updatePreferencesFromSignal(r, PreferenceSignal.selectedForMockup);
    }
    if (mounted) setState(() {});
  }

  /// Step 6: Update preferences via exponential moving average on interaction.
  void _updatePreferencesFromSignal(DesignRecipe r, PreferenceSignal signal) {
    _preferences = const PreferenceLearner().observe(_preferences, r, signal);
    _persistence?.savePreferences(_preferences);
  }

  // Date-range filter for the studio design options. macOS has no real travel
  // history, so the Lab synthesises a deterministic trip set per country; the
  // range filters which trips feed passport/timeline/etc. designs.
  static const _minYear = 2018;
  static const _maxYear = 2026;
  RangeValues _years = const RangeValues(2018, 2026);

  /// Optional: when on, moving the Trips slider populates the flag selection
  /// with the countries visited within the range.
  bool _restrictToRange = false;

  /// The simulated "visited countries" universe (built at boot).
  List<Trip> _allTrips = const [];

  /// A deterministic set of "visited" countries (those that have trips). Uses a
  /// familiar roster, intersected with the flags actually available.
  List<String> _visitedRoster() {
    const roster = [
      'us', 'gb', 'fr', 'de', 'jp', 'br', 'au', 'it', 'es', 'ca',
      'sc', 'in', 'cn', 'mx', 'za', 'th', 'gr', 'pt', 'nl', 'se',
    ];
    final available = _allCodes.toSet();
    final present = [for (final c in roster) if (available.contains(c)) c];
    return present.isEmpty ? _allCodes.take(12).toList() : present;
  }

  /// Distinct countries with a trip overlapping [range], first-visited order.
  List<String> _visitedInRange(DateRange range) =>
      TravelHistory(_allTrips.where(range.overlaps).toList()).countryCodes;

  bool get _yearsIsAll =>
      _years.start <= _minYear && _years.end >= _maxYear;

  DateRange get _dateRange => _yearsIsAll
      ? DateRange.all
      : DateRange.years(_years.start.round(), _years.end.round());

  /// Deterministic simulated trips for [codes] — 1–3 trips per country spread
  /// across [_minYear].._maxYear, so the date-range filter has data to act on.
  List<Trip> _simulatedTrips(List<String> codes) {
    final trips = <Trip>[];
    for (final cc in codes) {
      final r = DeterministicRng(_stableSeed('trips:$cc')).stream('trip');
      final n = 1 + r.nextInt(3);
      for (var i = 0; i < n; i++) {
        final year = _minYear + r.nextInt(_maxYear - _minYear + 1);
        final month = 1 + r.nextInt(12);
        final day = 1 + r.nextInt(24);
        final stay = 3 + r.nextInt(14);
        final start = DateTime(year, month, day);
        trips.add(Trip(
          countryCode: cc,
          startedOn: start,
          endedOn: start.add(Duration(days: stay)),
          photoCount: 10 + r.nextInt(200),
        ));
      }
    }
    return trips;
  }

  static int _stableSeed(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 0x01000193;
      h &= 0x7fffffff;
    }
    return h;
  }

  DesignContext get _context {
    final range = _dateRange;
    // When restricting, the selection has already been populated from the range,
    // so an empty selection genuinely means "nothing visited" (no 'us' fallback).
    final selected = _selectedFlags.isEmpty && !_restrictToRange
        ? ['us']
        : _selectedFlags.toList();
    // Trips (deterministic per country) for the selected countries, in range.
    final trips =
        _simulatedTrips(selected).where(range.overlaps).toList();
    return DesignContext(
      flagCodes: selected,
      trips: trips,
      dateRange: range,
      scopeKey: 'lab:${selected.join("+")}'
          '${_yearsIsAll ? '' : ':${_years.start.round()}-${_years.end.round()}'}',
    );
  }

  /// Populate the flag selection from the countries visited in the current range
  /// (used when the "auto-select from range" toggle is on and the slider moves).
  void _syncSelectionToRange() {
    _selectedFlags
      ..clear()
      ..addAll(_visitedInRange(_dateRange));
  }

  void _generate() {
    final RecipeGenerator gen;
    if (_template != null) {
      // A data-driven template always uses the showcase generator (which owns
      // the template path); Smart mode doesn't apply.
      gen = _generator;
    } else if (_mode == _GeneratorMode.smart) {
      gen = LabSmartGenerator(
        preferences: _preferences,
        silhouettesByShape: _silhouettesByShape,
        continents: _continents,
        countryNames: _countryNames,
        poolSize: 150,
        outputCount: _count < 8 ? _count : 8,
      );
    } else {
      gen = _generator;
    }
    final ctx = _context;
    if (ctx.flagCodes.isEmpty) {
      // "Only in range" is on but no country was visited in the window.
      setState(() {
        _recipes = [];
        _inspected = null;
        _variations = null;
        _status = 'No countries visited in '
            '${_years.start.round()}–${_years.end.round()}';
      });
      return;
    }
    setState(() {
      _recipes = gen.generate(ctx, seed: _baseSeed, count: _count);
      _inspected = null;
      _variations = null;
      _status = _mode == _GeneratorMode.smart
          ? 'Smart: ${_recipes.length} designs (seed $_baseSeed)'
          : 'Generated ${_recipes.length} designs (seed $_baseSeed)';
    });
  }

  /// Step 5: "More Like This" with VariationGenerator.
  void _moreLikeThis(DesignRecipe r) {
    const varGen = VariationGenerator();
    final vars = varGen.variate(r, count: 12);
    setState(() {
      _variations = vars;
      _status = 'Variations of seed ${r.seed}';
    });
  }

  void _variationsOf(DesignRecipe r) {
    // Original "More like this": same flags, seeds around the parent seed.
    // Now also sets up the variation view.
    _moreLikeThis(r);
  }

  Future<void> _reproduce(String seedText) async {
    final seed = int.tryParse(seedText.trim());
    if (seed == null) return;
    final r = _generator.generate(_context, seed: seed, count: 1).first;
    setState(() {
      _inspected = r;
      _status = 'Reproduced seed $seed → ${r.recipeId}';
    });
  }

  Future<void> _exportPng(DesignRecipe r) async {
    final res = await _service!.renderFull(r, 1600);
    final file = File('${_source!.labOutputDir.path}/${r.recipeId}.png');
    await file.writeAsBytes(res.pngBytes);
    _toast('Exported ${file.path}');
  }

  Future<void> _exportContactSheet() async {
    _toast('Building contact sheet…');
    final sheet = await const ContactSheetBuilder(columns: 6, cell: 240)
        .build(_recipes, _service!.renderer);
    final file = File(
        '${_source!.labOutputDir.path}/contact_sheet_seed${_baseSeed}_${_recipes.length}.png');
    await file.writeAsBytes(sheet);
    _toast('Contact sheet: ${file.path}');
  }

  Future<void> _openSurvey() async {
    final result = await PreferenceSurveyDialog.show(
      context,
      initial: _preferences,
      service: _service!,
      allCodes: _allCodes,
    );
    if (result != null) {
      setState(() => _preferences = result);
      _persistence?.savePreferences(result);
      if (_mode == _GeneratorMode.smart) _generate();
    }
  }

  void _toast(String msg) {
    setState(() => _status = msg);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) {
      return Scaffold(body: Center(child: Text(_status)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roavvy Design Lab'),
        backgroundColor: const Color(0xFF16181D),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(_status, style: const TextStyle(fontSize: 12))),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _leftPanel(),
          const VerticalDivider(width: 1),
          Expanded(child: _gallery()),
          if (_inspected != null) ...[
            const VerticalDivider(width: 1),
            RecipeEditorPanel(
              recipe: _inspected!,
              service: _service!,
              silhouettesByShape: _silhouettesByShape,
              continents: _continents,
              countryNames: _countryNames,
              onExportPng: _exportPng,
              onVariations: _variationsOf,
              onClose: () => setState(() => _inspected = null),
            ),
          ],
        ],
      ),
    );
  }

  // ---- Left panel: tabs for Generate + Profile ----
  Widget _leftPanel() {
    return SizedBox(
      width: 280,
      child: Container(
        color: const Color(0xFF16181D),
        child: Column(
          children: [
            // Tab bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<_LeftTab>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: _LeftTab.generate, label: Text('Generate')),
                  ButtonSegment(value: _LeftTab.profile, label: Text('Profile')),
                ],
                selected: {_leftTab},
                onSelectionChanged: (s) => setState(() => _leftTab = s.first),
              ),
            ),
            const Divider(),
            Expanded(
              child: _leftTab == _LeftTab.generate
                  ? _generatePanel()
                  : _profilePanel(),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Generate tab (original left panel content) ----
  Widget _generatePanel() {
    final filtered = _flagQuery.isEmpty
        ? _allCodes
        : _allCodes.where((c) => c.contains(_flagQuery)).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FLAGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final c in _selectedFlags)
                Chip(
                  label: Text(c.toUpperCase()),
                  onDeleted: () => setState(() => _selectedFlags.remove(c)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'search code (e.g. jp)…',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _flagQuery = v.toLowerCase().trim()),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 3,
            child: ListView(
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in filtered.take(200))
                      FilterChip(
                        label: Text(c.toUpperCase(), style: const TextStyle(fontSize: 11)),
                        selected: _selectedFlags.contains(c),
                        visualDensity: VisualDensity.compact,
                        onSelected: (s) => setState(() {
                          if (s) {
                            _selectedFlags.add(c);
                          } else {
                            _selectedFlags.remove(c);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // Mode toggle: Style vs Smart
          Row(
            children: [
              const Text('Mode '),
              Expanded(
                child: SegmentedButton<_GeneratorMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: _GeneratorMode.style, label: Text('Style')),
                    ButtonSegment(value: _GeneratorMode.smart, label: Text('Smart')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) {
                    setState(() => _mode = s.first);
                    _generate();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Template '),
              Expanded(
                child: DropdownButton<DesignFamily?>(
                  isExpanded: true,
                  isDense: true,
                  value: _template,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Showcase (flags)')),
                    DropdownMenuItem(
                        value: DesignFamily.timeline, child: Text('Timeline')),
                    DropdownMenuItem(
                        value: DesignFamily.journeys, child: Text('Journeys')),
                    DropdownMenuItem(
                        value: DesignFamily.wordCloud, child: Text('Word cloud')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _template = v;
                      _rebuildGenerator();
                    });
                    _generate();
                  },
                ),
              ),
            ],
          ),
          if (_template == null && _mode == _GeneratorMode.style)
            Row(
              children: [
                const Text('Style '),
                Expanded(
                  child: DropdownButton<LabStyle>(
                    isExpanded: true,
                    isDense: true,
                    value: _style,
                    items: [
                      for (final s in LabStyle.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _style = v;
                        _rebuildGenerator();
                      });
                      _generate();
                    },
                  ),
                ),
              ],
            ),
          _dateRangeRow(),
          Row(
            children: [
              const Text('Seed '),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: '$_baseSeed'),
                  decoration: const InputDecoration(isDense: true),
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) => _baseSeed = int.tryParse(v) ?? _baseSeed,
                ),
              ),
            ],
          ),
          if (_mode == _GeneratorMode.style)
            Row(
              children: [
                const Text('Count '),
                Expanded(
                  child: Slider(
                    value: _count.toDouble(),
                    min: 6,
                    max: 240,
                    divisions: 39,
                    label: '$_count',
                    onChanged: (v) => setState(() => _count = v.round()),
                  ),
                ),
                Text('$_count'),
              ],
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.grid_view, size: 16),
                label: Text(_mode == _GeneratorMode.smart ? 'Recommend' : 'Generate'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _baseSeed += _count);
                  _generate();
                },
                icon: const Icon(Icons.casino, size: 16),
                label: const Text('Next batch'),
              ),
              OutlinedButton.icon(
                onPressed: _exportContactSheet,
                icon: const Icon(Icons.dashboard, size: 16),
                label: const Text('Contact sheet'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Reproduce from seed',
              suffixIcon: Icon(Icons.replay, size: 18),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: _reproduce,
          ),
        ],
      ),
    );
  }

  // ---- Profile tab (Step 3 + Step 4 trigger) ----
  Widget _profilePanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Text('TRAVEL PROFILE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          // Persona dropdown
          Row(
            children: [
              const Text('Persona '),
              Expanded(
                child: DropdownButton<TravelPersona>(
                  isExpanded: true,
                  isDense: true,
                  value: _travelProfile.persona,
                  items: [
                    for (final p in TravelPersona.values)
                      DropdownMenuItem(
                        value: p,
                        child: Text(p.label, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _travelProfile = SimulatedTravelContext(
                          visitedCountries: _travelProfile.visitedCountries,
                          signatureCountries: _travelProfile.signatureCountries,
                          persona: v,
                        ));
                    _persistence?.saveProfile(_travelProfile);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _travelProfile.persona.description,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          // Visited countries
          const Text('Visited Countries',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final c in _travelProfile.visitedCountries)
                Chip(
                  label: Text(c.toUpperCase()),
                  onDeleted: () {
                    final updated = Set<String>.from(_travelProfile.visitedCountries)
                      ..remove(c);
                    final sig = Set<String>.from(_travelProfile.signatureCountries)
                      ..remove(c);
                    setState(() => _travelProfile = SimulatedTravelContext(
                          visitedCountries: updated,
                          signatureCountries: sig,
                          persona: _travelProfile.persona,
                        ));
                    _persistence?.saveProfile(_travelProfile);
                  },
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          _CountryAdder(
            allCodes: _allCodes,
            excluded: _travelProfile.visitedCountries,
            onAdd: (code) {
              final updated = Set<String>.from(_travelProfile.visitedCountries)
                ..add(code);
              setState(() => _travelProfile = SimulatedTravelContext(
                    visitedCountries: updated,
                    signatureCountries: _travelProfile.signatureCountries,
                    persona: _travelProfile.persona,
                  ));
              _persistence?.saveProfile(_travelProfile);
            },
          ),
          const SizedBox(height: 12),
          // Signature countries (subset of visited, 1–3)
          const Text('Signature Countries (1–3)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (_travelProfile.visitedCountries.isEmpty)
            const Text('Add visited countries first',
                style: TextStyle(fontSize: 11, color: Colors.white38))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in _travelProfile.visitedCountries)
                  FilterChip(
                    label: Text(c.toUpperCase()),
                    selected: _travelProfile.signatureCountries.contains(c),
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      final sig =
                          Set<String>.from(_travelProfile.signatureCountries);
                      if (selected && sig.length < 3) {
                        sig.add(c);
                      } else {
                        sig.remove(c);
                      }
                      setState(() => _travelProfile = SimulatedTravelContext(
                            visitedCountries: _travelProfile.visitedCountries,
                            signatureCountries: sig,
                            persona: _travelProfile.persona,
                          ));
                      _persistence?.saveProfile(_travelProfile);
                    },
                  ),
              ],
            ),
          const Divider(height: 24),
          const Text('PREFERENCES',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          // Show current preference summary
          _prefSummaryRow('Styles', _preferences.styleWeights.entries
              .where((e) => e.value > 1.2)
              .map((e) => e.key.label)
              .toList()),
          _prefSummaryRow('Shapes', _preferences.shapeWeights.entries
              .where((e) => e.value > 1.2)
              .map((e) => e.key.label)
              .toList()),
          if (_preferences.prefersDarkGarment != null)
            _prefSummaryRow('Garment',
                [_preferences.prefersDarkGarment! ? 'Dark' : 'Light']),
          if (_preferences.prefersVibrant != null)
            _prefSummaryRow('Color',
                [_preferences.prefersVibrant! ? 'Vibrant' : 'Muted']),
          Text('Interactions: ${_preferences.sampleCount}',
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openSurvey,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Take Preference Survey'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _preferences = DesignPreferences.neutral);
              _persistence?.savePreferences(_preferences);
            },
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Reset Preferences'),
          ),
        ],
      ),
    );
  }

  Widget _prefSummaryRow(String label, List<String> values) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('$label:',
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              values.isEmpty ? 'None' : values.join(', '),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Center: gallery ----
  Widget _gallery() {
    // Which designs to show: the current batch, or the persisted library
    // (liked / used-for-t-shirt) re-rendered from their stored recipes.
    final List<DesignRecipe> items = switch (_view) {
      _ViewMode.batch => _recipes,
      _ViewMode.liked => [for (final e in _lib.library.liked) e.recipe],
      _ViewMode.tshirts => [for (final e in _lib.library.usedForTshirt) e.recipe],
    };

    return Column(
      children: [
        _viewBar(),
        // Step 5: Variation drill-down panel.
        if (_variations != null && _view == _ViewMode.batch) _variationPanel(),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(switch (_view) {
                  _ViewMode.batch => 'Select flags and press Generate',
                  _ViewMode.liked => 'No liked designs yet — tap the heart on a design',
                  _ViewMode.tshirts => 'No designs marked as used for a t-shirt yet',
                }))
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _galleryTile(items[i]),
                ),
        ),
      ],
    );
  }

  /// Step 5: Shows variations grouped by axis.
  Widget _variationPanel() {
    final vars = _variations!;
    // Group by axis.
    final byAxis = <VariationAxis, List<RecipeVariation>>{};
    for (final v in vars) {
      (byAxis[v.axis] ??= []).add(v);
    }
    return Container(
      color: const Color(0xFF1A1D22),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('More Like This',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              IconButton(
                iconSize: 16,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _variations = null),
              ),
            ],
          ),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final axis in byAxis.keys) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(axis.label,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white54)),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Row(
                            children: [
                              for (final v in byAxis[axis]!)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _inspected = v.recipe;
                                    }),
                                    child: SizedBox(
                                      width: 100,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _inspected?.recipeId ==
                                                    v.recipe.recipeId
                                                ? Colors.tealAccent
                                                : const Color(0xFF2A2D33),
                                          ),
                                          color: const Color(0xFFF2F2F2),
                                        ),
                                        child: _RecipeTile(
                                          service: _service!,
                                          recipe: v.recipe,
                                          size: 100,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Studio design option: filter designs to trips within a year range. Feeds
  /// real (simulated, on macOS) trip dates into passport/timeline designs.
  Widget _dateRangeRow() {
    final label = _yearsIsAll
        ? 'All years'
        : '${_years.start.round()}–${_years.end.round()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Trips'),
            const Spacer(),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        RangeSlider(
          values: _years,
          min: _minYear.toDouble(),
          max: _maxYear.toDouble(),
          divisions: _maxYear - _minYear,
          labels: RangeLabels(
              '${_years.start.round()}', '${_years.end.round()}'),
          onChanged: (v) => setState(() => _years = v),
          onChangeEnd: (_) {
            if (_restrictToRange) setState(_syncSelectionToRange);
            _generate();
          },
        ),
        // Optional: the slider populates the flag selection with the countries
        // visited within the range.
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('Auto-select countries visited in range',
                style: TextStyle(fontSize: 11)),
            selected: _restrictToRange,
            visualDensity: VisualDensity.compact,
            onSelected: (v) {
              setState(() {
                _restrictToRange = v;
                if (v) _syncSelectionToRange();
              });
              _generate();
            },
          ),
        ),
      ],
    );
  }

  Widget _viewBar() {
    final likedN = _lib.library.liked.length;
    final tshirtN = _lib.library.usedForTshirt.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          SegmentedButton<_ViewMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              const ButtonSegment(value: _ViewMode.batch, label: Text('Batch')),
              ButtonSegment(value: _ViewMode.liked, label: Text('Liked ($likedN)')),
              ButtonSegment(
                  value: _ViewMode.tshirts, label: Text('T-shirts ($tshirtN)')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ],
      ),
    );
  }

  Widget _galleryTile(DesignRecipe r) {
    final liked = _lib.library.isLiked(r.recipeId);
    final tshirt = _lib.library.isUsedForTshirt(r.recipeId);
    final isSel = _inspected?.recipeId == r.recipeId;
    return GestureDetector(
      onTap: () => setState(() => _inspected = r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSel ? Colors.tealAccent : const Color(0xFF2A2D33),
                width: isSel ? 2 : 1,
              ),
              color: const Color(0xFFF2F2F2),
            ),
            child: _RecipeTile(service: _service!, recipe: r, size: 200),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Row(
              children: [
                IconButton(
                  iconSize: 18,
                  tooltip: 'More like this',
                  icon: const Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
                  onPressed: () => _moreLikeThis(r),
                ),
                IconButton(
                  iconSize: 18,
                  tooltip: tshirt ? 'Used for a t-shirt' : 'Mark used for t-shirt',
                  icon: Icon(tshirt ? Icons.checkroom : Icons.checkroom_outlined,
                      color: tshirt ? Colors.lightBlueAccent : Colors.white70),
                  onPressed: () => _toggleTshirt(r),
                ),
                IconButton(
                  iconSize: 18,
                  tooltip: liked ? 'Liked' : 'Like (saves the recipe)',
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.pinkAccent : Colors.white70),
                  onPressed: () => _toggleLike(r),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ViewMode { batch, liked, tshirts }

enum _LeftTab { generate, profile }

/// A small widget for adding a country code via autocomplete.
class _CountryAdder extends StatefulWidget {
  const _CountryAdder({
    required this.allCodes,
    required this.excluded,
    required this.onAdd,
  });
  final List<String> allCodes;
  final Set<String> excluded;
  final void Function(String) onAdd;

  @override
  State<_CountryAdder> createState() => _CountryAdderState();
}

class _CountryAdderState extends State<_CountryAdder> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: const InputDecoration(
        isDense: true,
        hintText: 'Add country code…',
        prefixIcon: Icon(Icons.add, size: 16),
      ),
      onSubmitted: (v) {
        final code = v.trim().toLowerCase();
        if (code.isNotEmpty && widget.allCodes.contains(code)) {
          widget.onAdd(code);
          _ctrl.clear();
        }
      },
    );
  }
}

/// A [DesignStore] backed by a local JSON file (the macOS Lab's disk). The
/// iPhone app plugs the same [PersistentDesignLibrary] into a documents-dir
/// store instead — the library core is identical.
class _FileDesignStore implements DesignStore {
  _FileDesignStore(this.file);
  final File file;

  @override
  Future<String?> read() async =>
      await file.exists() ? file.readAsString() : null;

  @override
  Future<void> write(String contents) async {
    await file.writeAsString(contents);
  }
}

/// A gallery tile that renders its recipe once (cached in [RenderService]).
class _RecipeTile extends StatefulWidget {
  const _RecipeTile({required this.service, required this.recipe, required this.size});
  final RenderService service;
  final DesignRecipe recipe;
  final int size;

  @override
  State<_RecipeTile> createState() => _RecipeTileState();
}

class _RecipeTileState extends State<_RecipeTile> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RecipeTile old) {
    super.didUpdateWidget(old);
    if (old.recipe.recipeId != widget.recipe.recipeId) _load();
  }

  Future<void> _load() async {
    final img = await widget.service.imageFor(widget.recipe, widget.size);
    if (mounted) setState(() => _image = img);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(
          child: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return RawImage(image: img, fit: BoxFit.contain);
  }
}
