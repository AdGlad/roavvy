import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../../shared/garment_mockup/garment_mockup_canvas.dart';
import '../../shared/garment_mockup/garment_mockup_spec.dart';
import '../host/studio_v2_trace.dart';
import '../host/studio_garments.dart';

/// The Studio hero, on an actual shirt: the live [DesignRecipe] rendered through
/// the shared [RenderService], composited onto a garment recoloured to the
/// design's own garment colour, with the fabric's folds falling across the ink.
///
/// **Preview, not an editor.** Where the design sits is owned by the Studio's
/// existing controls (Focus, artwork size, orientation) and its undo history —
/// this widget only shows the result faithfully. Freehand drag/pinch placement
/// lives one step later, on the order screen.
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
    this.longSide = 1024,
  });

  final RenderService service;
  final DesignRecipe recipe;

  /// Which face to show — picks the garment photo and the print area.
  final bool front;

  final int longSide;

  @override
  State<ShirtPreview> createState() => _ShirtPreviewState();
}

class _ShirtPreviewState extends State<ShirtPreview> {
  ui.Image? _artwork;
  ui.Image? _garment;
  String? _garmentKey;

  GarmentMockupSpec get _spec => StudioGarments.specFor(
    garmentColour: widget.recipe.palette?.garmentColour,
    front: widget.front,
  );

  @override
  void initState() {
    super.initState();
    _loadArtwork();
    _loadGarment();
  }

  @override
  void didUpdateWidget(covariant ShirtPreview old) {
    super.didUpdateWidget(old);
    // The artwork only re-renders when the design identity changes — a stage
    // change or a garment swap must not trigger an expensive re-render.
    if (old.recipe.recipeId != widget.recipe.recipeId ||
        old.longSide != widget.longSide) {
      _loadArtwork();
    }
    if (_spec.garmentKey != _garmentKey) _loadGarment();
  }

  Future<void> _loadArtwork() async {
    try {
      final img = await widget.service.imageFor(widget.recipe, widget.longSide);
      if (mounted) setState(() => _artwork = img);
    } catch (e) {
      // A transient render failure must never take the shell down; the next
      // recipe change retries.
      v2trace('ShirtPreview.artwork.ERROR $e');
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
    } catch (e) {
      v2trace('ShirtPreview.garment.ERROR $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final garment = _garment;
    final artwork = _artwork;
    if (artwork == null) {
      return const Center(
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
      // The recoloured garment carries its own folds, so it doubles as the
      // shading source — exactly as it does for the untinted photographs.
      shadingImage: garment,
      artworkImage: artwork,
      // Studio artwork is rendered on transparency, so it composites straight
      // over the fabric and the shading masks to its own alpha.
      artworkBlendMode: ui.BlendMode.srcOver,
      interactive: false,
      showHud: false,
    );
  }
}
