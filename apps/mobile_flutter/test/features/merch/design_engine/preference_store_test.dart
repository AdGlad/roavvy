import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/preference_store.dart';
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

class _FakeStore implements PreferenceStore {
  UserDesignPreferenceProfile saved = UserDesignPreferenceProfile.neutral;
  int saves = 0;
  @override
  Future<UserDesignPreferenceProfile> load() async => saved;
  @override
  Future<void> save(UserDesignPreferenceProfile p) async {
    saved = p;
    saves++;
  }
}

void main() {
  const gen = ProceduralDesignGenerator();
  final ctx = DesignContext.of(
    scope: DesignScope.multiCountry,
    countryCodes: const ['fr', 'jp', 'us'],
  );
  final recipe = gen.generate(ctx, seed: 3).designs.first.recipe;

  test('recording a signal updates state and persists', () async {
    final store = _FakeStore();
    final notifier = PreferenceProfileNotifier(store);
    // starts neutral
    expect(const PreferenceScorer().score(recipe, notifier.state),
        closeTo(0.5, 1e-9));

    notifier.record(recipe, PreferenceSignal.saved);

    expect(const PreferenceScorer().score(recipe, notifier.state),
        greaterThan(0.5));
    expect(store.saves, 1);
    expect(store.saved.sampleCount, 1);
  });

  test('loads persisted profile on construction', () async {
    final store = _FakeStore();
    // pre-seed a profile that likes this recipe.
    var seeded = UserDesignPreferenceProfile.neutral;
    for (var i = 0; i < 3; i++) {
      seeded = const PreferenceLearner()
          .observe(seeded, recipe, PreferenceSignal.selectedForMockup);
    }
    store.saved = seeded;

    final notifier = PreferenceProfileNotifier(store);
    await Future<void>.delayed(Duration.zero); // let _load() run
    expect(notifier.state.sampleCount, 3);
    expect(const PreferenceScorer().score(recipe, notifier.state),
        greaterThan(0.5));
  });
}
