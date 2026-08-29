# M174 — Interactive Photorealistic T-Shirt Mockup Canvas

**Phase:** 30 — Advanced Merch Studio & Photorealistic Mockups  
**Depends on:** M58 (mockup preview screen), M96 (preset merch customisation), M100 (card rendering)  
**Status:** Queued  
**Primary Target:** `apps/mobile_flutter`

---

## 1. Goal

Upgrade Roavvy's t-shirt merchandise preview from a static placed image into an interactive, photorealistic client-side canvas that mimics a Photoshop (PSD) Smart Object. 

Users can freely reposition, scale, and rotate their travel artwork directly on the garment in real time. The t-shirt's natural fabric folds, creases, and lighting highlights dynamically bleed through the artwork at locked 60fps/120fps (ProMotion), while strictly constraining the design to the garment's physical printable boundary.

---

## 2. Product & Interaction Specifications

### 2.1 The User Interaction Model
* **Direct Manipulation:**
  * **Pan:** 1-finger drag translates the graphic across the chest printing area.
  * **Pinch-to-Zoom:** 2-finger pinch scales the graphic smoothly around the gesture focal point.
  * **Two-Finger Rotation:** 2-finger twist rotates the design smoothly around the focal point.
* **Constraints & Clamping:**
  * Minimum scale: $0.3\times$ of print bounding box (prevents disappearing/sub-pixel artwork).
  * Maximum scale: $2.5\times$ of print bounding box (prevents severe pixelation/loss of visual quality).
* **Isolation Boundary:**
  * Artwork is strictly clipped to the physical chest printable area (`spec.printAreaNorm`). Artwork dragged beyond the perimeter clips cleanly with no bleed onto the background UI.
* **HUD & Alignment Helpers:**
  * **Snap Actions:** Quick alignment buttons ("Center", "Left Chest", "Reset").
  * **Boundary Guide:** Subtle dashed boundary box appears during active gestures and fades out 1.2s after `onScaleEnd`.

---

## 3. Architecture & Rendering Pipeline

### 3.1 The 3-Layer Composite Architecture

```
                                  TOP LAYER
             ┌────────────────────────────────────────────────────────┐
             │ Greyscale Shadow & Wrinkle Displacement Map            │
             │ (BlendMode.multiply + BlendMode.dstIn Artwork Mask)    │
             └───────────────────────────▲────────────────────────────┘
                                         │ (Applies shadows onto artwork only)
                                 MIDDLE LAYER
             ┌────────────────────────────────────────────────────────┐
             │ Interactive Design Viewport (Matrix4 + ClipRect)       │
             │ (User Transparent PNG Artwork rotated/scaled/panned)   │
             └───────────────────────────▲────────────────────────────┘
                                         │ (Overlaid over base shirt)
                                 BOTTOM LAYER
             ┌────────────────────────────────────────────────────────┐
             │ Base Garment Layer (High-res shirt photo + swatch tone)│
             └────────────────────────────────────────────────────────┘
```

#### Layer 1: Base Garment (Bottom)
* Displays the clean, high-resolution t-shirt asset ([`productImage`](file:///Users/adglad/git/roavvy/apps/mobile_flutter/lib/features/merch/local_mockup_painter.dart)).
* Rendered using `BoxFit.contain` centered on the viewport.

#### Layer 2: Interactive Design Canvas (Middle)
* Translates, scales, and rotates the user's transparent PNG artwork using an active `Matrix4`.
* Contained inside a `clipRect(printPixels)` boundary derived from `spec.printAreaNorm`.

#### Layer 3: Texture & Wrinkle Overlay (Top)
* Greyscale shadow/highlight map asset.
* **Alpha-Masked Multiply Formula:**
  1. Open off-screen buffer: `canvas.saveLayer(printPixels, Paint())`
  2. Draw greyscale fabric shading pass: `blendMode: BlendMode.multiply, opacity: 0.35`
  3. Mask shading to active artwork pixels: Draw transformed artwork with `blendMode: BlendMode.dstIn`
  4. Close buffer: `canvas.restore()`
* **Why this is critical:** Standard `multiply` over the whole print rectangle creates a dark rectangular box over transparent PNG backgrounds. The `dstIn` step erases shading from transparent pixels, applying fabric wrinkles exclusively to the active artwork pixels.

---

### 3.2 Performance & Matrix Architecture

To prevent frame drops on ProMotion (120Hz) displays, **zero widget tree rebuilds (`setState`) occur during gestures**.

```
Gesture Events (onScaleStart, onScaleUpdate, onScaleEnd)
                           │
                           ▼
             MockupTransformController
         (Pure Dart Matrix Math & Clamping)
                           │
                           ▼
          ValueNotifier<MockupTransform>
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
    RepaintBoundary               TshirtMockupPainter
(Isolates render subtree)      (Canvas paint pass only)
```

---

## 4. Coding Directions & Mathematical Specification

### 4.1 Matrix4 Gesture Mathematics

#### State Data Model:
```dart
class MockupTransform {
  final Offset translation; // in local canvas pixels
  final double scale;       // 1.0 = fit inside print area
  final double rotation;    // in radians

  const MockupTransform({
    this.translation = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  Matrix4 toMatrix4(Size printSize) {
    final center = Offset(printSize.width / 2, printSize.height / 2);
    return Matrix4.identity()
      ..translate(center.dx + translation.dx, center.dy + translation.dy)
      ..rotateZ(rotation)
      ..scale(scale, scale)
      ..translate(-center.dx, -center.dy);
  }
}
```

#### Gesture Calculation Loop (`MockupTransformController`):
1. **On `onScaleStart(ScaleStartDetails details)`:**
   - Record `_startTransform = currentTransform`
   - Record `_startFocalPoint = details.localFocalPoint`
2. **On `onScaleUpdate(ScaleUpdateDetails details)`:**
   - Calculate delta translation: $\Delta T = \text{details.localFocalPoint} - \text{\_startFocalPoint}$
   - Calculate delta scale: $S = (\text{\_startTransform.scale} \times \text{details.scale}).\text{clamp}(0.3, 2.5)$
   - Calculate delta rotation: $\theta = \text{\_startTransform.rotation} + \text{details.rotation}$
   - Update `ValueNotifier<MockupTransform>` directly.
3. **On `onScaleEnd(ScaleEndDetails details)`:**
   - Persist normalized placement parameters:
     $$x_{\text{norm}} = \frac{\text{translation.dx}}{\text{printWidth}}, \quad y_{\text{norm}} = \frac{\text{translation.dy}}{\text{printHeight}}, \quad \text{scale}, \quad \text{rotation}$$

---

### 4.2 Painter Implementation Strategy (`TshirtMockupPainter`)

```dart
class TshirtMockupPainter extends CustomPainter {
  TshirtMockupPainter({
    required this.baseImage,
    required this.shadowMapImage,
    required this.artworkImage,
    required this.spec,
    required this.transformNotifier,
    required this.isGestureActiveNotifier,
  }) : super(repaint: Listenable.merge([transformNotifier, isGestureActiveNotifier]));

  final ui.Image baseImage;
  final ui.Image? shadowMapImage;
  final ui.Image? artworkImage;
  final ProductMockupSpec spec;
  final ValueNotifier<MockupTransform> transformNotifier;
  final ValueNotifier<bool> isGestureActiveNotifier;

  @override
  void paint(Canvas canvas, Size size) {
    final dstRect = _calculateDestinationRect(size, baseImage);
    final printPixels = _calculatePrintPixels(dstRect, spec.printAreaNorm);

    // 1. Layer 1: Base T-Shirt
    canvas.drawImageRect(
      baseImage,
      Rect.fromLTWH(0, 0, baseImage.width.toDouble(), baseImage.height.toDouble()),
      dstRect,
      Paint(),
    );

    if (artworkImage == null) return;

    // 2. Layer 2: Clipped & Transformed User Artwork
    canvas.save();
    canvas.clipRect(printPixels);

    final transform = transformNotifier.value;
    final matrix = transform.toMatrix4(printPixels.size);

    canvas.save();
    canvas.translate(printPixels.left, printPixels.top);
    canvas.transform(matrix.storage);

    final artworkSrc = Rect.fromLTWH(
      0, 0, artworkImage!.width.toDouble(), artworkImage!.height.toDouble(),
    );
    final artworkDst = _calculateFittedRect(printPixels.size, artworkSrc);

    canvas.drawImageRect(artworkImage!, artworkSrc, artworkDst, Paint());
    canvas.restore(); // Restore matrix transform
    canvas.restore(); // Restore clipRect

    // 3. Layer 3: Alpha-Masked Wrinkle & Shadow Composite
    if (shadowMapImage != null) {
      canvas.save();
      canvas.clipRect(printPixels);
      // Create offscreen layer
      canvas.saveLayer(printPixels, Paint());

      // Pass A: Draw shadow map with multiply
      canvas.drawImageRect(
        shadowMapImage!,
        Rect.fromLTWH(0, 0, shadowMapImage!.width.toDouble(), shadowMapImage!.height.toDouble()),
        dstRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..color = const Color(0x66FFFFFF), // Shading opacity control
      );

      // Pass B: Mask shading strictly to artwork alpha
      canvas.save();
      canvas.translate(printPixels.left, printPixels.top);
      canvas.transform(matrix.storage);
      canvas.drawImageRect(
        artworkImage!,
        artworkSrc,
        artworkDst,
        Paint()..blendMode = BlendMode.dstIn,
      );
      canvas.restore();

      canvas.restore(); // Composites masked layer back to canvas
      canvas.restore(); // Restore clipRect
    }

    // 4. Debug & Gesture Boundary Guide
    if (isGestureActiveNotifier.value) {
      _paintDashedGuide(canvas, printPixels);
    }
  }

  @override
  bool shouldRepaint(covariant TshirtMockupPainter oldDelegate) => false;
}
```

---

## 5. Detailed Task Breakdown

### Task T1: Math Model & Controller (`MockupTransformController`)
- **File:** `apps/mobile_flutter/lib/features/merch/mockup_transform_controller.dart`
- Implement immutable `MockupTransform` with copyWith, serialization (`toJson`/`fromJson`), and matrix conversion.
- Implement `MockupTransformController` managing `ValueNotifier<MockupTransform>`.
- Add clamping math for scale $[0.3, 2.5]$, translation boundary dampening, and reset/center presets.

### Task T2: Asset Spec & Shadow Map Pipeline
- **Files:** `apps/mobile_flutter/lib/features/merch/product_mockup_specs.dart`, `assets/mockups/`
- Add `shadowMapAssetPath` to `ProductMockupSpec`.
- Preload companion shadow maps into `LocalMockupImageCache`.

### Task T3: 3-Layer Composite Painter (`TshirtMockupPainter`)
- **File:** `apps/mobile_flutter/lib/features/merch/tshirt_mockup_painter.dart`
- Implement custom painter with `saveLayer`, `BlendMode.multiply`, and `BlendMode.dstIn` alpha masking.
- Add dashed boundary guide rendering during active gestures.

### Task T4: Interactive Widget (`TshirtMockupCanvas`)
- **File:** `apps/mobile_flutter/lib/features/merch/tshirt_mockup_canvas.dart`
- Wrap canvas in `GestureDetector(onScaleStart, onScaleUpdate, onScaleEnd)`.
- Wrap in `RepaintBoundary` to isolate paint pipeline.
- Implement floating HUD bar with "Reset", "Center", and "Left Chest" quick actions.

### Task T5: Integration into `LocalMockupPreviewScreen`
- **File:** `apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart`
- Replace static `LocalMockupPainter` with `TshirtMockupCanvas`.
- Wire normalized transform parameters into cart creation payload and Printful placement mapper.

### Task T6: Verification & Quality Gates
- **Files:** `test/features/merch/mockup_transform_test.dart`, `test/features/merch/tshirt_mockup_canvas_test.dart`
- Unit test matrix math: focal point invariance, scale bounds, rotation math.
- Widget test: multi-touch interaction, clipping containment, HUD action execution.
- Ensure 0 analyze warnings and clean test passes.

---

## 6. Acceptance Criteria

- [ ] Multi-touch pan, pinch-zoom, and rotation operate simultaneously with zero stutter on 60Hz and 120Hz displays.
- [ ] User artwork never spills outside the designated chest print area (`printAreaNorm`).
- [ ] T-shirt wrinkles and folds visibly bleed through dark and light artwork.
- [ ] No dark rectangular background box is visible when using transparent PNG artwork.
- [ ] Quick-action buttons ("Center", "Left Chest", "Reset") smoothly re-align the design.
- [ ] Normalized transformation coordinates are correctly passed to Printful placement payloads.
- [ ] `flutter analyze` and `flutter test` pass with 100% clean status.
