import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/map/country_polygon_layer.dart';

void main() {
  group('depthFillColor', () {
    test('0 trips returns visited fallback colour', () {
      expect(depthFillColor(0), const Color(0xFFFFB300));
    });

    test('1 trip returns lightest amber', () {
      expect(depthFillColor(1), const Color(0xFFFFE082));
    });

    test('3 trips returns mid amber', () {
      expect(depthFillColor(3), const Color(0xFFFFCA28));
    });

    test('2 trips also returns mid amber', () {
      expect(depthFillColor(2), const Color(0xFFFFCA28));
    });

    test('4 trips returns dark amber', () {
      expect(depthFillColor(4), const Color(0xFFFFB300));
    });

    test('5 trips returns dark amber', () {
      expect(depthFillColor(5), const Color(0xFFFFB300));
    });

    test('6 trips returns deepest amber', () {
      expect(depthFillColor(6), const Color(0xFFFF8F00));
    });

    test('100 trips returns deepest amber', () {
      expect(depthFillColor(100), const Color(0xFFFF8F00));
    });
  });
}
