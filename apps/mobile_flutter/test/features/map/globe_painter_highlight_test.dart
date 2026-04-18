// M69 — GlobePainter highlight/pulse extension tests (ADR-123)

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/map/globe_painter.dart';
import 'package:mobile_flutter/features/map/globe_projection.dart';

void main() {
  const proj = GlobeProjection();

  GlobePainter makePainter({
    String? highlightedCode,
    double pulseValue = 0.0,
  }) =>
      GlobePainter(
        polygons: const [],
        visualStates: const {},
        tripCounts: const {},
        projection: proj,
        highlightedCode: highlightedCode,
        pulseValue: pulseValue,
      );

  group('GlobePainter.shouldRepaint', () {
    test('returns false when nothing changes', () {
      final a = makePainter(highlightedCode: 'JP', pulseValue: 0.5);
      final b = makePainter(highlightedCode: 'JP', pulseValue: 0.5);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('returns true when pulseValue changes', () {
      final a = makePainter(highlightedCode: 'JP', pulseValue: 0.0);
      final b = makePainter(highlightedCode: 'JP', pulseValue: 0.5);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when highlightedCode changes', () {
      final a = makePainter(highlightedCode: 'JP');
      final b = makePainter(highlightedCode: 'FR');
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when highlightedCode goes from null to non-null', () {
      final a = makePainter();
      final b = makePainter(highlightedCode: 'JP', pulseValue: 0.5);
      expect(a.shouldRepaint(b), isTrue);
    });
  });
}
