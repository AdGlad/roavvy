import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;

import '../shared/garment_mockup/mockup_transform.dart';
import 'commerce/garment_cart_request.dart';
import 'host/studio_v2_trace.dart';
import 'studio_v2_stage.dart';
import 'studio_v2_theme.dart';
import 'widgets/colour_workspace.dart';
import 'widgets/detail_workspace.dart';
import 'widgets/direction_workspace.dart';
import 'widgets/fine_tune_workspace.dart';
import 'widgets/focus_workspace.dart';
import 'widgets/front_workspace.dart';
import 'widgets/garment_preview.dart';
import 'widgets/instant_workspace.dart';
import 'widgets/placement_workspace.dart';
import 'widgets/saved_designs_sheet.dart';
import 'widgets/review_workspace.dart';
import 'widgets/shirt_preview.dart';
import 'widgets/travels_workspace.dart';
import 'widgets/vibe_workspace.dart';
import 'widgets/words_workspace.dart';

/// Consumer-facing Studio V2 shell.
///
/// The shirt is the canvas; the current creative decision is secondary. Tier-1
/// controls remain one tap away without permanently occupying a toolbar, while
/// every workflow stage stays reachable through the compact Steps sheet.
class StudioV2Screen extends StatefulWidget {
  const StudioV2Screen({super.key, required this.controller, this.onAddToCart});

  final StudioController controller;
  final AddToCartCallback? onAddToCart;

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

  void _goToStage(StudioStage s) {
    if (s == _stage) return;
    setState(() {
      _navHistory.add(_stage);
      _stage = s;
    });
  }

  List<StudioStage> get _visibleStages => [
    for (final s in _stages)
      if (s != StudioStage.detail || _c.detailApplies) s,
  ];

  void _next() {
    final vis = _visibleStages;
    final i = vis.indexOf(_stage);
    if (i >= 0 && i < vis.length - 1) _goToStage(vis[i + 1]);
  }

  void _workflowBack() {
    if (_navHistory.isEmpty) return;
    setState(() => _stage = _navHistory.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    v2bump('StudioV2Screen.build', detail: 'stage=${_stage.name}');
    final canUndo = _c.history.isNotEmpty;
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

  Widget _workspace() => Container(
    key: const Key('v2-workspace'),
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Color(0xFF121317),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
    child: switch (_stage) {
      StudioStage.instant => InstantWorkspace(
        controller: _c,
        onAddToCart: widget.onAddToCart,
        // Configure keeps the pick and opens the steps that restyle it;
        // Custom drops it and starts the flow at Direction.
        onConfigure: () => _goToStage(StudioStage.vibe),
        onCustom: () => _goToStage(StudioStage.direction),
      ),
      StudioStage.travels => TravelsWorkspace(controller: _c),
      StudioStage.direction => DirectionWorkspace(controller: _c),
      StudioStage.detail =>
        _c.detailApplies
            ? DetailWorkspace(controller: _c)
            : _detailNotApplicable(),
      StudioStage.vibe => VibeWorkspace(controller: _c),
      StudioStage.focus => FocusWorkspace(controller: _c),
      StudioStage.colour => ColourWorkspace(controller: _c),
      StudioStage.words => WordsWorkspace(controller: _c),
      StudioStage.front => FrontWorkspace(controller: _c),
      StudioStage.fineTune => FineTuneWorkspace(controller: _c),
      StudioStage.placement => PlacementWorkspace(
        controller: _c,
        placement: _placement,
      ),
      StudioStage.review => ReviewWorkspace(
        frontPlacement: _frontPlacement.value,
        backPlacement: _backPlacement.value,
        controller: _c,
        onAddToCart: widget.onAddToCart,
      ),
    },
  );

  Widget _detailNotApplicable() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Detail',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 6),
      Text(
        'Shape choices are available for Flags designs.',
        style: TextStyle(fontSize: 13, color: Colors.white60),
      ),
    ],
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
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: _showStages,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                // The progress bar went when the footer gained a second
                // action: on a phone the count says the same thing in far
                // less width, and the two buttons matter more than a meter.
                child: Text(
                  'Step ${index + 1} of ${vis.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Rule 3: buying is reachable from everywhere, not gated behind the
          // end of the flow. Someone who is happy at step two should not have
          // to walk to step eleven to pay.
          _buyButton(),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('v2-next'),
            onPressed: last ? null : _next,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            iconAlignment: IconAlignment.end,
            label: Text(last ? 'Done' : 'Continue'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
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
