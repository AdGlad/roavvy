// Verifies the cut-off fix against the REAL Australia country outline: every
// point inside the fitted clip path must have a flag tile under it, so the
// rendered outline can never be sheared by a straight boundary edge.
//
// This is a deterministic geometry check (no raster / no SVG) that loads the
// bundled assets/country_paths/au.json outline and runs it through the ACTUAL
// clip-path builder used at render time, then measures coverage by the flag
// layout with coverGrid on vs off.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_templates.dart';
import 'package:mobile_flutter/features/cards/card_text_renderer.dart';
import 'package:mobile_flutter/features/cards/country_path_service.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Landscape card (the reported cut-off orientation).
  const size = Size(600, 400);
  const topOffset = CardTextRenderer.titleZoneH; // 28
  const bottomOffset = CardTextRenderer.brandingZoneH; // 20

  /// Fraction of points inside [clip] that are also inside some flag [tiles]
  /// rect. `optionalRegion` restricts sampling (e.g. the bottom-right quadrant).
  double coverage(
    ui.Path clip,
    List<FlagGridTile> tiles, {
    Rect? region,
  }) {
    final b = region ?? clip.getBounds();
    const n = 80;
    var inside = 0;
    var covered = 0;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final pt = Offset(
          b.left + (i + 0.5) / n * b.width,
          b.top + (j + 0.5) / n * b.height,
        );
        if (!clip.contains(pt)) continue;
        inside++;
        // Expand tiles by the inter-row gutter so the thin (intended) gaps
        // between flags don't count as "not covered" — we only care about the
        // large straight-edge shear.
        for (final t in tiles) {
          if (t.rect.inflate(2.5).contains(pt)) {
            covered++;
            break;
          }
        }
      }
    }
    return inside == 0 ? 1.0 : covered / inside;
  }

  test('Australia outline clip is fully covered by flags with coverGrid (fix)',
      () async {
    final outline = await CountryPathService.pathFor('au', const Size(800, 533));
    expect(outline, isNotNull,
        reason: 'au.json outline must load from the bundled asset');

    final clip = clipPathForTesting(
      size,
      GridClipShape.countryOutline,
      outlinePath: outline,
      topOffset: topOffset,
      bottomOffset: bottomOffset,
    );

    List<FlagGridTile> tiles({
      required bool coverGrid,
      FlagGridLayoutMode mode = FlagGridLayoutMode.packedRow,
    }) =>
        FlagGridLayoutEngine.compute(
          codes: const ['au'],
          canvasSize: size,
          topOffset: topOffset,
          bottomOffset: bottomOffset,
          rowCount: 3,
          // A realistic single-country repeat (the rows slider) — montage
          // scatters this many tiles, which is where the gaps appeared.
          flagRepeatCount: 9,
          mode: mode,
          coverGrid: coverGrid,
        );

    final withFix = tiles(coverGrid: true);
    final withoutFix = tiles(coverGrid: false);

    final clipB = clip.getBounds();
    // The bottom-right quadrant — exactly where the user's screenshot was cut.
    final bottomRight = Rect.fromLTRB(
      clipB.center.dx,
      clipB.center.dy,
      clipB.right,
      clipB.bottom,
    );

    final covFull = coverage(clip, withFix);
    final covFullBR = coverage(clip, withFix, region: bottomRight);
    final covOldBR = coverage(clip, withoutFix, region: bottomRight);

    // With the fix, essentially the entire outline (and its bottom-right
    // corner) has flags under it — no straight-edge shear.
    expect(covFull, greaterThan(0.98), reason: 'whole outline must be covered');
    expect(covFullBR, greaterThan(0.98),
        reason: 'bottom-right corner (the reported cut) must be covered');
    // And the fix genuinely matters: the old centred layout left the
    // bottom-right materially uncovered.
    expect(covFullBR, greaterThan(covOldBR),
        reason: 'coverGrid must improve coverage vs the old behaviour');

    // ── Montage mode (the reported case) ─────────────────────────────────────
    final montageFix = tiles(coverGrid: true, mode: FlagGridLayoutMode.montage);
    final montageOld = tiles(coverGrid: false, mode: FlagGridLayoutMode.montage);
    final montageCov = coverage(clip, montageFix);
    final montageCovBR = coverage(clip, montageFix, region: bottomRight);
    final montageOldBR = coverage(clip, montageOld, region: bottomRight);
    expect(montageCov, greaterThan(0.98),
        reason: 'montage must fully fill the outline under a clip');
    expect(montageCovBR, greaterThan(0.98),
        reason: 'montage bottom-right (the reported cut) must be filled');
    expect(montageCovBR, greaterThan(montageOldBR),
        reason: 'coverGrid montage must improve coverage vs the old scatter');
  });
}
