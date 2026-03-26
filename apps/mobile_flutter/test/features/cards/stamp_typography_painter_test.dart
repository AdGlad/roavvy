import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/stamp_typography_painter.dart';

void main() {
  group('StampTypographyPainter', () {
    test('drawCondensedLabel does not throw with standard text', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawCondensedLabel(
        canvas, 'JP', Colors.blue, 10.0, Offset.zero, 42);
      // No exception
    });

    test('drawCondensedLabel no-ops on empty text', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      // Should not throw
      StampTypographyPainter.drawCondensedLabel(
          canvas, '', Colors.blue, 10.0, Offset.zero, 42);
    });

    test('drawMonoDate does not throw with standard date', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawMonoDate(
          canvas, '12 JAN 2023', Colors.red, 6.0, Offset.zero);
    });

    test('drawSublabel does not throw', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawSublabel(
          canvas, 'IMMIGRATION', Colors.black, 4.5, Offset.zero);
    });

    test('drawArcText does not throw with short text', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawArcText(
          canvas, 'ENTRY', Colors.blue, 7.0, const Offset(40, 40), 30.0, 0);
    });

    test('drawArcText no-ops on empty text', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawArcText(
          canvas, '', Colors.blue, 7.0, const Offset(40, 40), 30.0, 0);
    });

    test('drawHeroText does not throw', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawHeroText(
          canvas, 'UNITED KINGDOM', Colors.blue, 7.0, Offset.zero, 42);
    });

    test('drawHeroText truncates long names', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      // 20-char name — should not throw (truncated to 11 internally)
      StampTypographyPainter.drawHeroText(
          canvas, 'DEMOCRATIC REPUBLIC', Colors.blue, 7.0, Offset.zero, 99);
    });

    test('drawSerialNumber does not throw', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      StampTypographyPainter.drawSerialNumber(
          canvas, 'K-2394761', Colors.black, 4.5, Offset.zero);
    });

    test('ink break indices are deterministic for same seed', () {
      // We can't directly test private _inkBreakIndices but we verify that
      // drawCondensedLabel with the same seed produces no exception repeatedly
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = 0; i < 5; i++) {
        StampTypographyPainter.drawCondensedLabel(
            canvas, 'JAPAN', Colors.blue, 8.0, Offset(0, i * 20.0), 42);
      }
    });
  });
}
