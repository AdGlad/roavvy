import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:flutter/material.dart';

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

  late DesignRecipe _current;
  final List<DesignRecipe> _history = [];
  final Set<DesignAxis> _locked = {};

  /// Preferences learned from this session's authoring, seeded from the host.
  late DesignPreferences _preferences;

  /// The axis whose alternatives the tray currently shows (null on open).
  DesignAxis? _activeAxis;
  List<DesignRecipe> _alternatives = const [];

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
    _current = _pickHero();
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
            label: const Text('Surprise me'),
            onPressed: _surprise,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _breadcrumb(),
          // Instant hero — the shirt is the star, always visible + centred.
          Expanded(
            child: Container(
              color: const Color(0xFF0E0F12),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: _HeroCanvas(
                key: const Key('studio-hero'),
                service: widget.service,
                recipe: _current,
              ),
            ),
          ),
          if (_activeAxis != null) _alternativesTray(),
          _decisionDeck(),
        ],
      ),
    );
  }

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
