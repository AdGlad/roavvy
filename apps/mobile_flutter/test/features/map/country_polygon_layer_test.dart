import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/map/country_polygon_layer.dart';

void main() {
  group('depthFillColor', () {
    // Colour values updated for dark-ocean gold scheme (ADR-080).

    test('0 trips returns visited fallback colour', () {
      expect(depthFillColor(0), const Color(0xFFD4A017));
    });

    test('1 trip returns lightest gold', () {
      expect(depthFillColor(1), const Color(0xFFD4A017));
    });

    test('3 trips returns deeper gold', () {
      expect(depthFillColor(3), const Color(0xFFC8860A));
    });

    test('2 trips also returns deeper gold', () {
      expect(depthFillColor(2), const Color(0xFFC8860A));
    });

    test('4 trips returns amber-brown', () {
      expect(depthFillColor(4), const Color(0xFFB86A00));
    });

    test('5 trips also returns amber-brown', () {
      expect(depthFillColor(5), const Color(0xFFB86A00));
    });

    test('6 trips returns deep burnt amber', () {
      expect(depthFillColor(6), const Color(0xFF8B4500));
    });

    test('100 trips returns deep burnt amber', () {
      expect(depthFillColor(100), const Color(0xFF8B4500));
    });
  });
}
