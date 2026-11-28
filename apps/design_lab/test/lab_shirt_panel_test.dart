import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_shirt_panel.dart';
import 'package:design_studio/design_studio.dart';
import 'package:design_studio/garment_mockup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Lab's shirt panel renders a design onto the app's own garment mockup,
/// with the photos read from the mobile app's assets on disk.
void main() {
  testWidgets('shirt panel prints the design onto the shirt', (tester) async {
    final source = FlagSource.locate()!;
    LabShirtPanel.useMobileAssets(source.dir.parent.parent);
    final service = RenderService(source.resolver());
    final recipe = portraitTornFlagRecipe(flagCode: 'us', seed: 1);
    final boundary = GlobalKey();

    tester.view.physicalSize = const Size(380, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: RepaintBoundary(
          key: boundary,
          child: LabShirtPanel(service: service, recipe: recipe),
        ),
      ),
    ));

    // Render, recolour, luminance map and the fabric bake are all async (the
    // bake is slow under the test's JIT; ~0.2 s in a release build).
    final canvas = find.byType(GarmentMockupCanvas);
    bool baked() =>
        canvas.evaluate().isNotEmpty &&
        tester.widget<GarmentMockupCanvas>(canvas).shadingImage == null;
    for (var i = 0; i < 600 && !baked(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(canvas, findsOneWidget, reason: 'the shirt (not the flat design) is shown');
    final mockup = tester.widget<GarmentMockupCanvas>(canvas);
    expect(mockup.shadingImage, isNull,
        reason: 'the FabricPrint bake replaced the live shading pass');

    final out = Platform.environment['LAB_SHIRT_PNG'];
    if (out != null) {
      await tester.runAsync(() async {
        final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await ro.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(out).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });

  testWidgets('the panel edits the print layout with the app\'s controls', (tester) async {
    final source = FlagSource.locate()!;
    LabShirtPanel.useMobileAssets(source.dir.parent.parent);
    final service = RenderService(source.resolver());
    final recipe = portraitTornFlagRecipe(flagCode: 'us', seed: 1);
    tester.view.physicalSize = const Size(380, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var layout = PrintLayout.standard;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => LabShirtPanel(
            service: service,
            recipe: recipe,
            layout: layout,
            onLayoutChanged: (l) => setState(() => layout = l),
          ),
        ),
      ),
    ));
    expect(find.byType(PrintLayoutControls), findsOneWidget);
    expect(find.byKey(const Key('tee-face-back')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('layout-preset-front')));
    await tester.tap(find.byKey(const Key('layout-preset-front')));
    await tester.pump();
    expect(layout, PrintLayoutPreset.front.layout);
    // The back no longer prints, so the panel turned to the front.
    expect(find.byKey(const Key('tee-face-front')), findsOneWidget);
    expect(find.byKey(const Key('tee-guide-front')), findsOneWidget);
  });

  testWidgets('without an editor the panel has no layout controls', (tester) async {
    final source = FlagSource.locate()!;
    final service = RenderService(source.resolver());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LabShirtPanel(service: service, recipe: null),
      ),
    ));
    expect(find.byType(PrintLayoutControls), findsNothing);
    expect(find.byType(TeeViewSwitcher), findsOneWidget);
  });
}
