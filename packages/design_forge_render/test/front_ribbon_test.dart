// The shirt FRONT: the app's original chest artwork — the ROAVVY wordmark over
// a grid of flag tiles. It is the default front, so its composition is pinned
// here rather than left to drift.
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// Solid, distinguishable flags — enough to tell "a flag was drawn here" from
/// "nothing was drawn here".
class _FlagResolver implements AssetResolver {
  @override
  Future<ui.Image> resolveFlag(String code,
      {required int width, required int height}) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF1E88E5),
    );
    return recorder.endRecording().toImage(width, height);
  }

  @override
  Future<ui.Image?> resolveClipMask(ClipShape shape, String? code,
          {required int width, required int height}) async =>
      null;

  @override
  Future<ui.Image?> resolvePassportCollage(List<PassportStampRef> stamps,
          {required int width,
          required int height,
          int seed = 0,
          double scatter = 0.5,
          double stampScale = 1.0,
          PassportInk ink = PassportInk.flag}) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DesignRecipe ribbon(
    List<String> codes, {
    Map<String, Object?> meta = const {},
    String? garment,
  }) =>
      DesignRecipe(
        seed: 1,
        content: RecipeContent(
          flags: [for (final c in codes) FlagRef(c)],
          source: 'test:front',
          meta: meta,
        ),
        composition: const Composition(family: DesignFamily.frontRibbon),
        palette: garment == null ? null : Palette(garmentColour: garment),
      );

  /// Renders and returns the artwork's pixels plus its size.
  Future<(List<int>, int, int)> render(
    WidgetTester tester,
    DesignRecipe recipe, {
    int w = 240,
    int h = 320,
  }) async {
    late List<int> px;
    late int rw, rh;
    await tester.runAsync(() async {
      // As RenderService does for the on-garment preview: the garment tone
      // reaches the stages, but the fill is not painted.
      final hex = recipe.palette?.garmentColour?.replaceFirst('#', '');
      final result = await CanvasRenderer(assets: _FlagResolver()).render(
        recipe,
        RenderTarget(
          width: w,
          height: h,
          background:
              hex == null ? null : ui.Color(int.parse('ff$hex', radix: 16)),
          paintBackground: false,
        ),
      );
      rw = result.image.width;
      rh = result.image.height;
      px = (await result.image.toByteData())!.buffer.asUint8List();
    });
    return (px, rw, rh);
  }

  /// Rows of the artwork that contain any opaque pixel.
  List<int> inkedRows((List<int>, int, int) img) {
    final (px, w, h) = img;
    final rows = <int>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (px[(y * w + x) * 4 + 3] > 16) {
          rows.add(y);
          break;
        }
      }
    }
    return rows;
  }

  /// Number of opaque pixels in row [y].
  int rowInk((List<int>, int, int) img, int y) {
    final (px, w, _) = img;
    var n = 0;
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] > 16) n++;
    }
    return n;
  }

  int widestRow((List<int>, int, int) img) {
    final rows = inkedRows(img);
    var best = 0;
    for (final y in rows) {
      final n = rowInk(img, y);
      if (n > best) best = n;
    }
    return best;
  }

  int opaqueCount((List<int>, int, int) img) {
    final (px, w, h) = img;
    var n = 0;
    for (var i = 0; i < w * h; i++) {
      if (px[i * 4 + 3] > 16) n++;
    }
    return n;
  }

  testWidgets('the wordmark sits above the flags', (tester) async {
    final img = await render(tester, ribbon(['us', 'fr', 'jp', 'br']));
    final rows = inkedRows(img);
    expect(rows, isNotEmpty, reason: 'the front rendered nothing at all');

    // The wordmark band and the flag grid are separate horizontal bands, and
    // the wordmark is the upper one.
    final (px, w, _) = img;
    int inkedIn(int y) {
      var n = 0;
      for (var x = 0; x < w; x++) {
        if (px[(y * w + x) * 4 + 3] > 16) n++;
      }
      return n;
    }

    final top = rows.first, bottom = rows.last;
    // The flag grid is far wider than the wordmark's letterforms.
    expect(inkedIn(bottom - (bottom - top) ~/ 8),
        greaterThan(inkedIn(top + (bottom - top) ~/ 12)),
        reason: 'the flags should be the wider band, below the wordmark');
  });

  testWidgets('an empty wordmark leaves the flags alone', (tester) async {
    // Not measured by total ink: dropping the wordmark shortens the block, so
    // the flags scale UP to fill the area and the pixel count rises. What
    // changes is the structure — the narrow band of letterforms at the top.
    final withMark = await render(tester, ribbon(['us', 'fr']));
    final without = await render(
      tester,
      ribbon(['us', 'fr'], meta: const {'frontWordmark': ''}),
    );

    final markedRows = inkedRows(withMark);
    expect(rowInk(withMark, markedRows.first),
        lessThan(widestRow(withMark) * 0.75),
        reason: 'the top band should be letterforms, narrower than the flags');

    final bareRows = inkedRows(without);
    expect(rowInk(without, bareRows.first + 1),
        greaterThan(widestRow(without) * 0.75),
        reason: 'with no wordmark the flags start at the top');
    expect(opaqueCount(without), greaterThan(0), reason: 'flags must remain');
  });

  testWidgets('a subtitle adds a line beneath the flags', (tester) async {
    final plain = await render(tester, ribbon(['us', 'fr']));
    final withSub = await render(
      tester,
      ribbon(['us', 'fr'], meta: const {'frontSubtitle': 'Globetrotter'}),
    );
    // Without one the design ends on the flags; with one it ends on a narrow
    // band of text.
    final plainRows = inkedRows(plain);
    expect(rowInk(plain, plainRows.last - 1),
        greaterThan(widestRow(plain) * 0.75));
    final subRows = inkedRows(withSub);
    expect(rowInk(withSub, subRows.last), lessThan(widestRow(withSub) * 0.75),
        reason: 'the design should end on the subtitle, not the flags');
  });

  testWidgets('a custom wordmark replaces ROAVVY', (tester) async {
    final a = await render(tester, ribbon(['us', 'fr']));
    final b = await render(
      tester,
      ribbon(['us', 'fr'], meta: const {'frontWordmark': 'WANDERLUST FOREVER'}),
    );
    expect(opaqueCount(b), isNot(opaqueCount(a)));
  });

  testWidgets('the grid fills a chest badge instead of drawing one thin row',
      (tester) async {
    // Eight countries across a portrait chest area: a single eight-wide row
    // would render a few pixels tall. It should stack instead.
    const codes = ['us', 'fr', 'jp', 'br', 'au', 'it', 'gr', 'th'];
    final chest = await render(tester, ribbon(codes), w: 120, h: 170);
    final rows = inkedRows(chest);
    final span = rows.last - rows.first;
    expect(span, greaterThan(170 * 0.25),
        reason: 'the badge should use its height, not sit in one thin band');
  });

  testWidgets('a wide front still lays the flags out broadly', (tester) async {
    const codes = ['us', 'fr', 'jp', 'br', 'au', 'it', 'gr', 'th'];
    final wide = await render(tester, ribbon(codes), w: 400, h: 120);
    final rows = inkedRows(wide);
    // A wide area gets a wide, shallow lockup — the original's proportions.
    expect(rows.last - rows.first, lessThan(120 * 0.9));
    expect(opaqueCount(wide), greaterThan(0));
  });

  testWidgets('the wordmark inks for the garment it prints on', (tester) async {
    // Dark ink on a white shirt, light ink on a black one — otherwise the
    // wordmark disappears on half the range.
    final onWhite = await render(tester, ribbon(['us'], garment: '#FFFFFF'));
    final onBlack = await render(tester, ribbon(['us'], garment: '#0E0E0E'));

    int brightestInk((List<int>, int, int) img) {
      final (px, w, _) = img;
      final rows = inkedRows(img);
      // The wordmark band: the top fifth of the INKED area, not of the canvas —
      // the block is centred, so the canvas top is empty.
      final widest = widestRow(img);
      var best = 0;
      // Only rows that are clearly letterforms, not flag tiles.
      for (final y in rows.where((y) => rowInk(img, y) < widest * 0.6)) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          if (px[i + 3] > 16 && px[i + 1] > best) best = px[i + 1];
        }
      }
      return best;
    }

    expect(brightestInk(onBlack), greaterThan(brightestInk(onWhite)),
        reason: 'the wordmark must lighten for a dark garment');
  });

  testWidgets('no countries renders nothing rather than crashing',
      (tester) async {
    final img = await render(tester, ribbon(const []));
    expect(opaqueCount(img), 0);
  });
}
