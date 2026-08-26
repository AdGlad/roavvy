import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/studio_canvas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canonical view of the DIRECTION axis (the clip) for byte-identity checks.
String _clip(DesignRecipe r) => jsonEncode(r.clip?.toJson());

void main() {
  // The Lab reads flag SVGs straight from the repo checkout; locate() walks up
  // from cwd (apps/design_lab) to the repo root.
  final source = FlagSource.locate();

  // Build the same generator + render service main.dart wires up, plus a
  // sensible default single-country context so the hero is a reliable flag.
  late LabShowcaseGenerator generator;
  late RenderService service;
  const context = DesignContext(flagCodes: ['us'], scopeKey: 'lab:us');

  setUp(() {
    generator = LabShowcaseGenerator(
      silhouettesByShape: {
        for (final s in ClipShape.values) s: const <String>[],
      },
      countryNames: source?.countryNames() ?? const {},
    );
    service = RenderService(source!.resolver());
  });

  Future<StudioCanvasScreenState> pumpScreen(
    WidgetTester tester,
    GlobalKey<StudioCanvasScreenState> key,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: StudioCanvasScreen(
        key: key,
        generator: generator,
        service: service,
        designContext: context,
        initialSeed: 7,
      ),
    ));
    // A couple of pumps to let the async hero image resolve (don't settle — the
    // spinner animation never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return key.currentState!;
  }

  testWidgets('(a) screen builds and shows a hero', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    expect(find.byType(StudioCanvasScreen), findsOneWidget);
    expect(find.byKey(const Key('studio-hero')), findsOneWidget);
    expect(state.currentRecipe, isNotNull);
    // All five decision-deck chips are present.
    for (final axis in DesignAxis.values) {
      expect(find.byKey(Key('studio-chip-${axis.key}')), findsOneWidget);
    }
  });

  testWidgets('(b) tapping a decision chip changes the current recipeId',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final before = state.currentRecipe.recipeId;
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.vibe.key}')));
    await tester.pump();

    expect(state.currentRecipe.recipeId, isNot(before));
    // The touched axis drives the alternatives tray.
    expect(state.activeAxis, DesignAxis.vibe);
    expect(state.alternatives, isNotEmpty);
  });

  testWidgets('(c) locking an axis then Surprise-me leaves that axis unchanged',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final clipBefore = _clip(state.currentRecipe);

    // Lock DIRECTION (owns the clip) via its lock badge (the deletable icon on
    // the chip). Long-press works in-app too, but the badge is deterministic to
    // target in a widget test.
    await tester.tap(find.descendant(
      of: find.byKey(Key('studio-chip-${DesignAxis.direction.key}')),
      matching: find.byIcon(Icons.lock_open),
    ));
    await tester.pump();
    expect(state.lockedAxes, contains(DesignAxis.direction));

    // Surprise me re-rolls everything else.
    await tester.tap(find.byKey(const Key('studio-surprise')));
    await tester.pump();

    // The locked axis's field is byte-identical…
    expect(_clip(state.currentRecipe), clipBefore);
    // …while the overall design moved on.
    expect(state.historyLength, greaterThan(0));
  });

  testWidgets('(d) undo restores the previous recipeId', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final original = state.currentRecipe.recipeId;
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.direction.key}')));
    await tester.pump();
    final afterReroll = state.currentRecipe.recipeId;
    expect(afterReroll, isNot(original));

    await tester.tap(find.byKey(const Key('studio-undo')));
    await tester.pump();

    expect(state.currentRecipe.recipeId, original);
    expect(state.historyLength, 0);
  });

  testWidgets('(e) Direction switches subject, not just re-rolls flags',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    // Cycle the Direction chip through the whole subject set.
    final families = <DesignFamily>{state.currentRecipe.composition.family};
    for (var i = 0; i < 6; i++) {
      await tester
          .tap(find.byKey(Key('studio-chip-${DesignAxis.direction.key}')));
      await tester.pump();
      families.add(state.currentRecipe.composition.family);
    }
    // Route→journeys and World→wordCloud are distinct data families, so the
    // subject genuinely changes (a plain flag re-roll would never reach them).
    expect(families.length, greaterThan(1),
        reason: 'Direction must reach different subjects');
    expect(
        families.any((f) =>
            f == DesignFamily.journeys || f == DesignFamily.wordCloud),
        isTrue,
        reason: 'Route/World subjects must be reachable via Direction');
    // The Direction tray previews one hero per subject.
    expect(state.activeAxis, DesignAxis.direction);
    expect(state.alternatives.length, greaterThan(1));
  });
}
