import 'package:design_studio/design_studio.dart';
import 'package:design_studio/garment_mockup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrintZone', () {
    test('every zone sits inside the 12"×16" print file and its photo', () {
      const file = Rect.fromLTWH(0, 0, 12, 16);
      const photo = Rect.fromLTWH(0, 0, 1, 1);
      for (final z in PrintZone.values) {
        for (final s in [z.minScale, 0.8, 1.0]) {
          final a = z.areaInches(s);
          expect(file.intersect(a), a, reason: '${z.name}@$s inches');
          final m = z.mockupRectAt(s);
          expect(photo.intersect(m), m, reason: '${z.name}@$s mockup');
        }
      }
    });

    test('chest zones are the M167 3.5" logo the order pipeline prints', () {
      expect(PrintZone.leftChest.inches, const Rect.fromLTWH(8.25, 3, 3.5, 3.5));
      expect(PrintZone.rightChest.inches, const Rect.fromLTWH(0.25, 3, 3.5, 3.5));
      expect(PrintZone.leftChest.sizeLabel(), '3.5″ × 3.5″');
      expect(PrintZone.fullBack.sizeLabel(), '12″ × 16″');
    });

    test('shipped zones keep their calibrated photo rects', () {
      expect(PrintZone.fullFront.mockupRect, BundledGarments.frontCenterArea);
      expect(PrintZone.leftChest.mockupRect, BundledGarments.frontLeftChestArea);
      expect(PrintZone.fullBack.mockupRect, BundledGarments.backPrintArea);
    });

    test('derived back zones keep their print shape on the photo', () {
      const photo = BundledGarments.tintBaseBackSize;
      for (final z in [PrintZone.upperBack, PrintZone.backNeck]) {
        final m = z.mockupRect;
        final photoAspect = m.width * photo.width / (m.height * photo.height);
        expect(photoAspect, closeTo(z.inches.width / z.inches.height, 1e-9));
        expect(m.top, greaterThan(BundledGarments.backPrintArea.top));
      }
    });

    test('a smaller size hangs from the same top line, centred', () {
      final full = PrintZone.fullBack.areaInches();
      final half = PrintZone.fullBack.areaInches(0.5);
      expect(half.top, full.top);
      expect(half.center.dx, full.center.dx);
      expect(half.width, 6);
      // Clamped to the zone's minimum.
      expect(PrintZone.leftChest.areaInches(0.1).width, closeTo(3.5 * 0.7, 1e-9));
    });

    test('each zone maps to a placement on its own face', () {
      for (final z in PrintZone.values) {
        expect(z.placement.side, z.side, reason: z.name);
      }
      expect(PrintZone.values.map((z) => z.placement).toSet().length,
          PrintZone.values.length);
    });
  });

  group('PrintLayout', () {
    test('presets are recognised, sizes aside', () {
      for (final p in PrintLayoutPreset.values) {
        expect(p.layout.preset, p);
        final side = p.backZone != null ? PrintSide.back : PrintSide.front;
        expect(p.layout.withScale(side, 0.8).preset, p);
      }
      const custom = PrintLayout(
        front: ZonePrint(PrintZone.rightChest),
        back: ZonePrint(PrintZone.upperBack),
      );
      expect(custom.preset, isNull);
      expect(custom.summary, 'Right chest + Upper back');
    });

    test('round-trips through JSON', () {
      final layouts = [
        for (final p in PrintLayoutPreset.values) p.layout,
        const PrintLayout(
          front: ZonePrint(PrintZone.leftChest, scale: 0.85),
          back: ZonePrint(PrintZone.backNeck),
        ),
      ];
      for (final l in layouts) {
        expect(PrintLayout.fromJson(l.toJson()), l);
      }
      expect(PrintLayout.standard.toJson(), {
        'back': {'zone': 'fullBack'},
      });
    });

    test('unreadable JSON falls back to the standard full back', () {
      expect(PrintLayout.fromJson(null), PrintLayout.standard);
      expect(PrintLayout.fromJson(const {}), PrintLayout.standard);
      expect(PrintLayout.fromJson({'back': {'zone': 'sleeve'}}), PrintLayout.standard);
      // A front zone on the back is ignored, not misprinted.
      expect(
        PrintLayout.fromJson({
          'front': {'zone': 'fullBack'},
          'back': {'zone': 'upperBack'},
        }),
        const PrintLayout(back: ZonePrint(PrintZone.upperBack)),
      );
    });

    test('the last printed face cannot be cleared', () {
      const back = PrintLayout.standard;
      expect(back.withZone(PrintSide.back, null), back);
      final both = back.withZone(PrintSide.front, PrintZone.leftChest);
      expect(both.withZone(PrintSide.back, null),
          const PrintLayout(front: ZonePrint(PrintZone.leftChest)));
    });

    test('changing zone resets the size; keeping it keeps the size', () {
      final l = PrintLayout.standard.withScale(PrintSide.back, 0.7);
      expect(l.withZone(PrintSide.back, PrintZone.fullBack).back!.scale, 0.7);
      expect(l.withZone(PrintSide.back, PrintZone.upperBack).back!.scale, 1);
    });
  });

  group('the Roavvy mark', () {
    test('prints only with a back design, and not over a back-neck design', () {
      expect(PrintLayout.standard.printsMark, isTrue);
      expect(PrintLayoutPreset.crest.layout.printsMark, isFalse);
      expect(PrintLayoutPreset.crest.layout.markBlockedReason,
          'Prints only with a back design');
      expect(PrintLayoutPreset.frontAndNeck.layout.printsMark, isFalse);
      expect(PrintLayoutPreset.frontAndNeck.layout.markBlockedReason,
          'The design is using the back neck');
      final off = PrintLayout.standard.withBrandMark(false);
      expect(off.printsMark, isFalse);
      expect(off.markBlockedReason, isNull);
    });

    test('pushes the back design below it; the front is untouched', () {
      final l = PrintLayoutPreset.crestAndBack.layout;
      final back = l.areaInches(PrintSide.back)!;
      expect(back.top, PrintLayout.markClearInches);
      expect(back.bottom, 16);
      expect(back.width, 12);
      expect(PrintLayout.markInches.bottom, lessThan(back.top));
      expect(l.areaInches(PrintSide.front), PrintZone.leftChest.inches);
      // Without the mark the zone is exactly the zone.
      expect(l.withBrandMark(false).areaInches(PrintSide.back),
          PrintZone.fullBack.inches);
      // …and on the photo the design moves down by the same inches.
      final m = l.mockupRect(PrintSide.back)!;
      expect(m.top, greaterThan(BundledGarments.backPrintArea.top));
      expect(m.bottom, closeTo(BundledGarments.backPrintArea.bottom, 1e-9));
      expect(PrintLayout.markMockupRect.bottom, lessThan(m.top));
    });

    test('is saved only when switched off, and survives presets and edits', () {
      expect(PrintLayout.standard.toJson().containsKey('mark'), isFalse);
      final off = PrintLayout.standard.withBrandMark(false);
      expect(off.toJson()['mark'], false);
      expect(PrintLayout.fromJson(off.toJson()), off);
      expect(PrintLayout.fromJson(const {'mark': false}), off);
      expect(off.withZone(PrintSide.front, PrintZone.leftChest).brandMark, isFalse);
      expect(off.withScale(PrintSide.back, 0.8).brandMark, isFalse);
      expect(PrintLayoutPreset.frontAndBack.applyTo(off).brandMark, isFalse);
      expect(off.preset, PrintLayoutPreset.back);
    });

    test('ink is legible on the shirt', () {
      expect(BrandMark.inkFor(const Color(0xFF0E0E0E)), const Color(0xFFF2F2F2));
      expect(BrandMark.inkFor(const Color(0xFFFFFFFF)), const Color(0xFF1C1C1C));
    });

    test('a print spec refuses a mark over the artwork', () {
      expect(
        () => ProductionRenderSpec(
          placement: PrintPlacement.backFull,
          canvasWidthPx: 1800,
          canvasHeightPx: 2400,
          dpi: 150,
          artworkArea: const Rect.fromLTWH(0, 0, 1800, 2400),
          marks: const [
            PrintMark(rect: Rect.fromLTWH(700, 60, 400, 90), ink: Color(0xFFFFFFFF)),
          ],
        ),
        throwsA(isA<ProductionRenderException>()),
      );
    });
  });

  group('PrintLayoutControls', () {
    Future<List<PrintLayout>> pump(
      WidgetTester tester,
      PrintLayout layout,
      List<PrintSide> focus,
    ) async {
      final changes = <PrintLayout>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrintLayoutControls(
                layout: layout,
                onChanged: changes.add,
                onFocus: focus.add,
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('a preset sets both faces and turns the preview', (t) async {
      final focus = <PrintSide>[];
      final changes = await pump(t, PrintLayout.standard, focus);
      await t.tap(find.byKey(const Key('layout-preset-crestAndBack')));
      expect(changes.single, PrintLayoutPreset.crestAndBack.layout);
      expect(focus.single, PrintSide.back);
    });

    testWidgets('a zone chip changes one face and focuses it', (t) async {
      final focus = <PrintSide>[];
      final changes = await pump(t, PrintLayout.standard, focus);
      await t.tap(find.byKey(const Key('layout-zone-front-rightChest')));
      expect(changes.single.front!.zone, PrintZone.rightChest);
      expect(changes.single.back, PrintLayout.standard.back);
      expect(focus.single, PrintSide.front);
    });

    testWidgets('shows the size in inches, and only for printed faces', (t) async {
      await pump(t, PrintLayoutPreset.crestAndBack.layout, []);
      expect(find.text('3.5″ × 3.5″'), findsOneWidget);
      // The full back, below the Roavvy mark's clearance…
      expect(find.text('12″ × 14.5″'), findsOneWidget);
      // …and the whole area with the mark off.
      await pump(t, PrintLayoutPreset.crestAndBack.layout.withBrandMark(false), []);
      expect(find.text('12″ × 16″'), findsOneWidget);
      await pump(t, PrintLayout.standard, []);
      expect(find.byKey(const Key('layout-size-front')), findsNothing);
      expect(find.byKey(const Key('layout-size-back')), findsOneWidget);
      // The only printed face offers no "None".
      final none = t.widget<ChoiceChip>(
        find.byKey(const Key('layout-zone-back-none')),
      );
      expect(none.onSelected, isNull);
    });

    testWidgets('the mark switch toggles the mark and says when it cannot print', (t) async {
      final changes = await pump(t, PrintLayout.standard, []);
      expect(find.text('roavvy.com, small, below the collar'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('layout-mark')));
      await t.tap(find.byKey(const Key('layout-mark')));
      expect(changes.single.brandMark, isFalse);
      await pump(t, PrintLayoutPreset.crest.layout, []);
      expect(find.text('Prints only with a back design'), findsOneWidget);
    });
  });
}
