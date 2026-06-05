// T4 — MerchShareExporter + share text unit tests (M142)

import 'package:flutter_test/flutter_test.dart';

// ── Share text formula (used by _shareDesign() on option cards) ───────────────

String _buildShareText(String title, int n) =>
    '$title — $n ${n == 1 ? "country" : "countries"} '
    "I've visited, designed with Roavvy 🌍";

void main() {
  group('Share text format', () {
    test('singular: uses "country"', () {
      final text = _buildShareText('Japan Adventure', 1);
      expect(text, contains('Japan Adventure'));
      expect(text, contains('1 country'));
      expect(text, isNot(contains('countries')));
      expect(text, contains('Roavvy'));
    });

    test('plural: uses "countries"', () {
      final text = _buildShareText('My Passport Design', 42);
      expect(text, contains('42 countries'));
      expect(text, contains('My Passport Design'));
      expect(text, contains('Roavvy'));
    });

    test('title is included verbatim', () {
      const title = 'Grand Tour 2024';
      final text = _buildShareText(title, 8);
      expect(text, startsWith(title));
    });
  });
}
