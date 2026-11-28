import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'garment_mockup_painter.dart';
import 'garment_mockup_spec.dart';
import 'mockup_transform.dart';

/// M174 — the interactive photorealistic mockup surface.
///
/// Drag to move the design, pinch to resize, twist to rotate — directly on the
/// garment, with the fabric's folds bleeding through the ink. Behaves like a
/// Photoshop Smart Object: the artwork is clipped to the real printable area
/// and can never bleed onto the shirt beyond it.
///
/// Gestures drive a [MockupTransformController], which publishes through
/// [ValueNotifier]s that the painter listens to. Nothing here calls `setState`
/// during a gesture, and the painter sits under a [RepaintBoundary], so a drag
/// costs one paint of one layer.
class GarmentMockupCanvas extends StatefulWidget {
  const GarmentMockupCanvas({
    super.key,
    required this.spec,
    this.garmentImage,
    this.shadingImage,
    this.artworkImage,
    this.controller,
    this.initialTransform = MockupTransform.identity,
    this.artworkBlendMode = ui.BlendMode.multiply,
    this.shadingOpacity = 0.4,
    this.interactive = true,
    this.showHud = true,
    this.onTransformCommitted,
    this.debugPrintArea = false,
  });

  final GarmentMockupSpec spec;
  final ui.Image? garmentImage;
  final ui.Image? shadingImage;
  final ui.Image? artworkImage;

  /// Supply one to own the transform (e.g. to share it with a print export);
  /// otherwise the canvas creates and disposes its own.
  final MockupTransformController? controller;

  /// Starting placement — a saved cart item's stored transform, typically.
  final MockupTransform initialTransform;

  final ui.BlendMode artworkBlendMode;
  final double shadingOpacity;

  /// False renders the same composite but ignores touch — for thumbnails and
  /// read-only previews.
  final bool interactive;

  /// Whether to show the floating quick-action bar.
  final bool showHud;

  /// Fired when a gesture or quick action settles on a new placement.
  final ValueChanged<MockupTransform>? onTransformCommitted;

  final bool debugPrintArea;

  @override
  State<GarmentMockupCanvas> createState() => _GarmentMockupCanvasState();
}

class _GarmentMockupCanvasState extends State<GarmentMockupCanvas> {
  late MockupTransformController _controller;
  bool _ownsController = false;

  /// Drives the HUD's "edited" affordance without repainting the canvas.
  final ValueNotifier<bool> _isEdited = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    final supplied = widget.controller;
    if (supplied != null) {
      _controller = supplied;
      _ownsController = false;
    } else {
      _controller = MockupTransformController(initial: widget.initialTransform);
      _ownsController = true;
    }
    _controller.onCommit = _onCommit;
    _isEdited.value = !_controller.value.isIdentity;
  }

  void _onCommit(MockupTransform t) {
    _isEdited.value = !t.isIdentity;
    widget.onTransformCommitted?.call(t);
  }

  @override
  void didUpdateWidget(GarmentMockupCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    } else if (_controller.onCommit == _onCommit) {
      _controller.onCommit = null;
    }
    _isEdited.dispose();
    super.dispose();
  }

  /// The printable area in canvas pixels, so the controller can convert focal
  /// deltas into print-area fractions.
  void _syncPrintSize(Size canvasSize) {
    final img = widget.garmentImage;
    Size printSize;
    if (img == null) {
      printSize = Size(
        widget.spec.printAreaNorm.width * canvasSize.width,
        widget.spec.printAreaNorm.height * canvasSize.height,
      );
    } else {
      final crop = widget.spec.srcRectNorm;
      final srcW = img.width * (crop?.width ?? 1.0);
      final srcH = img.height * (crop?.height ?? 1.0);
      final scale =
          (canvasSize.width / srcW) < (canvasSize.height / srcH)
              ? canvasSize.width / srcW
              : canvasSize.height / srcH;
      printSize = Size(
        widget.spec.printAreaNorm.width * srcW * scale,
        widget.spec.printAreaNorm.height * srcH * scale,
      );
    }
    _controller.setPrintSize(printSize);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Layout-time, not gesture-time: no rebuild cost during a drag.
        _syncPrintSize(size);

        Widget canvas = RepaintBoundary(
          child: CustomPaint(
            painter: GarmentMockupPainter(
              spec: widget.spec,
              controller: _controller,
              garmentImage: widget.garmentImage,
              shadingImage: widget.shadingImage,
              artworkImage: widget.artworkImage,
              artworkBlendMode: widget.artworkBlendMode,
              shadingOpacity: widget.shadingOpacity,
              showGuide: widget.interactive,
              debugPrintArea: widget.debugPrintArea,
            ),
            child: const SizedBox.expand(),
          ),
        );

        if (widget.interactive) {
          canvas = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _controller.onScaleStart,
            onScaleUpdate: _controller.onScaleUpdate,
            onScaleEnd: _controller.onScaleEnd,
            child: canvas,
          );
        }

        if (!widget.interactive || !widget.showHud) return canvas;

        return Stack(
          fit: StackFit.expand,
          children: [
            canvas,
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              // Scrolls rather than overflows on narrow canvases (small
              // phones, split-screen, thumbnail hosts); centred when it fits.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: (constraints.maxWidth - 16).clamp(0.0, 4000.0),
                  ),
                  child: Center(
                    child: _MockupHud(
                      controller: _controller,
                      isEdited: _isEdited,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact quick-action pill: Centre · Left chest · Straighten · Reset.
///
/// Chips rather than buttons (design system: compact, icon-led controls), on a
/// translucent dark pill so the shirt stays the hero.
class _MockupHud extends StatelessWidget {
  const _MockupHud({required this.controller, required this.isEdited});

  final MockupTransformController controller;
  final ValueNotifier<bool> isEdited;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEdited,
      builder:
          (context, edited, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HudChip(
                  key: const Key('mockup-hud-center'),
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Centre',
                  onTap: controller.center,
                ),
                _HudChip(
                  key: const Key('mockup-hud-left-chest'),
                  icon: Icons.badge_outlined,
                  label: 'Left chest',
                  onTap: controller.leftChest,
                ),
                _HudChip(
                  key: const Key('mockup-hud-straighten'),
                  icon: Icons.straighten_rounded,
                  label: 'Straighten',
                  onTap: controller.straighten,
                ),
                _HudChip(
                  key: const Key('mockup-hud-reset'),
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  enabled: edited,
                  onTap: controller.reset,
                ),
              ],
            ),
          ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colour =
        enabled ? Colors.white : Colors.white.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colour),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.0,
                  color: colour,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience: loads a spec's garment + shading images, then builds a
/// [GarmentMockupCanvas]. Hosts that already hold decoded images should use the
/// widget directly.
class GarmentMockupCanvasLoader extends StatefulWidget {
  const GarmentMockupCanvasLoader({
    super.key,
    required this.spec,
    required this.loader,
    this.artworkImage,
    this.controller,
    this.artworkBlendMode = ui.BlendMode.multiply,
    this.onTransformCommitted,
  });

  final GarmentMockupSpec spec;

  /// Returns `(garment, shading)` for the spec — normally
  /// `LocalMockupImageCache.instance.loadWithShading`.
  final Future<(ui.Image, ui.Image)> Function(GarmentMockupSpec) loader;

  final ui.Image? artworkImage;
  final MockupTransformController? controller;
  final ui.BlendMode artworkBlendMode;
  final ValueChanged<MockupTransform>? onTransformCommitted;

  @override
  State<GarmentMockupCanvasLoader> createState() =>
      _GarmentMockupCanvasLoaderState();
}

class _GarmentMockupCanvasLoaderState extends State<GarmentMockupCanvasLoader> {
  (ui.Image, ui.Image)? _images;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(GarmentMockupCanvasLoader old) {
    super.didUpdateWidget(old);
    if (old.spec.assetPath != widget.spec.assetPath) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final images = await widget.loader(widget.spec);
      if (mounted) setState(() => _images = images);
    } catch (_) {
      if (mounted) setState(() => _images = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    return GarmentMockupCanvas(
      spec: widget.spec,
      garmentImage: images?.$1,
      shadingImage: images?.$2,
      artworkImage: widget.artworkImage,
      controller: widget.controller,
      artworkBlendMode: widget.artworkBlendMode,
      onTransformCommitted: widget.onTransformCommitted,
    );
  }
}
