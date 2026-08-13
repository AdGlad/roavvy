// Auto-design re-config keeps the STYLE recipe.
//
// When an Auto design (ProceduralDesignScreen) is opened in the T-shirt preview
// (LocalMockupPreviewScreen) with an `autoStyleParams` intent, EVERY artwork
// render must re-apply that recipe's print-style filter to a text-free base and
// then composite the title/footer on top — so changing orientation / flag count
// / colour / title never reverts the design to the plain template.
//
// The preview routes every re-render through the same pure helper
// [styleAutoDesignArtwork] (via _afterArtworkCommitted → _restyleAuto), and the
// recipe's [PrintStyleParams] are held immutably on the widget, so proving the
// helper applies the style proves re-config keeps it. Merged/GPU designs are the
// only ones that stay locked (fixedArtwork) and carry NO autoStyleParams.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/local_mockup_preview_screen.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:shared_models/shared_models.dart';

// Match CardTextLayer's logical width so the title zone maps to the top rows.
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

Future<Uint8List> _rawRgba(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  return data!.buffer.asUint8List();
}

int _opaqueCount(Uint8List rgba) {
  var c = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 250) c++;
  }
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('styleAutoDesignArtwork — re-render applies the style recipe', () {
    test('a non-clean filter (grunge) transforms the artwork', () async {
      final clean = await _solidPng(_w, _h, const ui.Color(0xFFFFFFFF));
      final grunge = kPrintStylePresets[PrintStyleId.grunge]!;

      final styled = await styleAutoDesignArtwork(
        clean,
        params: grunge,
        showTitle: false,
        showFooter: false,
        title: '2 Countries',
        countryCount: 2,
        textColor: Colors.white,
      );

      // Grunge distress makes some ink pixels transparent, so the fully-opaque
      // pixel count must drop — the filter demonstrably ran on the re-render.
      final before = _opaqueCount(await _rawRgba(clean));
      final after = _opaqueCount(await _rawRgba(styled));
      expect(after, lessThan(before),
          reason: 'grunge should erode a solid fill');
    });

    test('clean filter + both toggles off is a byte-perfect pass-through',
        () async {
      final clean = await _solidPng(_w, _h, const ui.Color(0xFFFFFFFF));
      final out = await styleAutoDesignArtwork(
        clean,
        params: const PrintStyleParams(id: PrintStyleId.clean),
        showTitle: false,
        showFooter: false,
        title: '1 Country',
        countryCount: 1,
        textColor: Colors.white,
      );
      // Same instance returned — the untouched/normal path stays free.
      expect(identical(out, clean), isTrue);
    });

    test('title toggle composites text even under a clean filter', () async {
      // Transparent base so any opaque pixel afterwards is the composited text.
      final clean = await _solidPng(_w, _h, const ui.Color(0x00000000));
      final out = await styleAutoDesignArtwork(
        clean,
        params: const PrintStyleParams(id: PrintStyleId.clean),
        showTitle: true,
        showFooter: false,
        title: '3 Countries',
        countryCount: 3,
        textColor: Colors.white,
      );
      expect(_opaqueCount(await _rawRgba(out)), greaterThan(0),
          reason: 'the title layer should draw legible glyphs on top');
    });
  });

  group('LocalMockupPreviewScreen — auto-style vs merged wiring', () {
    test('card-rendered auto design carries style intent and is NOT fixed', () {
      final w = LocalMockupPreviewScreen(
        selectedCodes: const ['GB', 'FR'],
        allCodes: const ['GB', 'FR'],
        trips: const [],
        artworkImageBytes: Uint8List(0),
        autoStyleParams: kPrintStylePresets[PrintStyleId.edgeTear]!,
        autoShowTitle: true,
        autoShowFooter: false,
        initialTemplate: CardTemplateType.grid,
      );
      // Style recipe is retained (so every re-render can re-apply it) …
      expect(w.autoStyleParams, isNotNull);
      expect(w.autoStyleParams!.id, PrintStyleId.edgeTear);
      expect(w.autoShowTitle, isTrue);
      expect(w.autoShowFooter, isFalse);
      // … and the artwork is NOT locked, so re-config can regenerate it.
      expect(w.fixedArtwork, isFalse);
    });

    test('merged/GPU design stays fixed and carries NO auto style', () {
      final w = LocalMockupPreviewScreen(
        selectedCodes: const ['GB', 'FR'],
        allCodes: const ['GB', 'FR'],
        trips: const [],
        artworkImageBytes: Uint8List(0),
        fixedArtwork: true, // merged shaders can't be re-rendered by the card
        initialTemplate: CardTemplateType.grid,
      );
      expect(w.fixedArtwork, isTrue);
      expect(w.autoStyleParams, isNull);
    });
  });
}
