// M174 — MockupTransform maths + MockupTransformController gesture handling.
//
// These are the numbers that decide where a design lands on the shirt AND in
// the print file, so they are pinned here rather than eyeballed on device.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/mockup_transform.dart';

void main() {
  const printSize = Size(200, 400);

  /// Maps a print-area-local point through a transform, the way the painter and
  /// the print exporter both do.
  Offset apply(MockupTransform t, Offset p) {
    final v = t.toMatrix4(printSize).applied(Vector3ish(p.dx, p.dy));
    return Offset(v.$1, v.$2);
  }

  group('MockupTransform', () {
    test('identity leaves every point where it was', () {
      const t = MockupTransform.identity;
      expect(t.isIdentity, isTrue);
      final p = apply(t, const Offset(37, 91));
      expect(p.dx, closeTo(37, 1e-9));
      expect(p.dy, closeTo(91, 1e-9));
    });

    test('translation is a fraction of the print area, not pixels', () {
      const t = MockupTransform(translation: Offset(0.5, 0.25));
      final p = apply(t, const Offset(100, 200)); // the centre
      // Half a print area right (100px) and a quarter down (100px).
      expect(p.dx, closeTo(200, 1e-6));
      expect(p.dy, closeTo(300, 1e-6));
    });

    test('scale grows about the print-area centre, which stays fixed', () {
      const t = MockupTransform(scale: 2.0);
      final centre = apply(t, const Offset(100, 200));
      expect(centre.dx, closeTo(100, 1e-6));
      expect(centre.dy, closeTo(200, 1e-6));
      // A point one quarter across moves twice as far from the centre.
      final edge = apply(t, const Offset(50, 200));
      expect(edge.dx, closeTo(0, 1e-6));
    });

    test('rotation turns about the centre', () {
      final t = MockupTransform(rotation: math.pi / 2);
      final centre = apply(t, const Offset(100, 200));
      expect(centre.dx, closeTo(100, 1e-6));
      expect(centre.dy, closeTo(200, 1e-6));
      // 90° clockwise: a point directly above the centre swings to its right.
      final above = apply(t, const Offset(100, 100));
      expect(above.dx, closeTo(200, 1e-6));
      expect(above.dy, closeTo(200, 1e-6));
    });

    test('json round-trips and omits defaults', () {
      const t = MockupTransform(
        translation: Offset(0.2, -0.3),
        scale: 1.4,
        rotation: 0.35,
      );
      expect(MockupTransform.fromJson(t.toJson()), t);
      expect(MockupTransform.identity.toJson(), isEmpty);
    });

    test('fromJson tolerates missing, null and out-of-range values', () {
      expect(MockupTransform.fromJson(null), MockupTransform.identity);
      expect(MockupTransform.fromJson(const {}), MockupTransform.identity);
      // An older/corrupt record must not produce an invisible or giant print.
      expect(
        MockupTransform.fromJson(const {'scale': 99}).scale,
        MockupTransform.maxScale,
      );
      expect(
        MockupTransform.fromJson(const {'scale': 0.001}).scale,
        MockupTransform.minScale,
      );
      expect(MockupTransform.fromJson(const {'scale': double.nan}).scale, 1.0);
    });
  });

  group('MockupTransformController', () {
    late MockupTransformController c;
    late List<MockupTransform> commits;

    setUp(() {
      c = MockupTransformController()..setPrintSize(printSize);
      commits = [];
      c.onCommit = commits.add;
    });

    tearDown(() => c.dispose());

    ScaleStartDetails start(Offset at) =>
        ScaleStartDetails(localFocalPoint: at);
    ScaleUpdateDetails update(
      Offset at, {
      double scale = 1.0,
      double rotation = 0.0,
    }) => ScaleUpdateDetails(
      localFocalPoint: at,
      scale: scale,
      rotation: rotation,
    );

    test('a drag translates by the focal delta over the print size', () {
      c.onScaleStart(start(const Offset(50, 50)));
      c.onScaleUpdate(update(const Offset(100, 150)));
      // +50px of 200 wide, +100px of 400 tall.
      expect(c.value.translation.dx, closeTo(0.25, 1e-9));
      expect(c.value.translation.dy, closeTo(0.25, 1e-9));
      expect(c.value.scale, 1.0);
    });

    test('pinch and twist accumulate from the gesture start', () {
      c.onScaleStart(start(const Offset(100, 200)));
      c.onScaleUpdate(
        update(const Offset(100, 200), scale: 1.5, rotation: 0.4),
      );
      expect(c.value.scale, closeTo(1.5, 1e-9));
      expect(c.value.rotation, closeTo(0.4, 1e-9));

      // A second gesture compounds on the committed value (1.5 × 1.6 = 2.4,
      // still inside the printable range).
      c.onScaleEnd(ScaleEndDetails());
      c.onScaleStart(start(const Offset(100, 200)));
      c.onScaleUpdate(update(const Offset(100, 200), scale: 1.6));
      expect(c.value.scale, closeTo(2.4, 1e-9));
    });

    test('scale is clamped to the printable range', () {
      c.onScaleStart(start(Offset.zero));
      c.onScaleUpdate(update(Offset.zero, scale: 99));
      expect(c.value.scale, MockupTransform.maxScale);
      c.onScaleUpdate(update(Offset.zero, scale: 0.0001));
      expect(c.value.scale, MockupTransform.minScale);
    });

    test('translation is clamped so the design is never lost off-canvas', () {
      c.onScaleStart(start(Offset.zero));
      c.onScaleUpdate(update(const Offset(100000, -100000)));
      expect(c.value.translation.dx, 1.0);
      expect(c.value.translation.dy, -1.0);
    });

    test(
      'a gesture commits once, on end, and flags activity while running',
      () {
        expect(c.isGestureActive.value, isFalse);
        c.onScaleStart(start(Offset.zero));
        expect(c.isGestureActive.value, isTrue);
        c.onScaleUpdate(update(const Offset(10, 10)));
        c.onScaleUpdate(update(const Offset(20, 20)));
        expect(commits, isEmpty, reason: 'mid-gesture updates must not commit');
        c.onScaleEnd(ScaleEndDetails());
        expect(c.isGestureActive.value, isFalse);
        expect(commits, hasLength(1));
      },
    );

    test('an update before layout (no print size) is ignored, not a crash', () {
      final fresh = MockupTransformController();
      addTearDown(fresh.dispose);
      fresh.onScaleStart(start(Offset.zero));
      fresh.onScaleUpdate(update(const Offset(40, 40)));
      expect(fresh.value, MockupTransform.identity);
    });

    group('quick actions', () {
      test('Centre keeps scale and rotation, drops the offset', () {
        c.onScaleStart(start(Offset.zero));
        c.onScaleUpdate(
          update(const Offset(40, 40), scale: 1.6, rotation: 0.3),
        );
        c.onScaleEnd(ScaleEndDetails());
        c.center();
        expect(c.value.translation, Offset.zero);
        expect(c.value.scale, closeTo(1.6, 1e-9));
        expect(c.value.rotation, closeTo(0.3, 1e-9));
      });

      test('Left chest is a small upright badge, high and to one side', () {
        c.leftChest();
        expect(c.value.scale, lessThan(0.5));
        expect(c.value.rotation, 0.0);
        expect(c.value.translation.dx, greaterThan(0));
        expect(c.value.translation.dy, lessThan(0)); // high on the chest
      });

      test('Straighten only zeroes rotation', () {
        c.onScaleStart(start(Offset.zero));
        c.onScaleUpdate(update(const Offset(30, 0), scale: 1.2, rotation: 0.9));
        c.onScaleEnd(ScaleEndDetails());
        final before = c.value;
        c.straighten();
        expect(c.value.rotation, 0.0);
        expect(c.value.translation, before.translation);
        expect(c.value.scale, before.scale);
      });

      test('Reset returns to identity and commits', () {
        c.leftChest();
        commits.clear();
        c.reset();
        expect(c.value, MockupTransform.identity);
        expect(commits, [MockupTransform.identity]);
      });

      test('a no-op action does not commit', () {
        c.center(); // already centred
        expect(commits, isEmpty);
      });

      test('restore sets the value without committing', () {
        c.restore(const MockupTransform(scale: 2.0));
        expect(c.value.scale, 2.0);
        expect(commits, isEmpty);
      });
    });
  });
}

/// Minimal 2D point application for a [Matrix4] without importing vector_math
/// directly in the test.
extension on Matrix4 {
  (double, double) applied(Vector3ish p) {
    final s = storage;
    return (s[0] * p.x + s[4] * p.y + s[12], s[1] * p.x + s[5] * p.y + s[13]);
  }
}

class Vector3ish {
  const Vector3ish(this.x, this.y);
  final double x;
  final double y;
}
