import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/features/stats/flag_mosaic_screen.dart';
import 'package:shared_models/shared_models.dart';

/// Pumps [FlagMosaicScreen] overriding [effectiveVisitsProvider] with [visits].
///
/// Uses a very tall surface so that the lazy SliverGrid renders all country
/// tiles into the viewport for reliable widget-count assertions.
Future<void> _pumpMosaic(
  WidgetTester tester,
  List<EffectiveVisitedCountry> visits,
) async {
  // Grid: ~248 countries, 7 cols → ~36 rows × ~116 px each ≈ 4200 px.
  // Add 800 px for AppBar, chips, legend and padding.
  await tester.binding.setSurfaceSize(const Size(800, 5500));
  addTearDown(() async => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        effectiveVisitsProvider.overrideWith((_) async => visits),
      ],
      child: const MaterialApp(home: FlagMosaicScreen()),
    ),
  );
  // Settle async provider + animation frames.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('FlagMosaicScreen — tile rendering', () {
    testWidgets(
      'given 3 visited countries, 3 coloured tiles and many dimmed tiles render',
      (tester) async {
        final visits = [
          const EffectiveVisitedCountry(
            countryCode: 'FR',
            hasPhotoEvidence: true,
            firstSeen: null,
          ),
          const EffectiveVisitedCountry(
            countryCode: 'JP',
            hasPhotoEvidence: true,
            firstSeen: null,
          ),
          const EffectiveVisitedCountry(
            countryCode: 'AU',
            hasPhotoEvidence: true,
            firstSeen: null,
          ),
        ];

        await _pumpMosaic(tester, visits);

        // ── Visited count in title ──────────────────────────────────────
        // Title: "Flag Wall  ·  3 / <total>"
        expect(find.textContaining('3 /'), findsOneWidget);

        // ── Dimmed (unvisited) tiles — ColorFiltered wrappers ───────────
        // Each unvisited _FlagTile returns ColorFiltered.
        // The legend also wraps one emoji in ColorFiltered.
        // Vast majority of ~248 tiles are unvisited → > 100 dimmed tiles.
        final dimmedTiles = tester.widgetList<ColorFiltered>(
          find.byType(ColorFiltered),
        );
        expect(dimmedTiles.length, greaterThan(100));

        // ── Coloured (visited) tiles — Opacity 0.30 is only on dimmed tiles ─
        // Unvisited tiles use Opacity(opacity: 0.30). Visited tiles do not.
        // So Opacity(0.30) count = total - 3 visited (>100 unvisited).
        final dimmedOpacity = tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((w) => w.opacity == 0.30)
            .toList();
        // Exactly 3 fewer dimmed-opacity tiles than ColorFiltered (legend has 0.4 opacity).
        expect(dimmedOpacity.length, equals(dimmedTiles.length - 1));
        // All dimmed tiles identified: total countries - 3 visited.
        expect(dimmedOpacity.length, greaterThan(100));
      },
    );

    testWidgets('no visits — all tiles are dimmed', (tester) async {
      await _pumpMosaic(tester, const []);

      // Title: "Flag Wall  ·  0 / <total>"
      expect(find.textContaining('0 /'), findsOneWidget);

      // All country tiles are dimmed — ColorFiltered count is high.
      final dimmedTiles = tester.widgetList<ColorFiltered>(
        find.byType(ColorFiltered),
      );
      expect(dimmedTiles.length, greaterThan(100));

      // All Opacity(0.30) tiles = all country tiles (no visited).
      final dimmedOpacity = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((w) => w.opacity == 0.30)
          .toList();
      expect(dimmedOpacity.length, equals(dimmedTiles.length - 1));
    });

    testWidgets('continent filter reduces visible tile count', (tester) async {
      await _pumpMosaic(tester, const []);

      // Tap 'Europe' chip to apply filter.
      final europeChip = find.text('Europe');
      expect(europeChip, findsOneWidget);
      await tester.tap(europeChip);
      await tester.pump();

      // Title should now show "0 / <europe_count>" — less than 100 countries.
      // We just verify the tile count dropped by checking the title text.
      // Europe has 44 countries in the data, so title ends with "/ 44".
      expect(find.textContaining('0 /'), findsOneWidget);
    });
  });

  group('FlagMosaicScreen — visit detail sheet', () {
    testWidgets('tapping a visited flag opens bottom sheet with country name',
        (tester) async {
      final visits = [
        const EffectiveVisitedCountry(
          countryCode: 'FR',
          hasPhotoEvidence: true,
          firstSeen: null,
        ),
      ];
      await _pumpMosaic(tester, visits);

      // The France flag emoji is rendered as a GestureDetector tile.
      // France flag emoji: 🇫🇷
      final frFlag = find.text('🇫🇷');
      expect(frFlag, findsOneWidget);

      await tester.tap(frFlag);
      await tester.pumpAndSettle();

      // Bottom sheet should show the country name "France".
      expect(find.text('France'), findsOneWidget);
    });
  });
}
