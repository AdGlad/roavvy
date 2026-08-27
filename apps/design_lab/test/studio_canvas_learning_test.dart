import 'package:design_forge/design_forge.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/lab_generator.dart';
import 'package:design_lab/render_service.dart';
import 'package:design_lab/studio_canvas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// M4 — the Studio Canvas feeds the shared preference-learning system as the
/// customer authors (docs/product/tshirt-creation-experience.md §19). These
/// tests assert that the authoring actions emit the right [PreferenceSignal]s
/// and update the reproducible [PersistentDesignLibrary].

/// A trivial in-memory [DesignStore] so the library persists without touching
/// disk during the test.
class _MemoryStore implements DesignStore {
  String? _data;
  @override
  Future<String?> read() async => _data;
  @override
  Future<void> write(String contents) async => _data = contents;
}

void main() {
  final source = FlagSource.locate();

  late LabShowcaseGenerator generator;
  late RenderService service;
  late PersistentDesignLibrary library;
  const context = DesignContext(flagCodes: ['us'], scopeKey: 'lab:us');

  setUp(() {
    generator = LabShowcaseGenerator(
      silhouettesByShape: {
        for (final s in ClipShape.values) s: const <String>[],
      },
      countryNames: source?.countryNames() ?? const {},
    );
    service = RenderService(source!.resolver());
    library = PersistentDesignLibrary(_MemoryStore());
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
        library: library,
      ),
    ));
    // Let the async hero image resolve and the post-frame "viewed" signal fire
    // (don't settle — the spinner animation never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return key.currentState!;
  }

  testWidgets('(a) the initial hero emits a viewed signal', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);
    // The post-frame "viewed" signal has been folded in by now.
    expect(state.currentPreferences.sampleCount, greaterThan(0));
  });

  testWidgets('(b) committing a decision updates preferences', (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final before = state.currentPreferences.sampleCount;
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.vibe.key}')));
    await tester.pump();

    // A styleChosen signal was folded in on top of the initial viewed.
    expect(state.currentPreferences.sampleCount, greaterThan(before));
  });

  testWidgets('(c) ♥ Save records a saved signal and a library like',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    final saved = state.currentRecipe;
    final before = state.currentPreferences.sampleCount;

    expect(library.library.isLiked(saved.recipeId), isFalse);
    await tester.tap(find.byKey(const Key('studio-save')));
    await tester.pump();

    expect(state.currentPreferences.sampleCount, greaterThan(before));
    expect(library.library.isLiked(saved.recipeId), isTrue);
  });

  testWidgets('(d) a tray dismiss records a rejected signal + library reject',
      (tester) async {
    final key = GlobalKey<StudioCanvasScreenState>();
    final state = await pumpScreen(tester, key);

    // Populate the generic alternatives tray by touching an axis. (Vibe now uses
    // a named style tray without per-tile dismiss, so use Focus for the reject
    // affordance.)
    await tester.tap(find.byKey(Key('studio-chip-${DesignAxis.focus.key}')));
    await tester.pump();
    expect(state.alternatives, isNotEmpty);

    final rejected = state.alternatives.first;
    final beforeCount = state.currentPreferences.sampleCount;
    final beforeAlts = state.alternatives.length;

    await tester.tap(find.byKey(const Key('studio-alt-dismiss-0')));
    await tester.pump();

    expect(state.currentPreferences.sampleCount, greaterThan(beforeCount));
    expect(library.library.isRejected(rejected.recipeId), isTrue);
    // The dismissed tile is dropped from the strip.
    expect(state.alternatives.length, beforeAlts - 1);
  });
}
