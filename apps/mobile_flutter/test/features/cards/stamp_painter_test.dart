import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/passport_stamp_model.dart';
import 'package:mobile_flutter/features/cards/stamp_painter.dart';

StampData _stamp(StampStyle style) => StampData.fromCode(
      'JP',
      style: style,
      inkFamilyIndex: 0,
      ageEffect: StampAgeEffect.fresh,
      rotation: 0.1,
      center: const Offset(100, 100),
    );

void main() {
  group('StampPainter', () {
    for (final style in StampStyle.values) {
      testWidgets('renders $style without assertion errors', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: StampPainter(_stamp(style)),
                ),
              ),
            ),
          ),
        );
        // No errors thrown during paint.
        expect(tester.takeException(), isNull);
      });
    }

    test('shouldRepaint returns false for identical stamp', () {
      final stamp = _stamp(StampStyle.airportEntry);
      final painter1 = StampPainter(stamp);
      final painter2 = StampPainter(stamp);
      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true when stamp changes', () {
      final painter1 = StampPainter(_stamp(StampStyle.airportEntry));
      final painter2 = StampPainter(_stamp(StampStyle.landBorder));
      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}
