import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// M174 — the placement of the user's artwork inside a garment's printable
/// area, as a pan / pinch / twist transform.
///
/// Values are **normalised to the print area**, not to screen pixels, so the
/// same transform reproduces identically at preview resolution and at print
/// resolution (and survives a Firestore round-trip):
///   * [translation] — offset from the print area's centre, as a fraction of
///     the print area's width/height (`0.5` = half a print area across).
///   * [scale] — `1.0` means the artwork exactly contain-fits the print area.
///   * [rotation] — radians, clockwise, about the artwork's own centre.
@immutable
class MockupTransform {
  const MockupTransform({
    this.translation = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  /// The default placement: contain-fit, centred, upright.
  static const identity = MockupTransform();

  /// Offset from the print-area centre, in print-area fractions.
  final Offset translation;

  /// Artwork scale, where 1.0 contain-fits the print area.
  final double scale;

  /// Rotation in radians about the artwork centre.
  final double rotation;

  /// Smallest allowed scale — below this the artwork becomes sub-pixel noise.
  static const double minScale = 0.3;

  /// Largest allowed scale — above this a print-resolution file visibly
  /// pixelates.
  static const double maxScale = 2.5;

  bool get isIdentity =>
      translation == Offset.zero && scale == 1.0 && rotation == 0.0;

  MockupTransform copyWith({
    Offset? translation,
    double? scale,
    double? rotation,
  }) => MockupTransform(
    translation: translation ?? this.translation,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
  );

  /// The transform matrix for a print area of [printSize] **pixels**, applied
  /// about the print area's centre. The caller draws in print-area-local
  /// coordinates (origin at the print area's top-left).
  Matrix4 toMatrix4(Size printSize) {
    final cx = printSize.width / 2;
    final cy = printSize.height / 2;
    return Matrix4.identity()
      ..translateByDouble(
        cx + translation.dx * printSize.width,
        cy + translation.dy * printSize.height,
        0,
        1,
      )
      ..rotateZ(rotation)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }

  Map<String, dynamic> toJson() => {
    if (translation.dx != 0) 'tx': translation.dx,
    if (translation.dy != 0) 'ty': translation.dy,
    if (scale != 1.0) 'scale': scale,
    if (rotation != 0.0) 'rotation': rotation,
  };

  /// Rebuilds a transform from stored values, tolerating nulls, missing keys
  /// and out-of-range values (older cart items have no transform at all).
  factory MockupTransform.fromJson(Map<String, dynamic>? json) {
    if (json == null) return identity;
    double d(String k, double fallback) =>
        (json[k] as num?)?.toDouble() ?? fallback;
    final scale = d('scale', 1.0);
    return MockupTransform(
      translation: Offset(d('tx', 0), d('ty', 0)),
      scale: scale.isFinite ? scale.clamp(minScale, maxScale) : 1.0,
      rotation: d('rotation', 0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MockupTransform &&
      other.translation == translation &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(translation, scale, rotation);

  @override
  String toString() =>
      'MockupTransform(t: $translation, scale: $scale, rot: $rotation)';
}

/// Drives [MockupTransform] from raw scale-gesture callbacks.
///
/// The controller is deliberately **widget-free**: it does pure matrix maths
/// and publishes through a [ValueNotifier], so a gesture never triggers a
/// `setState`/rebuild — only a repaint of the listening [CustomPainter]. That
/// is what keeps the mockup canvas at 60/120fps during a drag.
class MockupTransformController {
  MockupTransformController({
    MockupTransform initial = MockupTransform.identity,
  }) : transform = ValueNotifier(initial),
       isGestureActive = ValueNotifier(false);

  /// The live placement. Listened to by the painter.
  final ValueNotifier<MockupTransform> transform;

  /// True between `onScaleStart` and `onScaleEnd` — drives the boundary guide.
  final ValueNotifier<bool> isGestureActive;

  /// Called on every committed gesture (drag/pinch end) with the new value —
  /// the host persists it (cart item, print file) from here.
  void Function(MockupTransform)? onCommit;

  MockupTransform _start = MockupTransform.identity;
  Offset _startFocal = Offset.zero;
  Size _printSize = Size.zero;

  MockupTransform get value => transform.value;

  /// How far, in print-area fractions, the artwork may travel beyond centre.
  /// One full print area in each direction is plenty of freedom while keeping
  /// the artwork recoverable (it can never be lost off-canvas).
  static const double _maxTranslation = 1.0;

  /// The print area's pixel size must be known to convert focal-point pixel
  /// deltas into normalised translation. The canvas sets it on layout.
  void setPrintSize(Size size) => _printSize = size;

  void onScaleStart(ScaleStartDetails details) {
    _start = transform.value;
    _startFocal = details.localFocalPoint;
    isGestureActive.value = true;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final w = _printSize.width, h = _printSize.height;
    if (w <= 0 || h <= 0) return;

    final deltaPx = details.localFocalPoint - _startFocal;
    final translation = Offset(
      (_start.translation.dx + deltaPx.dx / w).clamp(
        -_maxTranslation,
        _maxTranslation,
      ),
      (_start.translation.dy + deltaPx.dy / h).clamp(
        -_maxTranslation,
        _maxTranslation,
      ),
    );

    transform.value = MockupTransform(
      translation: translation,
      scale: (_start.scale * details.scale).clamp(
        MockupTransform.minScale,
        MockupTransform.maxScale,
      ),
      rotation: _start.rotation + details.rotation,
    );
  }

  void onScaleEnd(ScaleEndDetails details) {
    isGestureActive.value = false;
    onCommit?.call(transform.value);
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

  /// Back to contain-fit, centred, upright.
  void reset() => _apply(MockupTransform.identity);

  /// Centre the artwork, keeping the user's scale and rotation.
  void center() => _apply(transform.value.copyWith(translation: Offset.zero));

  /// The classic left-chest badge: a small mark set high on the wearer's left
  /// (the viewer's right), upright. Sized as a fraction of the print area so it
  /// reads as a badge on any placement.
  void leftChest() => _apply(
    const MockupTransform(translation: Offset(0.22, -0.24), scale: 0.35),
  );

  /// Nudge the rotation back to upright without touching position or scale.
  void straighten() => _apply(transform.value.copyWith(rotation: 0));

  void _apply(MockupTransform next) {
    if (next == transform.value) return;
    transform.value = next;
    onCommit?.call(next);
  }

  /// Replace the placement without firing [onCommit] — used when restoring a
  /// saved transform (e.g. reopening a cart item).
  void restore(MockupTransform value) => transform.value = value;

  /// Rotation snapped to the nearest degree, for HUD readouts.
  int get rotationDegrees =>
      (transform.value.rotation * 180 / math.pi).round() % 360;

  void dispose() {
    transform.dispose();
    isGestureActive.dispose();
  }
}
