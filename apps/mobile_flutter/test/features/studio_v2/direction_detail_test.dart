import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

/// M3 — Direction + Detail. Exercises the two new lower-workspaces over the
/// shared [StudioController], with the real bundled silhouette inventory wired in
/// via [buildStudioV2ControllerFor]. The live shirt stays the hero throughout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Trip> tripsFixture() => [
        Trip(countryCode: 'us', startedOn: DateTime(2020, 6, 1), endedOn: DateTime(2020, 6, 8)),
        Trip(countryCode: 'fr', startedOn: DateTime(2021, 3, 1), endedOn: DateTime(2021, 3, 9)),
        Trip(countryCode: 'jp', startedOn: DateTime(2021, 8, 1), endedOn: DateTime(2021, 8, 5)),
      ];

  StudioController controller() => buildStudioV2ControllerFor(
      DesignContext.fromTrips(tripsFixture(), scopeKey: 'test:m3'));

  Future<StudioV2ScreenState> pumpAt(
      WidgetTester tester, StudioController c, StudioStage stage) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<StudioV2ScreenState>();
    await tester.pumpWidget(
        MaterialApp(home: StudioV2Screen(key: key, controller: c)));
    await tester.pump();
    await tester.tap(find.byKey(Key('v2-stage-${stage.name}')));
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('Direction shows 6 subjects; Detail is Flags-only + Next skips it',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    final state = await pumpAt(tester, c, StudioStage.direction);

    // Live shirt still visible; all six Direction subjects present.
    expect(find.byKey(const Key('v2-garment-preview')), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('v2-direction-$i')), findsOneWidget);
    }
    // Flags is the default → Detail stage chip present.
    expect(c.subjectIndex, 0);
    expect(find.byKey(const Key('v2-stage-detail')), findsOneWidget);

    // Choose Milestones (index 5) → not Flags → Detail chip hidden.
    await tester.tap(find.byKey(const Key('v2-direction-5')));
    await tester.pump();
    expect(c.subjectLabel, 'Milestones');
    expect(c.detailApplies, isFalse);
    expect(find.byKey(const Key('v2-stage-detail')), findsNothing);

    // Next from Direction skips Detail → lands on Vibe.
    await tester.tap(find.byKey(const Key('v2-next')));
    await tester.pump();
    expect(state.stage, StudioStage.vibe);

    // Back to Direction and reselect Flags → Detail chip returns.
    await tester.tap(find.byKey(const Key('v2-stage-direction')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-direction-0')));
    await tester.pump();
    expect(c.detailApplies, isTrue);
    expect(find.byKey(const Key('v2-stage-detail')), findsOneWidget);
  });

  testWidgets('Flags Detail exposes 7 shapes; applyDetail changes the clip',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.detail);

    for (final name in const [
      'grid', 'map', 'animals', 'plants', 'landmarks', 'heart', 'circle'
    ]) {
      expect(find.byKey(Key('v2-detail-$name')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('v2-detail-map')));
    await tester.pump();
    expect(c.detail, StudioDetail.map);
    expect(c.current.clip?.shapeId, ClipShape.countryOutline.id);

    await tester.tap(find.byKey(const Key('v2-detail-heart')));
    await tester.pump();
    expect(c.current.clip?.shapeId, ClipShape.heart.id);
  });

  testWidgets('silhouette picker selects a specific one; it renders + persists',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    final state = await pumpAt(tester, c, StudioStage.detail);

    // Landmarks → the two bundled landmarks for us/fr/jp are Eiffel + Fuji.
    await tester.tap(find.byKey(const Key('v2-detail-landmarks')));
    await tester.pump();
    expect(find.byKey(const Key('v2-detail-silhouette-pick')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-detail-silhouette-pick')));
    await tester.pump(); // start the sheet route
    await tester.pump(const Duration(milliseconds: 400)); // finish its animation
    expect(find.text('Choose a silhouette'), findsOneWidget);
    expect(find.byKey(const Key('v2-silhouette-fr_eiffel_tower')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-silhouette-fr_eiffel_tower')));
    await tester.pump(); // start the pop
    await tester.pump(const Duration(milliseconds: 400)); // finish it
    // Sheet closed; the specific silhouette is now the design's clip.
    expect(find.text('Choose a silhouette'), findsNothing);
    expect(c.current.clip?.shapeId, ClipShape.landmarkSilhouette.id);
    expect(c.current.clip?.code, 'fr_eiffel_tower');

    // Navigate away and back — the selection is preserved.
    await tester.tap(find.byKey(const Key('v2-stage-instant')));
    await tester.pump();
    expect(state.stage, StudioStage.instant);
    await tester.tap(find.byKey(const Key('v2-stage-detail')));
    await tester.pump();
    expect(c.current.clip?.code, 'fr_eiffel_tower');
  });

  testWidgets('Direction change preserves garment + travel selection',
      (tester) async {
    final c = controller();
    addTearDown(c.dispose);
    await pumpAt(tester, c, StudioStage.direction);

    await tester.tap(find.byKey(const Key('v2-garment-Olive')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v2-direction-2'))); // Route
    await tester.pump();
    expect(c.subjectLabel, 'Route');
    expect(c.current.palette?.garmentColour, '#6B7350'); // garment survives
    expect(c.selectedCountryCodes, {'us', 'fr', 'jp'}); // travel survives
  });
}
