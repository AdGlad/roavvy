import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/grid_math_engine.dart';

void main() {
  group('gridLayout (ADR-118)', () {
    // ── Edge cases ──────────────────────────────────────────────────────────

    test('n=0 returns empty layout', () {
      final layout = gridLayout(const Size(300, 200), 0);
      expect(layout.cols, 0);
      expect(layout.rows, 0);
      expect(layout.tileSize, 0);
      expect(layout.overflow, 0);
    });

    test('zero-width canvas returns empty layout', () {
      final layout = gridLayout(const Size(0, 200), 5);
      expect(layout, same(GridLayout.empty));
    });

    test('zero-height canvas returns empty layout', () {
      final layout = gridLayout(const Size(300, 0), 5);
      expect(layout, same(GridLayout.empty));
    });

    test('n=1 produces tileSize clamped to 90', () {
      // cols = ceil(sqrt(1 * 300 / 200)) = ceil(1.225) = 2
      // tileSize = 300/2 = 150 → clamped to 90
      final layout = gridLayout(const Size(300, 200), 1);
      expect(layout.cols, 2);
      expect(layout.rows, 1);
      expect(layout.tileSize, 90.0);
      expect(layout.overflow, 0);
    });

    // ── Portrait vs landscape produce different geometries ──────────────────

    test('portrait and landscape differ for same n', () {
      final portrait = gridLayout(const Size(200, 300), 20);
      final landscape = gridLayout(const Size(300, 200), 20);
      // portrait: cols = ceil(sqrt(20 * 200/300)) = ceil(sqrt(13.3)) = ceil(3.65) = 4
      // landscape: cols = ceil(sqrt(20 * 300/200)) = ceil(sqrt(30)) = ceil(5.48) = 6
      expect(portrait.cols, lessThan(landscape.cols));
    });

    test('portrait n=20: cols=4', () {
      // sqrt(20 * 200 / 300) = sqrt(13.33) ≈ 3.65 → ceil = 4
      final layout = gridLayout(const Size(200, 300), 20);
      expect(layout.cols, 4);
      expect(layout.rows, 5); // ceil(20/4)
    });

    test('landscape n=20: cols=6', () {
      // sqrt(20 * 300 / 200) = sqrt(30) ≈ 5.48 → ceil = 6
      final layout = gridLayout(const Size(300, 200), 20);
      expect(layout.cols, 6);
      expect(layout.rows, 4); // ceil(20/6) = ceil(3.33) = 4
    });

    // ── Tile size clamping ──────────────────────────────────────────────────

    test('tile size is always >= 28', () {
      for (final n in [1, 5, 20, 50, 100, 200]) {
        final layout = gridLayout(const Size(300, 200), n);
        expect(layout.tileSize, greaterThanOrEqualTo(28.0),
            reason: 'n=$n must produce tileSize >= 28');
      }
    });

    test('tile size is always <= 90', () {
      for (final n in [1, 2, 3]) {
        final layout = gridLayout(const Size(300, 200), n);
        expect(layout.tileSize, lessThanOrEqualTo(90.0),
            reason: 'n=$n must produce tileSize <= 90');
      }
    });

    test('large n (200) clamps to minimum tile size', () {
      final layout = gridLayout(const Size(300, 200), 200);
      expect(layout.tileSize, 28.0);
    });

    // ── Overflow cap ────────────────────────────────────────────────────────

    test('n <= 40 produces zero overflow', () {
      final layout = gridLayout(const Size(300, 200), 40);
      expect(layout.overflow, 0);
    });

    test('n=50 produces overflow=10', () {
      final layout = gridLayout(const Size(300, 200), 50);
      expect(layout.overflow, 10);
    });

    test('n=1 produces zero overflow', () {
      final layout = gridLayout(const Size(300, 200), 1);
      expect(layout.overflow, 0);
    });

    // ── cols × rows >= n (no flags lost) ────────────────────────────────────

    test('cols * rows >= n for various sizes', () {
      const sizes = [1, 5, 10, 20, 30, 40, 50, 100];
      for (final n in sizes) {
        final layout = gridLayout(const Size(300, 200), n);
        expect(layout.cols * layout.rows, greaterThanOrEqualTo(n),
            reason: 'n=$n: grid must have capacity for all flags');
      }
    });
  });

}
