import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../host/studio_v2_trace.dart';

/// The live t-shirt preview — the visual **hero** of the V2 shell. Renders a real
/// [DesignRecipe] through the shared [RenderService] (design_forge_render), with
/// an image cache keyed by `recipeId@size`.
///
/// Performance: it only re-fetches when the recipe **identity** changes
/// ([DesignRecipe.recipeId]). A pure workflow-stage change does not touch the
/// recipe, so the shirt image is reused (no re-render) — and even a rebuild hits
/// the [RenderService] cache. Colour / orientation / size / front-back edits do
/// change the recipe id, so the preview updates immediately.
class GarmentPreview extends StatefulWidget {
  const GarmentPreview({
    super.key,
    required this.service,
    required this.recipe,
    this.longSide = 1024,
  });

  final RenderService service;
  final DesignRecipe recipe;
  final int longSide;

  @override
  State<GarmentPreview> createState() => _GarmentPreviewState();
}

class _GarmentPreviewState extends State<GarmentPreview> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GarmentPreview old) {
    super.didUpdateWidget(old);
    // Only re-render when the design actually changed (not on stage navigation).
    if (old.recipe.recipeId != widget.recipe.recipeId ||
        old.longSide != widget.longSide) {
      _load();
    }
  }

  Future<void> _load() async {
    final sw = Stopwatch()..start();
    v2bump('GarmentPreview.load.start',
        detail: 'longSide=${widget.longSide} recipeId=${widget.recipe.recipeId}');
    try {
      final img = await widget.service.imageFor(widget.recipe, widget.longSide);
      v2trace('GarmentPreview.load.done longSide=${widget.longSide} '
          'in ${sw.elapsedMilliseconds}ms');
      if (mounted) setState(() => _image = img);
    } catch (e) {
      // A transient render/asset failure must never crash the shell; keep the
      // spinner and let a later recipe change retry.
      v2trace('GarmentPreview.load.ERROR longSide=${widget.longSide} '
          'after ${sw.elapsedMilliseconds}ms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return RawImage(image: img, fit: BoxFit.contain);
  }
}
