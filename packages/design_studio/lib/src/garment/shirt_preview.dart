import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import '../render_service.dart';
import 'package:flutter/material.dart';

import 'fabric_print.dart';
import 'garment_mockup_canvas.dart';
import 'garment_mockup_spec.dart';
import 'mockup_transform.dart';
import 'studio_garments.dart';

/// The Studio hero, on an actual shirt: the live [DesignRecipe] rendered through
/// the shared [RenderService], composited onto a garment recoloured to the
/// design's own garment colour, with the fabric's folds falling across the ink.
///
/// **Preview by default, editor on request.** What the design *is* stays owned
/// by the Studio's controls (Focus, artwork size, orientation) and its undo
/// history. Where it SITS on the garment is the Placement step's business:
/// pass a [transformController] and set [interactive], and this same hero
/// becomes the drag/pinch/twist surface — the arrangement happens on the shirt
/// the traveller has been looking at all along, not on a screen the flow
/// escapes into.
///
/// Every Studio garment colour renders exactly, including the three the
/// photography doesn't cover, because [StudioGarments] tints a neutral shirt
/// rather than mapping onto a near-miss photo (see `GarmentTint`).
class ShirtPreview extends StatefulWidget {
  const ShirtPreview({
    super.key,
    required this.service,
    required this.recipe,
    required this.front,
    this.printArea,
    this.longSide = 1024,
    this.placeholder,
    this.interactive = false,
    this.transformController,
    this.garmentColour,
  });

  /// The shirt colour (`#RRGGBB`) to show, when it is not the recipe's own.
  ///
  /// For a design whose recipe must not change with the shirt — a Signature
  /// hero whose `recipeId` is locked (M200). Null uses
  /// `recipe.palette.garmentColour`, as the Studio does.
  final String? garmentColour;

  final RenderService service;
  final DesignRecipe recipe;

  /// Which face to show — picks the garment photo and the print area.
  final bool front;

  /// Where the artwork prints on this face, as fractions of the garment photo.
  /// [Rect.zero] is a blank face (a garment with no print); null takes the
  /// face's default region.
  final Rect? printArea;

  final int longSide;

  /// Whether the artwork can be dragged, pinched and twisted on the garment.
  final bool interactive;

  /// Owns the placement when [interactive]. Held by the host so the arrangement
  /// outlives a stage change and reaches the print file.
  final MockupTransformController? transformController;

  /// Shown until the design has rendered. Defaults to a spinner, which suits
  /// the hero; a deck of eight thumbnails passes something quieter, because
  /// eight spinners is worse than none.
  final Widget? placeholder;

  @override
  State<ShirtPreview> createState() => _ShirtPreviewState();
}

class _ShirtPreviewState extends State<ShirtPreview> {
  ui.Image? _artwork;
  ui.Image? _garment;
  ui.Image? _shading;

  /// [_artwork] printed into the fabric ([FabricPrint]); null until baked, or
  /// when the design can be moved (the bake assumes the default placement).
  ui.Image? _printed;
  String? _printedKey;

  /// Identifies the design [_artwork] was rendered from (it can lag the
  /// widget's recipe while a new one renders).
  String? _artworkKey;
  String? _garmentKey;
  String? _shadingKey;

  /// True when this face carries no print at all (Front → Blank).
  bool get _blank => widget.printArea == Rect.zero;

  GarmentMockupSpec get _spec => StudioGarments.specFor(
    garmentColour: widget.garmentColour ?? widget.recipe.palette?.garmentColour,
    front: widget.front,
    printArea: _blank ? null : widget.printArea,
  );

  @override
  void initState() {
    super.initState();
    _loadArtwork();
    _loadGarment();
    _loadShading();
  }

  @override
  void didUpdateWidget(covariant ShirtPreview old) {
    super.didUpdateWidget(old);
    // The artwork only re-renders when the design identity changes — a stage
    // change or a garment swap must not trigger an expensive re-render.
    if (old.recipe.recipeId != widget.recipe.recipeId ||
        old.longSide != widget.longSide ||
        _artworkBackground(old) != _artworkBackground(widget)) {
      _loadArtwork();
    }
    if (_spec.garmentKey != _garmentKey) _loadGarment();
    if (_spec.shadingAssetPath != _shadingKey) _loadShading();
    // A new print area (or a still preview that was editable) needs its own
    // bake; an unchanged key returns at once.
    _bakePrint();
  }

  /// The tone the artwork is drawn against, when [ShirtPreview.garmentColour]
  /// overrides the recipe's and the design carries an outline that picks its
  /// colour from the shirt. Otherwise null (the recipe decides), so a colour
  /// change costs no re-render.
  ///
  /// Also for a design whose ink is chosen against the shirt ([inkFollowsShirt]:
  /// Passport Stamp's black/white ink, I ♥ Country's captions) — without the
  /// shirt it renders as if on a light one, black on every colour.
  static ui.Color? _artworkBackground(ShirtPreview w) {
    final hex = w.garmentColour ?? w.recipe.palette?.garmentColour;
    if (hex == null) return null;
    if (w.recipe.composition.outlineWidth <= 0 && !inkFollowsShirt(w.recipe)) {
      return null;
    }
    return StudioGarments.parseHex(hex);
  }

  Future<void> _loadArtwork() async {
    final key =
        '${widget.recipe.recipeId}@${widget.longSide}|'
        '${_artworkBackground(widget)}';
    try {
      // The artwork LAYER, with nothing behind it: anything opaque would show
      // as a card around the design instead of printing onto the fabric.
      final img = await widget.service.imageFor(
        widget.recipe,
        widget.longSide,
        transparent: true,
        background: _artworkBackground(widget),
      );
      if (mounted) {
        setState(() {
          _artwork = img;
          _artworkKey = key;
        });
        _bakePrint();
      }
    } catch (_) {
      // A transient render failure must never take the shell down; the next
      // recipe change retries.
    }
  }

  Future<void> _loadGarment() async {
    final spec = _spec;
    final key = spec.garmentKey;
    _garmentKey = key;
    try {
      final img = await StudioGarments.load(spec);
      // A slower earlier load must not overwrite a newer garment.
      if (mounted && _garmentKey == key) setState(() => _garment = img);
    } catch (_) {}
  }

  Future<void> _loadShading() async {
    final spec = _spec;
    final key = spec.shadingAssetPath;
    _shadingKey = key;
    try {
      final img = await StudioGarments.loadShading(spec);
      if (mounted && _shadingKey == key) {
        setState(() => _shading = img);
        _bakePrint();
      }
    } catch (_) {
      // Losing the folds costs realism, never the preview: the shirt and the
      // print still render, just flat.
    }
  }

  /// Whether the print can be baked into the fabric: a still preview at the
  /// default placement. An editable one keeps the live shading pass, which
  /// follows the design as it moves.
  bool get _bakes => !widget.interactive && widget.transformController == null;

  /// The artwork that was rendered, on this shading map and print area.
  String get _bakeKey =>
      '$_artworkKey|${_spec.shadingAssetPath}|${_spec.printAreaNorm}';

  Future<void> _bakePrint() async {
    final artwork = _artwork, shading = _shading;
    if (!_bakes || _blank || artwork == null || shading == null) return;
    if (_artworkKey == null) return;
    final key = _bakeKey;
    if (key == _printedKey && _printed != null) return;
    _printedKey = key;
    try {
      final img = await FabricPrint.bake(
        artwork: artwork,
        shading: shading,
        spec: _spec,
        cacheKey: _artworkKey!,
      );
      // A slower earlier bake must not overwrite a newer design.
      if (mounted && _printedKey == key && identical(_artwork, artwork)) {
        setState(() => _printed = img);
      }
    } catch (_) {
      // Realism, not correctness: the live shading pass still renders.
    }
  }

  @override
  Widget build(BuildContext context) {
    final garment = _garment;
    final artwork = _blank ? null : _artwork;
    // Only the bake of THIS design and print area; a stale one is ignored.
    final printed =
        _bakes && _printedKey == _bakeKey && !_blank ? _printed : null;
    if (garment != null && _blank) {
      // A blank front is a real choice, not a missing render.
      return GarmentMockupCanvas(
        spec: _spec,
        garmentImage: garment,
        shadingImage: garment,
        interactive: false,
        showHud: false,
      );
    }
    if (artwork == null) {
      return widget.placeholder ??
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }
    if (garment == null) {
      // The garment layer is recoloured on first use of a colour. Never hold
      // the hero hostage to it: show the design flat the moment it is ready and
      // let the shirt appear underneath when it arrives. This keeps first paint
      // as fast as it was before the shirt existed.
      return RawImage(image: artwork, fit: BoxFit.contain);
    }
    return GarmentMockupCanvas(
      spec: _spec,
      garmentImage: garment,
      // The NEUTRAL photograph, never the recoloured garment. The shading pass
      // multiplies this over the ink to bed the print into the fabric, so it
      // must supply folds — a luminance — and nothing else. Passing the tinted
      // shirt here is what put a red wash over the flags and swallowed the
      // lettering on a red tee.
      //
      // When the print has been baked into the fabric ([FabricPrint]) the
      // folds, light and weave are already in the ink, so the pass is skipped.
      shadingImage: printed != null ? null : _shading,
      artworkImage: printed ?? artwork,
      // The design prints as it was designed. It is rendered with no
      // background fill, so what reaches the fabric is the artwork alone and
      // the shirt shows through everywhere it is transparent.
      //
      // NOT multiply. Multiplying tints every colour by the garment — on a red
      // shirt France's blue turns purple and Japan's white turns pink — which
      // is neither what the design says nor what the printer produces, since
      // DTG lays a white underbase on coloured cloth.
      artworkBlendMode: ui.BlendMode.srcOver,
      controller: widget.transformController,
      interactive: widget.interactive,
      showHud: widget.interactive,
    );
  }
}

/// Whether [recipe]'s ink is chosen against the shirt it prints on: a
/// garment-aware design with adaptive ink (Passport Stamp in black ink — white
/// on dark cloth, black on light) or one with captions (kept in their colour
/// only while it contrasts with the shirt). Such a design must be rendered
/// knowing the shirt colour, on screen and in the print file.
bool inkFollowsShirt(DesignRecipe recipe) =>
    (recipe.palette?.strategy == ColourStrategy.garmentAware &&
        recipe.inkIsAdaptive) ||
    recipe.captions != null;
