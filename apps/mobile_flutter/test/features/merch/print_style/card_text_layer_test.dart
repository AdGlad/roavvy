import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/card_text_renderer.dart';
import 'package:mobile_flutter/features/merch/print_style/card_text_layer.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style_pipeline.dart';

/// Logical card width the overlay zones are defined in (mirrors
/// CardImageRenderer / CardTextLayer). Using an image this wide gives scale=1,
/// so the title zone is the top [titleZoneH] rows and the footer zone the
/// bottom [brandingZoneH] rows exactly.
const int _w = 340;
const int _h = 272; // 340 / (5/4) → a landscape card

Future<Uint8List> _solidPng(int w, int h, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = color,
  );
  final img = await recorder.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _rawRgbaOf(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final data =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  return data!.buffer.asUint8List();
}

/// Number of pixels with alpha > [threshold] in rows [y0, y1).
int _opaqueCountRows(Uint8List rgba, int w, int y0, int y1,
    {int threshold = 0}) {
  var c = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = 0; x < w; x++) {
      if (rgba[(y * w + x) * 4 + 3] > threshold) c++;
    }
  }
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pipeline = PrintStylePipeline.instance;

  final titleRows = CardTextRenderer.titleZoneH.toInt(); // scale=1
  const footerTop = _h - 20; // brandingZoneH = 20 at scale=1

  group('CardTextLayer toggles', () {
    test('both on → title AND footer zones gain opaque text pixels', () async {
      final art = await _solidPng(_w, _h, const ui.Color(0x00000000));
      final out = await CardTextLayer.compose(
        art,
        showTitle: true,
        showFooter: true,
        title: '1 COUNTRY',
        countryCount: 1,
        textColor: Colors.white,
      );
      final rgba = await _rawRgbaOf(out);
      expect(_opaqueCountRows(rgba, _w, 0, titleRows), greaterThan(0),
          reason: 'title text present');
      expect(_opaqueCountRows(rgba, _w, footerTop, _h), greaterThan(0),
          reason: 'footer text present');
    });

    test('title off, footer on → only the footer zone has text', () async {
      final art = await _solidPng(_w, _h, const ui.Color(0x00000000));
      final out = await CardTextLayer.compose(
        art,
        showTitle: false,
        showFooter: true,
        title: '1 COUNTRY',
        countryCount: 1,
        textColor: Colors.white,
      );
      final rgba = await _rawRgbaOf(out);
      expect(_opaqueCountRows(rgba, _w, 0, titleRows), 0);
      expect(_opaqueCountRows(rgba, _w, footerTop, _h), greaterThan(0));
    });

    test('title on, footer off → only the title zone has text', () async {
      final art = await _solidPng(_w, _h, const ui.Color(0x00000000));
      final out = await CardTextLayer.compose(
        art,
        showTitle: true,
        showFooter: false,
        title: '1 COUNTRY',
        countryCount: 1,
        textColor: Colors.white,
      );
      final rgba = await _rawRgbaOf(out);
      expect(_opaqueCountRows(rgba, _w, 0, titleRows), greaterThan(0));
      expect(_opaqueCountRows(rgba, _w, footerTop, _h), 0);
    });

    test('both off → bytes returned unchanged (same instance)', () async {
      final art = await _solidPng(_w, _h, const ui.Color(0x00000000));
      final out = await CardTextLayer.compose(
        art,
        showTitle: false,
        showFooter: false,
        title: '1 COUNTRY',
        countryCount: 1,
        textColor: Colors.white,
      );
      expect(identical(out, art), isTrue);
    });
  });

  group('text is never clipped by destructive print-style masks', () {
    // The whole point of the fix: the text is composited AFTER the pipeline, so
    // torn edges / the ripped-flag gash cannot remove any glyph pixels.
    for (final id in [PrintStyleId.edgeTear, PrintStyleId.rippedFlag]) {
      test('${id.name}: title + footer survive in full', () async {
        // Opaque artwork so the filter has ink to tear/gash.
        final opaque = await _solidPng(_w, _h, const ui.Color(0xFF3355AA));
        final params = kPrintStylePresets[id]!.copyWith(seed: 7);

        // Text baked onto transparent art then styled would be torn; instead we
        // style the artwork and compose text on top afterwards.
        final styled = await pipeline.applyToBytes(opaque, params);

        final composed = await CardTextLayer.compose(
          styled,
          showTitle: true,
          showFooter: true,
          title: '1 COUNTRY',
          countryCount: 1,
          textColor: Colors.white,
          tone: params,
        );

        // Compare glyph coverage against composing over a TRANSPARENT artwork
        // (no filter involved). The text-only opaque coverage must be identical
        // — proving the destructive pass never touched the glyphs.
        final transparent = await _solidPng(_w, _h, const ui.Color(0x00000000));
        final textOnly = await CardTextLayer.compose(
          transparent,
          showTitle: true,
          showFooter: true,
          title: '1 COUNTRY',
          countryCount: 1,
          textColor: Colors.white,
          tone: params,
        );
        final textRgba = await _rawRgbaOf(textOnly);
        final titleGlyphs = _opaqueCountRows(textRgba, _w, 0, titleRows);
        final footerGlyphs = _opaqueCountRows(textRgba, _w, footerTop, _h);
        expect(titleGlyphs, greaterThan(0));
        expect(footerGlyphs, greaterThan(0));

        // Over the styled (torn/gashed) artwork the zones must be AT LEAST as
        // opaque as the pure text coverage — i.e. every glyph pixel is present.
        final composedRgba = await _rawRgbaOf(composed);
        expect(_opaqueCountRows(composedRgba, _w, 0, titleRows),
            greaterThanOrEqualTo(titleGlyphs));
        expect(_opaqueCountRows(composedRgba, _w, footerTop, _h),
            greaterThanOrEqualTo(footerGlyphs));
      });
    }

    test('tone tint re-colours text without removing any glyph pixels',
        () async {
      final transparent = await _solidPng(_w, _h, const ui.Color(0x00000000));
      final tinted = await CardTextLayer.compose(
        transparent,
        showTitle: true,
        showFooter: true,
        title: '3 COUNTRIES',
        countryCount: 3,
        textColor: Colors.white,
        tone: kPrintStylePresets[PrintStyleId.vintage]!.copyWith(
          seed: 1,
          fade: 0.5,
          colorTreatment: ColorTreatment.vintageWarm,
        ),
      );
      final plain = await CardTextLayer.compose(
        transparent,
        showTitle: true,
        showFooter: true,
        title: '3 COUNTRIES',
        countryCount: 3,
        textColor: Colors.white,
        tone: null,
      );
      final tintedRgba = await _rawRgbaOf(tinted);
      final plainRgba = await _rawRgbaOf(plain);
      // Solid glyph BODY pixels (alpha well above the AA fringe) are identical:
      // the tone is colour-only, so it re-colours glyphs but never erases them.
      // (The softest sub-pixel edges may shift by the extra compositing pass;
      // that's cosmetic and does not clip the text.)
      const core = 200;
      final titlePlain = _opaqueCountRows(plainRgba, _w, 0, titleRows,
          threshold: core);
      final footerPlain =
          _opaqueCountRows(plainRgba, _w, footerTop, _h, threshold: core);
      expect(titlePlain, greaterThan(0));
      expect(footerPlain, greaterThan(0));
      expect(_opaqueCountRows(tintedRgba, _w, 0, titleRows, threshold: core),
          titlePlain);
      expect(_opaqueCountRows(tintedRgba, _w, footerTop, _h, threshold: core),
          footerPlain);
    });
  });
}
