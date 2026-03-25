import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/paper_texture_painter.dart';

void main() {
  group('PaperTexturePainter', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: CustomPaint(
                size: Size(300, 200),
                painter: PaperTexturePainter(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('shouldRepaint always returns false', () {
      const p = PaperTexturePainter();
      expect(p.shouldRepaint(const PaperTexturePainter()), isFalse);
    });
  });
}
