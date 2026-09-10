import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;

import '../shared/garment_mockup/mockup_transform.dart';
import 'commerce/garment_cart_request.dart';
import 'host/studio_v2_trace.dart';
import 'studio_v2_stage.dart';
import 'studio_v2_theme.dart';
import 'widgets/detail_workspace.dart';
import 'widgets/direction_workspace.dart';
import 'widgets/fine_tune_panel.dart';
import 'widgets/focus_workspace.dart';
import 'widgets/front_workspace.dart';
import 'widgets/garment_preview.dart';
import 'widgets/instant_workspace.dart';
import 'widgets/placement_workspace.dart';
import 'widgets/saved_designs_sheet.dart';
import 'widgets/review_workspace.dart';
import 'widgets/shirt_preview.dart';
import 'widgets/studio_workspace_shell.dart';
import 'widgets/travels_workspace.dart';
import 'widgets/vibe_workspace.dart';
import 'widgets/words_workspace.dart';

/// Consumer-facing Studio V2 shell.
///
/// The shirt is the canvas; the current creative decision is secondary. Tier-1
/// controls remain one tap away without permanently occupying a toolbar, while
/// every workflow stage stays reachable through the compact Steps sheet.
class StudioV2Screen extends StatefulWidget {
  const StudioV2Screen({
    super.key,
    required this.controller,
    this.onAddToCart,
    this.priceLabel,
  });

  final StudioController controller;
  final AddToCartCallback? onAddToCart;

  /// The store's price for a tee, supplied by the host. The Studio may not
  /// import the merch feature, so pricing arrives the same way the cart does.
  final String? priceLabel;

  @override
  State<StudioV2Screen> createState() => StudioV2ScreenState();
}

class StudioV2ScreenState extends State<StudioV2Screen> {
  StudioController get _c => widget.controller;

  static const _stages = StudioStage.values;
  StudioStage _stage = StudioStage.instant;

  /// Hero view: the design on the shirt (default) or the flat artwork. A pure
  /// view preference — it never touches the recipe or the undo history.
  bool _onShirt = true;

  /// Where the print sits on each face. Owned here rather than in the
  /// workspace so an arrangement survives leaving the Placement step, and so
  /// the checkout hand-off can bake it into the print file.
  final _frontPlacement = MockupTransformController();
  final _backPlacement = MockupTransformController();

  MockupTransformController get _placement =>
      _c.onFront ? _frontPlacement : _backPlacement;

  /// True while a buy is in flight, so the action cannot be double-tapped.
  bool _busyBuying = false;
  final List<StudioStage> _navHistory = [];

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
    _frontPlacement.dispose();
    _backPlacement.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    v2bump('controller.notify', detail: 'recipeId=${_c.current.recipeId}');
    if (mounted) setState(() {});
  }

  /// Jump to a step. Public so tests can walk the flow the way a person does,
  /// rather than reaching into private state.
  @visibleForTesting
  void goToStage(StudioStage s) => _goToStage(s);

  /// Which side was being viewed before Front Design flipped it.
  ///
  /// The Studio edits whichever face is on screen, so a view left flipped is
  /// not cosmetic: after visiting Front Design, a title typed back on Words
  /// landed on the CHEST BADGE and the design kept its old words. Front Design
  /// borrows the view; it gives it back.
  bool? _sideBeforeFront;

  void _goToStage(StudioStage s) {
    if (s == _stage) return;
    // Front Design is about the front, so it opens showing it. This is VIEW
    // state — setSide touches no recipe and no history — and the Front/Back
    // toggle stays available for comparing the two sides.
    if (s == StudioStage.front && _stage != StudioStage.front) {
      _sideBeforeFront = _c.onFront;
      _c.setSide(true);
    } else if (_stage == StudioStage.front && s != StudioStage.front) {
      _c.setSide(_sideBeforeFront ?? false);
      _sideBeforeFront = null;
    }
    setState(() {
      _navHistory.add(_stage);
      _stage = s;
    });
  }

  /// The steps this design actually has. A step with nothing to offer is not
  /// a step: Detail asks the Direction whether it has choices, and each Fine
  /// Tune group asks whether any of its controls apply to this recipe.
  List<StudioStage> get _visibleStages {
    final groups = _c.fineTuneGroups();
    bool applies(StudioStage s) => switch (s) {
      StudioStage.detail => _c.detailApplies,
      StudioStage.layout => groups.contains(FineTuneGroup.layout),
      StudioStage.graphics => groups.contains(FineTuneGroup.graphics),
      StudioStage.colour => groups.contains(FineTuneGroup.colour),
      // Words is a step whenever the design CAN carry a title — the field is
      // how one gets added, so it does not wait for the group to fill.
      StudioStage.words => _c.wordsApply,
      _ => true,
    };
    return [
      for (final s in _stages)
        if (applies(s)) s,
    ];
  }

  void _next() {
    final vis = _visibleStages;
    final i = vis.indexOf(_stage);
    if (i >= 0) {
      if (i < vis.length - 1) _goToStage(vis[i + 1]);
      return;
    }
    // The current step is no longer applicable — a recipe Undo can restore a
    // design whose Graphics or Colour group has nothing in it while that very
    // step is on screen. Without this, Next simply stopped working. Move on to
    // the first applicable step that comes after this one.
    for (final s in vis) {
      if (s.index > _stage.index) {
        _goToStage(s);
        return;
      }
    }
  }

  void _workflowBack() {
    if (_navHistory.isEmpty) return;
    final to = _navHistory.removeLast();
    if (_stage == StudioStage.front && to != StudioStage.front) {
      _c.setSide(_sideBeforeFront ?? false);
      _sideBeforeFront = null;
    }
    setState(() => _stage = to);
  }

  @override
  Widget build(BuildContext context) {
    v2bump('StudioV2Screen.build', detail: 'stage=${_stage.name}');
    final canUndo = _c.history.isNotEmpty;
    // Instant is the front door, not step one of eleven. It owns the whole
    // viewport — no hero/controls/workspace/footer split, no undo button, no
    // step counter — because it is showing a finished product, and product
    // screens do not wear a wizard's chrome. Every later stage keeps the
    // frame below, and Customise is how you get there.
    if (_stage == StudioStage.instant) {
      return Scaffold(
        backgroundColor: StudioV2Theme.canvas,
        body: SafeArea(
          child: InstantWorkspace(
            controller: _c,
            onAddToCart: widget.onAddToCart,
            onOpenSaved: _showSavedDesigns,
            onExit:
                Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
            // One way forward, carrying this exact design into the first
            // Customise step. Travels edits the design rather than replacing
            // it, so the shirt they chose is the shirt they keep editing.
            onCustomise: () => _goToStage(StudioStage.travels),
          ),
        ),
      );
    }
    // Review is the end of the flow, not a step in it: the design is finished,
    // so the screen carries no editing chrome at all — no Next, no Undo, no
    // Fine Tune. Just the finished product and the ways to own it.
    if (_stage == StudioStage.review) {
      return Scaffold(
        backgroundColor: StudioV2Theme.canvas,
        body: SafeArea(
          child: Column(
            children: [
              _reviewHeader(),
              _stepHeading(
                '11',
                'Review & Buy',
                'Check your design, then add it to your cart.',
              ),
              Expanded(
                child: ReviewWorkspace(
                  controller: _c,
                  onAddToCart: widget.onAddToCart,
                  frontPlacement: _frontPlacement.value,
                  backPlacement: _backPlacement.value,
                  priceLabel: widget.priceLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Fine Tune keeps the shirt: every control here changes how the design
    // looks, and a dial you cannot see the effect of is not a dial. It uses
    // the shared editing frame, so the shirt can still take the screen.
    if (_stage == StudioStage.fineTune ||
        _stage == StudioStage.layout ||
        _stage == StudioStage.graphics ||
        _stage == StudioStage.colour ||
        _stage == StudioStage.words ||
        _stage == StudioStage.front) {
      return Scaffold(
        backgroundColor: StudioV2Theme.canvas,
        body: SafeArea(
          bottom: false,
          child: StudioWorkspaceShell(
            header: _customiseHeader(),
            preview: _customisePreview(),
            controls: Column(
              children: [
                switch (_stage) {
                  StudioStage.layout => _stepHeading(
                    '6',
                    'Layout & Composition',
                    'Arrange the elements to get the perfect look.',
                  ),
                  StudioStage.graphics => _stepHeading(
                    '7',
                    'Graphics',
                    'Adjust the graphic style and appearance.',
                  ),
                  StudioStage.colour => _stepHeading(
                    '8',
                    'Colour, Effects & Print',
                    'Adjust the colours, effects and print style.',
                  ),
                  StudioStage.words => _stepHeading(
                    '9',
                    'Words & Title',
                    'Add a title or text to complete your design.',
                  ),
                  StudioStage.front => _stepHeading(
                    '10',
                    'Front Design',
                    'Add an optional design to the front of your shirt.',
                  ),
                  _ => _stepHeading(
                    '5',
                    'Fine Tune',
                    'Adjust the details to make it your own.',
                  ),
                },
                Expanded(
                  child: switch (_stage) {
                    StudioStage.words => WordsWorkspace(controller: _c),
                    StudioStage.front => FrontWorkspace(controller: _c),
                    _ => FineTunePanel(
                      controller: _c,
                      only: switch (_stage) {
                        StudioStage.layout => FineTuneGroup.layout,
                        StudioStage.graphics => FineTuneGroup.graphics,
                        StudioStage.colour => FineTuneGroup.colour,
                        _ => null,
                      },
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Travels is the first Customise step, and the first to use the shared
    // editing frame: a compact garment above a sheet of controls, draggable to
    // give the shirt the screen and back again. M13–M21 adopt it by passing
    // their own controls in.
    if (_stage == StudioStage.travels) {
      return Scaffold(
        backgroundColor: StudioV2Theme.canvas,
        body: SafeArea(
          bottom: false,
          child: StudioWorkspaceShell(
            header: _customiseHeader(),
            preview: _customisePreview(),
            controls: TravelsWorkspace(controller: _c),
          ),
        ),
      );
    }
    // Direction and its Detail have no garment. Both redraw the artwork
    // wholesale, so a preview would spend the screen showing the design about
    // to be replaced — the cards themselves are the preview. Same header as
    // Travels, no sheet.
    if (_stage == StudioStage.direction ||
        _stage == StudioStage.detail ||
        _stage == StudioStage.vibe) {
      return Scaffold(
        backgroundColor: StudioV2Theme.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _customiseHeader(),
              const SizedBox(height: 6),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: StudioV2Theme.card,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    children: [
                      // The same grab affordance the sheet steps show, so the
                      // flow reads as one surface even where nothing drags.
                      const SizedBox(
                        height: 30,
                        child: Center(
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 26,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      Expanded(
                        child: switch (_stage) {
                          StudioStage.direction => DirectionWorkspace(
                            controller: _c,
                          ),
                          StudioStage.detail => DetailWorkspace(controller: _c),
                          _ => VibeWorkspace(controller: _c),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0E0F12),
        foregroundColor: Colors.white,
        leading: IconButton(
          key: const Key('v2-workflow-back'),
          tooltip: 'Back a step',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: canWorkflowBack ? _workflowBack : null,
        ),
        title: const Text(
          'Design your travel tee',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('v2-recipe-undo'),
            tooltip: canUndo ? 'Undo design change' : 'Nothing to undo',
            icon: const Icon(Icons.undo_rounded),
            onPressed: canUndo ? _c.undo : null,
          ),
          IconButton(
            key: const Key('v2-saved-designs'),
            tooltip: 'Your saved designs',
            icon: const Icon(Icons.bookmark_border_rounded),
            onPressed: _showSavedDesigns,
          ),
          IconButton(
            key: const Key('v2-open-steps'),
            tooltip: 'All design steps',
            icon: const Icon(Icons.more_horiz),
            onPressed: _showStages,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(flex: 6, child: _hero()),
            _quickControls(),
            Expanded(flex: 4, child: _workspace()),
            _progressFooter(),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
    width: double.infinity,
    color: const Color(0xFF0E0F12),
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
    child: Column(
      children: [
        Expanded(
          child: Center(
            // The hero shows the design ON the shirt by default — the
            // garment colour you chose, with its folds falling across the
            // ink — so every Direction / Vibe / Colour decision is judged
            // against the real thing. The flat artwork stays one tap away
            // for judging the design on its own.
            child:
                _onShirt
                    ? ShirtPreview(
                      key: const Key('v2-garment-preview'),
                      service: _c.service,
                      recipe: _c.current,
                      front: _c.onFront,
                      // The front print moves — left chest by default — and the
                      // shirt has to show it where it will actually be.
                      printArea: _c.onFront ? _c.frontPrintRect() : null,
                      // The hero becomes the placement surface at that step —
                      // and only there, so a stray drag cannot rearrange a
                      // print while someone is choosing a vibe.
                      interactive: _stage == StudioStage.placement,
                      transformController: _placement,
                    )
                    : GarmentPreview(
                      key: const Key('v2-garment-preview'),
                      service: _c.service,
                      recipe: _c.current,
                    ),
          ),
        ),
        const SizedBox(height: 4),
        // Four pills side by side overflow a phone by ~115px. Scroll rather
        // than clip: on a wide window they stay centred, on a narrow one they
        // remain reachable instead of hiding behind a striped bar.
        LayoutBuilder(
          builder:
              (context, c) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _sideSelector(),
                      const SizedBox(width: 8),
                      _viewToggle(),
                    ],
                  ),
                ),
              ),
        ),
      ],
    ),
  );

  /// Shirt ⇄ flat artwork. Purely a view of the same design — it touches no
  /// recipe state, so it never enters the undo history.
  Widget _viewToggle() => Container(
    height: 38,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1C21),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sidePill(
          'view-shirt',
          'Shirt',
          _onShirt,
          () => setState(() => _onShirt = true),
        ),
        _sidePill(
          'view-artwork',
          'Artwork',
          !_onShirt,
          () => setState(() => _onShirt = false),
        ),
      ],
    ),
  );

  Widget _sideSelector() => Container(
    height: 38,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1C21),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sidePill('side-front', 'Front', _c.onFront, () => _c.setSide(true)),
        _sidePill('side-back', 'Back', !_c.onFront, () => _c.setSide(false)),
      ],
    ),
  );

  Widget _sidePill(
    String id,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => GestureDetector(
    key: Key('v2-$id'),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.black : Colors.white60,
        ),
      ),
    ),
  );

  /// Persistent reachability without a permanently expanded settings toolbar.
  Widget _quickControls() {
    final comp = _c.current.composition;
    final garment = _c.current.palette?.garmentColour ?? '#0E0E0E';
    // Same treatment as the hero controls: these must stay reachable on a
    // narrow phone rather than disappear behind an overflow bar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: LayoutBuilder(
        builder:
            (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _quickButton(
                      key: const Key('v2-shirt-colour-menu'),
                      icon: Icons.checkroom_outlined,
                      label: 'Shirt',
                      leading: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _hexColour(garment),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                      ),
                      onTap: _showGarmentColours,
                    ),
                    const SizedBox(width: 8),
                    _quickButton(
                      key: const Key('v2-aspect-menu'),
                      icon: Icons.crop_portrait_rounded,
                      label: _orientationLabel(comp.orientation),
                      onTap: _showOrientations,
                    ),
                    const SizedBox(width: 8),
                    _quickButton(
                      key: const Key('v2-size-menu'),
                      icon: Icons.aspect_ratio_rounded,
                      label: 'Art ${_sizeLabel(comp.sizeClass)}',
                      onTap: _showSizes,
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _quickButton({
    Key? key,
    required IconData icon,
    required String label,
    Widget? leading,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    key: key,
    onPressed: onTap,
    icon: leading ?? Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 11)),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white70,
      side: const BorderSide(color: Color(0xFF35383F)),
      backgroundColor: const Color(0xFF17191E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      minimumSize: const Size(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  /// The numbered step heading the Customise screens share.
  /// The Review header: a way back, the wordmark, and the one action this
  /// screen exists for. No Next — there is nowhere further to go.
  Widget _reviewHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
    child: Row(
      children: [
        IconButton(
          key: const Key('v2-review-workflow-back'),
          tooltip: 'Back',
          onPressed: _workflowBack,
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: Colors.white70,
        ),
        const Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'roavvy',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Icon(Icons.place, size: 17, color: StudioV2Theme.accent),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('v2-saved-designs'),
          tooltip: 'Your saved designs',
          onPressed: _showSavedDesigns,
          icon: const Icon(Icons.inventory_2_outlined, size: 20),
          color: Colors.white70,
        ),
      ],
    ),
  );

  Widget _stepHeading(String number, String title, String helper) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: StudioV2Theme.accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Customise navigation: out of the step, the wordmark, and on to the next.
  /// Deliberately not the wizard app bar — no undo, no step counter, no menu.
  Widget _customiseHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
    child: Row(
      children: [
        IconButton(
          key: const Key('v2-customise-back'),
          tooltip: 'Back',
          onPressed: _workflowBack,
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: Colors.white70,
        ),
        const Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'roavvy',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Icon(Icons.place, size: 17, color: StudioV2Theme.accent),
              ],
            ),
          ),
        ),
        // Your wardrobe, from the steps that make it — a design you saved is
        // not something to walk to the end of the flow to look at.
        IconButton(
          key: const Key('v2-saved-designs'),
          tooltip: 'Your saved designs',
          onPressed: _showSavedDesigns,
          icon: const Icon(Icons.inventory_2_outlined, size: 20),
          color: Colors.white70,
        ),
        FilledButton(
          key: const Key('v2-customise-next'),
          onPressed: _next,
          style: FilledButton.styleFrom(
            backgroundColor: StudioV2Theme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Next'),
        ),
      ],
    ),
  );

  /// The design being edited, with the face switch beside it. Built once and
  /// kept alive across sheet drags — sliding the sheet must reveal more of
  /// this shirt, never re-render it.
  Widget _customisePreview() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: ShirtPreview(
          key: const Key('v2-garment-preview'),
          service: _c.service,
          recipe: _c.current,
          front: _c.onFront,
          printArea: _c.onFront ? _c.frontPrintRect() : null,
        ),
      ),
      Padding(padding: const EdgeInsets.only(right: 8), child: _sideSelector()),
    ],
  );

  Widget _workspace() => Container(
    key: const Key('v2-workspace'),
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Color(0xFF121317),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
    child: switch (_stage) {
      // Instant and the Customise choice steps are handled above — each owns
      // its whole screen rather than sitting in this frame — but the switch
      // must stay exhaustive.
      StudioStage.instant => const SizedBox.shrink(),
      StudioStage.direction => const SizedBox.shrink(),
      StudioStage.detail => const SizedBox.shrink(),
      StudioStage.travels => TravelsWorkspace(controller: _c),
      StudioStage.vibe => const SizedBox.shrink(),
      StudioStage.focus => FocusWorkspace(controller: _c),
      StudioStage.words => const SizedBox.shrink(),
      StudioStage.front => const SizedBox.shrink(),
      StudioStage.fineTune => const SizedBox.shrink(),
      StudioStage.colour => const SizedBox.shrink(),
      StudioStage.layout => const SizedBox.shrink(),
      StudioStage.graphics => const SizedBox.shrink(),
      StudioStage.placement => PlacementWorkspace(
        controller: _c,
        placement: _placement,
      ),
      StudioStage.review => const SizedBox.shrink(),
    },
  );

  /// Buy what is on the shirt right now, from any step.
  ///
  /// Goes through the same `buildGarmentCartRequest` the Review step uses — a
  /// second hand-rolled payload is how a quick path starts ordering something
  /// the careful path would not. A colour the store cannot make says so here
  /// rather than failing at the till.
  Widget _buyButton() {
    final orderable = _c.canOrderCurrent;
    return OutlinedButton.icon(
      key: const Key('v2-buy-now'),
      onPressed: _busyBuying ? null : (orderable ? _buyNow : _explainUnbuyable),
      icon:
          _busyBuying
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(
                orderable
                    ? Icons.shopping_bag_outlined
                    : Icons.info_outline_rounded,
                size: 17,
              ),
      label: const Text('Buy'),
      style: OutlinedButton.styleFrom(
        foregroundColor: orderable ? Colors.white : Colors.white38,
        side: BorderSide(
          color: orderable ? StudioV2Theme.border : StudioV2Theme.subtleBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _explainUnbuyable() {
    final name = _c.garmentLabelFor(_c.current.palette?.garmentColour);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${name ?? 'That shirt colour'} is not available to order yet — '
          'pick another colour to buy this design.',
        ),
      ),
    );
  }

  Future<void> _buyNow() async {
    final cb = widget.onAddToCart;
    if (cb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is not available in this build')),
      );
      return;
    }
    setState(() => _busyBuying = true);
    try {
      await cb(
        context,
        buildGarmentCartRequest(
          _c,
          frontPlacement: _frontPlacement.value,
          backPlacement: _backPlacement.value,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyBuying = false);
    }
  }

  Widget _progressFooter() {
    final vis = _visibleStages;
    final index = vis.indexOf(_stage).clamp(0, vis.length - 1);
    final last = index == vis.length - 1;
    return Container(
      color: const Color(0xFF121317),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: LayoutBuilder(
        builder:
            (context, c) => Row(
              children: [
                // On a narrow phone the two actions and the step count cannot all
                // fit. The count goes: it is a label, they are the reason anyone
                // looks down here, and the step sheet still names where you are.
                if (c.maxWidth >= 300) ...[
                  Flexible(
                    child: InkWell(
                      onTap: _showStages,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 2,
                        ),
                        // The progress bar went when the footer gained a second
                        // action: the count says the same thing in far less width.
                        child: Text(
                          'Step ${index + 1} of ${vis.length}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else
                  const Spacer(),
                // Rule 3: buying is reachable from everywhere, not gated behind
                // the end of the flow. Someone who is happy at step two should not
                // have to walk to step eleven to pay.
                _buyButton(),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('v2-next'),
                  onPressed: last ? null : _next,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  iconAlignment: IconAlignment.end,
                  label: Text(last ? 'Done' : 'Continue'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  void _showStages() {
    final vis = _visibleStages;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1C21),
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              itemCount: vis.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (_, i) {
                final s = vis[i];
                final selected = s == _stage;
                return ListTile(
                  key: Key('v2-stage-${s.name}'),
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        selected ? Colors.tealAccent : Colors.white10,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.black : Colors.white70,
                      ),
                    ),
                  ),
                  title: Text(
                    s.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  trailing:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            color: Colors.tealAccent,
                          )
                          : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToStage(s);
                  },
                );
              },
            ),
          ),
    );
  }

  /// Your wardrobe, reachable from every step — like buying, it is not
  /// something to walk to the end of the flow for.
  void _showSavedDesigns() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1C21),
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => SavedDesignsSheet(
          controller: _c,
          onAddToCart: widget.onAddToCart,
          // Saving happened at Review, so that is where carrying on resumes.
          onOpen: (_) => _goToStage(StudioStage.review),
        ),
  );

  void _showGarmentColours() => _showChoiceSheet(
    title: 'Shirt colour',
    children: [
      for (final (hex, name) in StudioController.garments)
        ListTile(
          key: Key('v2-garment-$name'),
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hexColour(hex),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
          title: Text(name),
          // Shown, but never silently sellable: a colour the store cannot
          // fulfil says so here, at the moment of choosing, rather than
          // being refused later at the till.
          subtitle:
              _c.canOrderGarment(name)
                  ? null
                  : const Text(
                    'Not available to order yet',
                    style: TextStyle(fontSize: 11),
                  ),
          trailing:
              _c.current.palette?.garmentColour == hex
                  ? const Icon(Icons.check_rounded, color: Colors.tealAccent)
                  : null,
          onTap: () {
            Navigator.pop(context);
            _c.setGarment(hex);
          },
        ),
    ],
  );

  void _showOrientations() => _showChoiceSheet(
    title: 'Artwork shape',
    children: [
      for (final (o, label, icon) in const [
        (Orientation.portrait, 'Portrait', Icons.crop_portrait_rounded),
        (Orientation.landscape, 'Landscape', Icons.crop_landscape_rounded),
        (Orientation.square, 'Square', Icons.crop_square_rounded),
      ])
        ListTile(
          key: Key('v2-aspect-${o.name}'),
          leading: Icon(icon),
          title: Text(label),
          trailing:
              _c.current.composition.orientation == o
                  ? const Icon(Icons.check_rounded, color: Colors.tealAccent)
                  : null,
          onTap: () {
            Navigator.pop(context);
            _c.setOrientation(o);
          },
        ),
    ],
  );

  void _showSizes() => _showChoiceSheet(
    title: 'Artwork size',
    subtitle: 'This changes the print size, not the physical T-shirt size.',
    children: [
      for (final (s, label) in const [
        (SizeClass.small, 'Small'),
        (SizeClass.medium, 'Medium'),
        (SizeClass.large, 'Large'),
      ])
        ListTile(
          key: Key('v2-size-${s.name}'),
          title: Text(label),
          trailing:
              _c.current.composition.sizeClass == s
                  ? const Icon(Icons.check_rounded, color: Colors.tealAccent)
                  : null,
          onTap: () {
            Navigator.pop(context);
            _c.setSize(s);
          },
        ),
    ],
  );

  void _showChoiceSheet({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1C21),
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
    );
  }

  static Color _hexColour(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  static String _orientationLabel(Orientation o) => switch (o) {
    Orientation.portrait => 'Portrait',
    Orientation.landscape => 'Landscape',
    Orientation.square => 'Square',
  };

  static String _sizeLabel(SizeClass s) => switch (s) {
    SizeClass.small => 'S',
    SizeClass.medium => 'M',
    SizeClass.large => 'L',
  };
}
