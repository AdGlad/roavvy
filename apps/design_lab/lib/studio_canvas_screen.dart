import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:flutter/material.dart';

import 'lab_generator.dart';
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

  /// The axis whose alternatives the tray currently shows (null on open).
  DesignAxis? _activeAxis;
  List<DesignRecipe> _alternatives = const [];

  /// Monotonic source of fresh per-axis seeds so each tap yields a new look.
  int _seedBump = 1000;
  int _nextSeed() => _seedBump++;

  // ── Test-facing read-only accessors ──
  DesignRecipe get currentRecipe => _current;
  Set<DesignAxis> get lockedAxes => Set.unmodifiable(_locked);
  int get historyLength => _history.length;
  List<DesignRecipe> get alternatives => List.unmodifiable(_alternatives);
  DesignAxis? get activeAxis => _activeAxis;

  @override
  void initState() {
    super.initState();
    // Instant hero: one design from the default context, rendered large.
    _current = widget.generator
        .generate(widget.designContext, seed: widget.initialSeed, count: 1)
        .first;
  }

  /// Commit [next] as the new hero, pushing the outgoing hero onto the undo
  /// stack. No-op (no history entry) if the recipe is unchanged.
  void _commit(DesignRecipe next) {
    if (next.recipeId == _current.recipeId) return;
    setState(() {
      _history.add(_current);
      _current = next;
    });
  }

  /// Deck tap: re-roll just [axis] with a fresh seed, focus its tray.
  void _rerollAxis(DesignAxis axis) {
    final next = widget.generator.reroll(_current, axis, newSeed: _nextSeed());
    _commit(next);
    _focusAxis(axis);
  }

  /// Rebuild the alternatives tray for [axis] (a strip of 4 re-rolls of the
  /// current hero on that axis, each a non-destructive candidate).
  void _focusAxis(DesignAxis axis) {
    setState(() {
      _activeAxis = axis;
      _alternatives = [
        for (var i = 0; i < 4; i++)
          widget.generator.reroll(_current, axis, newSeed: _nextSeed()),
      ];
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
    final next = widget.generator.rerollUnlocked(_current, locked: _locked);
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
        _alternatives = [
          for (var i = 0; i < 4; i++)
            widget.generator.reroll(_current, _activeAxis!, newSeed: _nextSeed()),
        ];
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
                return GestureDetector(
                  key: Key('studio-alt-$i'),
                  onTap: () => _commit(alt),
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
              label: label,
              icon: icon,
              locked: _locked.contains(axis),
              active: _activeAxis == axis,
              onTap: () => _rerollAxis(axis),
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
