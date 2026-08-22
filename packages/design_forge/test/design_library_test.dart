import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _recipe(int seed) => DesignRecipe(
      seed: seed,
      content: const RecipeContent(flags: [FlagRef('sc')]),
      composition: const Composition(family: DesignFamily.singleHero),
    );

/// In-memory store for testing PersistentDesignLibrary.
class _MemStore implements DesignStore {
  String? _data;
  @override
  Future<String?> read() async => _data;
  @override
  Future<void> write(String contents) async => _data = contents;
}

void main() {
  group('DesignLibrary', () {
    test('like stores the full recipe and reproduces it', () {
      final lib = DesignLibrary();
      final r = _recipe(1);
      lib.like(r, nowMs: 1000);
      expect(lib.isLiked(r.recipeId), isTrue);
      // Round-trip through JSON → the recipe is fully recoverable (reproducible).
      final restored = DesignLibrary.decode(lib.encode());
      final saved = restored.get(r.recipeId)!;
      expect(saved.recipe.recipeId, r.recipeId);
      expect(saved.recipe.toJson(), r.toJson());
    });

    test('un-liking an unused design drops it (no batch accumulation)', () {
      final lib = DesignLibrary();
      final r = _recipe(2);
      lib.like(r, nowMs: 1);
      expect(lib.length, 1);
      lib.unlike(r.recipeId);
      expect(lib.length, 0);
    });

    test('used-for-tshirt is kept even when not liked', () {
      final lib = DesignLibrary();
      final r = _recipe(3);
      lib.setUsedForTshirt(r, true, nowMs: 5);
      expect(lib.isUsedForTshirt(r.recipeId), isTrue);
      expect(lib.isLiked(r.recipeId), isFalse);
      // Un-liking (which it never had) must not remove a t-shirt design.
      lib.unlike(r.recipeId);
      expect(lib.contains(r.recipeId), isTrue);
      // Unmarking t-shirt while unliked drops it.
      lib.setUsedForTshirt(r, false, nowMs: 6);
      expect(lib.contains(r.recipeId), isFalse);
    });

    test('liked and usedForTshirt lists filter correctly', () {
      final lib = DesignLibrary();
      lib.like(_recipe(1), nowMs: 10);
      lib.like(_recipe(2), nowMs: 20);
      lib.setUsedForTshirt(_recipe(2), true, nowMs: 30);
      lib.setUsedForTshirt(_recipe(3), true, nowMs: 40);
      expect(lib.liked.length, 2);
      expect(lib.usedForTshirt.length, 2);
      expect(lib.entries.length, 3);
    });

    test('toggleLike flips state', () {
      final lib = DesignLibrary();
      final r = _recipe(7);
      expect(lib.toggleLike(r, nowMs: 1), isTrue);
      expect(lib.isLiked(r.recipeId), isTrue);
      expect(lib.toggleLike(r, nowMs: 2), isFalse);
      expect(lib.contains(r.recipeId), isFalse);
    });
  });

  group('PersistentDesignLibrary', () {
    test('persists across reload via the store', () async {
      final store = _MemStore();
      final p1 = PersistentDesignLibrary(store);
      await p1.load();
      final r = _recipe(9);
      await p1.toggleLike(r, nowMs: 100);
      await p1.setUsedForTshirt(r, true, nowMs: 110);

      final p2 = PersistentDesignLibrary(store)..library;
      await p2.load();
      expect(p2.library.isLiked(r.recipeId), isTrue);
      expect(p2.library.isUsedForTshirt(r.recipeId), isTrue);
      expect(p2.library.get(r.recipeId)!.recipe.toJson(), r.toJson());
    });

    test('decode tolerates empty/garbage', () {
      expect(DesignLibrary.decode(null).length, 0);
      expect(DesignLibrary.decode('').length, 0);
      expect(DesignLibrary.decode('not json').length, 0);
    });
  });
}
