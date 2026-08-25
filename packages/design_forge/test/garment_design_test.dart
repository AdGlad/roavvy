import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _front() => DesignRecipe(
      seed: 123,
      content: const RecipeContent(
        flags: [FlagRef('jp', weight: 2.0), FlagRef('fr')],
        source: 'thisYear',
      ),
      composition: const Composition(family: DesignFamily.duoBlend),
      palette: const Palette(garmentColour: '#101010', accents: ['#ffcc00']),
    );

DesignRecipe _back() => DesignRecipe(
      seed: 999,
      content: const RecipeContent(flags: [FlagRef('it')]),
      composition: const Composition(family: DesignFamily.grid),
      palette: const Palette(garmentColour: '#101010'),
    );

GarmentDesign _roundTrip(GarmentDesign g) => GarmentDesign.fromJson(
    jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>);

void main() {
  group('GarmentDesign JSON round-trip', () {
    test('front + back', () {
      final g = GarmentDesign(
        front: _front(),
        back: _back(),
        garmentColour: '#101010',
        variant: 'L',
        themeSeed: 42,
      );
      final d = _roundTrip(g);
      expect(d.front!.recipeId, g.front!.recipeId);
      expect(d.back!.recipeId, g.back!.recipeId);
      expect(d.garmentColour, '#101010');
      expect(d.variant, 'L');
      expect(d.themeSeed, 42);
      expect(d.garmentId, g.garmentId);
      expect(d, g);
    });

    test('front-only', () {
      final g = GarmentDesign(front: _front(), themeSeed: 7);
      final d = _roundTrip(g);
      expect(d.front!.recipeId, g.front!.recipeId);
      expect(d.back, isNull);
      expect(d.garmentId, g.garmentId);
      expect(d, g);
    });

    test('back-only', () {
      final g = GarmentDesign(back: _back(), themeSeed: 7);
      final d = _roundTrip(g);
      expect(d.front, isNull);
      expect(d.back!.recipeId, g.back!.recipeId);
      expect(d.garmentId, g.garmentId);
      expect(d, g);
    });
  });

  group('garmentId', () {
    test('is stable / reproducible for identical inputs', () {
      final a = GarmentDesign(
          front: _front(), back: _back(), garmentColour: '#111', themeSeed: 5);
      final b = GarmentDesign(
          front: _front(), back: _back(), garmentColour: '#111', themeSeed: 5);
      expect(a.garmentId, b.garmentId);
    });

    test('changes when a side changes', () {
      final a = GarmentDesign(front: _front(), back: _back(), themeSeed: 5);
      final b = a.copyWith(back: _back().copyWith(seed: 1000));
      expect(b.garmentId, isNot(a.garmentId));
    });

    test('changes when garment colour changes', () {
      final a = GarmentDesign(front: _front(), garmentColour: '#000');
      final b = a.copyWith(garmentColour: '#fff');
      expect(b.garmentId, isNot(a.garmentId));
    });

    test('changes when variant or themeSeed changes', () {
      final a = GarmentDesign(front: _front(), variant: 'S', themeSeed: 1);
      expect(a.copyWith(variant: 'M').garmentId, isNot(a.garmentId));
      expect(a.copyWith(themeSeed: 2).garmentId, isNot(a.garmentId));
    });
  });

  group('coherence helpers', () {
    test('withSharedTheme derives a back sharing themeSeed + garmentColour', () {
      final g = GarmentDesign.withSharedTheme(
        front: _front(),
        themeSeed: 77,
        garmentColour: '#222222',
        variant: 'M',
      );
      expect(g.front, isNotNull);
      expect(g.back, isNotNull);
      expect(g.themeSeed, 77);
      expect(g.garmentColour, '#222222');
      // Both faces carry the shared garment colour.
      expect(g.front!.palette!.garmentColour, '#222222');
      expect(g.back!.palette!.garmentColour, '#222222');
      // Back shares the front's palette accents (vibe intent) …
      expect(g.back!.palette!.accents, g.front!.palette!.accents);
      // … but draws with a distinct seed derived from the theme seed.
      expect(g.back!.seed, GarmentDesign.backSeedFromTheme(77));
      expect(g.back!.seed, isNot(g.front!.seed));
    });

    test('withSharedTheme falls back to the front recipe garment colour', () {
      final g = GarmentDesign.withSharedTheme(front: _front(), themeSeed: 3);
      expect(g.garmentColour, '#101010');
      expect(g.back!.palette!.garmentColour, '#101010');
    });

    test('deriveBack keeps content + palette, distinct seed', () {
      final front = _front();
      final back =
          GarmentDesign.deriveBack(front, themeSeed: 9, garmentColour: '#abc');
      expect(back.content.flags, front.content.flags);
      expect(back.palette!.garmentColour, '#abc');
      expect(back.seed, GarmentDesign.backSeedFromTheme(9));
      expect(back.seed, isNot(front.seed));
    });

    test('withGarmentColour updates both sides and the shared field', () {
      final g = GarmentDesign(
        front: _front(),
        back: _back(),
        garmentColour: '#101010',
        themeSeed: 1,
      );
      final r = g.withGarmentColour('#ff0000');
      expect(r.garmentColour, '#ff0000');
      expect(r.front!.palette!.garmentColour, '#ff0000');
      expect(r.back!.palette!.garmentColour, '#ff0000');
      // Pure: original is unchanged.
      expect(g.front!.palette!.garmentColour, '#101010');
      // Other palette fields are preserved.
      expect(r.front!.palette!.accents, g.front!.palette!.accents);
    });

    test('flipSides swaps front and back', () {
      final g = GarmentDesign(
          front: _front(), back: _back(), garmentColour: '#111', themeSeed: 8);
      final f = g.flipSides();
      expect(f.front!.recipeId, g.back!.recipeId);
      expect(f.back!.recipeId, g.front!.recipeId);
      expect(f.garmentColour, '#111');
      expect(f.themeSeed, 8);
    });
  });
}
