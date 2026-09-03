import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M4 — Vibe + Focus + Alternatives. Exercises the three new behaviours over the
/// shared [StudioController]: the 13-style Vibe picker, the deterministic
/// alternatives tray, the Focus (composition) axis, and per-axis locks + Remix.
/// The live shirt stays the hero throughout; Tier-1 + travel/Direction/Detail
/// selections persist across a Vibe change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Trip> tripsFixture() => [
    Trip(
      countryCode: 'us',
      startedOn: DateTime(2020, 6, 1),
      endedOn: DateTime(2020, 6, 8),
    ),
    Trip(
      countryCode: 'fr',
      startedOn: DateTime(2021, 3, 1),
      endedOn: DateTime(2021, 3, 9),
    ),
    Trip(
      countryCode: 'jp',
      startedOn: DateTime(2021, 8, 1),
      endedOn: DateTime(2021, 8, 5),
    ),
  ];

  StudioController controller() => buildStudioV2ControllerFor(
    DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:m4'),
  );

  Future<StudioV2ScreenState> pumpAt(
    WidgetTester tester,
    StudioController c,
    StudioStage stage,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<StudioV2ScreenState>();
    await tester.pumpWidget(
      MaterialApp(home: StudioV2Screen(key: key, controller: c)),
    );
    await tester.pump();
    await tester.tap(find.byKey(Key('v2-stage-${stage.name}')));
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('Vibe shows 13 styles; tapping one updates the live shirt + '
      'preserves Direction/Detail/Tier-1', (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.detail);

    // Pin a Detail (heart) and a garment first — these must survive a Vibe pick.
    await tester.tap(find.byKey(const Key('v2-detail-heart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-garment-Olive')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('v2-stage-vibe')));
    await tester.pump();
    expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);

    // All 13 named styles are present (some off-screen in the horizontal strip).
    for (final s in LabStyle.values) {
      expect(
        find.byKey(Key('v2-vibe-${s.name}')),
        findsOneWidget,
        reason: 'missing vibe card ${s.name}',
      );
    }

    final id0 = c.current.recipeId;
    await tester.tap(find.byKey(const Key('v2-vibe-grunge')));
    await tester.pump();
    expect(c.currentStyle, LabStyle.grunge); // committed the chosen vibe
    expect(c.current.recipeId, isNot(id0)); // live shirt updated
    // Everything else held.
    expect(c.subjectIndex, 0); // Direction = Flags
    expect(c.current.clip?.shapeId, ClipShape.heart.id); // Detail preserved
    expect(c.current.palette?.garmentColour, '#6B7350'); // garment preserved
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'}); // travel preserved
  });

  testWidgets('alternatives tray commits, offers More, and Undo reverts', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.vibe);
    await tester.pump(); // let the post-frame focusAxis populate the tray
    await tester.pump();

    expect(c.activeAxis, DesignAxis.vibe);
    expect(c.alternatives, isNotEmpty);
    expect(find.byKey(const Key('v2-alt-0')), findsOneWidget);

    final id0 = c.current.recipeId;
    await tester.tap(find.byKey(const Key('v2-alt-1')));
    await tester.pump();
    expect(c.current.recipeId, c.alternatives[1].recipeId); // committed

    // Undo (recipe history) reverts the alternative commit.
    await tester.tap(find.byKey(const Key('v2-recipe-undo')));
    await tester.pump();
    expect(c.current.recipeId, id0);

    // "More" rolls a fresh deterministic set.
    final firstSet = c.alternatives.map((r) => r.recipeId).toList();
    await tester.tap(find.byKey(const Key('v2-alt-more')));
    await tester.pump();
    expect(c.alternatives.map((r) => r.recipeId).toList(), isNot(firstSet));
  });

  testWidgets('Focus stage exposes composition alternatives that commit', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    final state = await pumpAt(tester, c, StudioStage.focus);
    await tester.pump(); // post-frame focusAxis(focus)
    await tester.pump();

    expect(state.stage, StudioStage.focus);
    expect(c.activeAxis, DesignAxis.focus);
    expect(find.byKey(const Key('v2-alt-0')), findsOneWidget);

    final id0 = c.current.recipeId;
    await tester.tap(find.byKey(const Key('v2-alt-0')));
    await tester.pump();
    expect(c.current.recipeId, isNot(id0)); // composition change committed
  });

  testWidgets(
    'locks + Remix: locking Vibe holds it while Remix rerolls the rest',
    (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await pumpAt(tester, c, StudioStage.vibe);
      await tester.pump();

      // Choose a distinctive vibe, then lock it.
      await tester.tap(find.byKey(const Key('v2-vibe-grunge')));
      await tester.pump();
      final fx0 = c.current.effects;
      await tester.tap(find.byKey(const Key('v2-lock-vibe')));
      await tester.pump();
      expect(c.locked, contains(DesignAxis.vibe));

      final id0 = c.current.recipeId;
      await tester.tap(find.byKey(const Key('v2-remix')));
      await tester.pump();
      expect(c.current.recipeId, isNot(id0)); // unlocked axes evolved
      expect(c.current.effects?.distress, fx0?.distress); // locked Vibe held
    },
  );
}
