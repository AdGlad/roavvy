import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

void main() {
  group('new recipe fields (copies/stampMode/statementHero/sizeClass/effects)', () {
    test('Composition new fields round-trip and default cleanly', () {
      const c = Composition(
        family: DesignFamily.grid,
        copiesPerCountry: 3,
        statementHero: true,
        sizeClass: SizeClass.large,
      );
      final back = Composition.fromJson(c.toJson());
      expect(back.copiesPerCountry, 3);
      expect(back.statementHero, isTrue);
      expect(back.sizeClass, SizeClass.large);

      // Defaults are omitted so existing recipes hash identically.
      const def = Composition(family: DesignFamily.grid);
      final j = def.toJson();
      expect(j.containsKey('copiesPerCountry'), isFalse);
      expect(j.containsKey('statementHero'), isFalse);
      expect(j.containsKey('sizeClass'), isFalse);
      expect(def.copiesPerCountry, 1);
      expect(def.statementHero, isFalse);
      expect(def.sizeClass, SizeClass.medium);
    });

    test('SizeClass maps to an artwork scale', () {
      expect(SizeClass.small.scale, lessThan(SizeClass.medium.scale));
      expect(SizeClass.medium.scale, lessThan(SizeClass.large.scale));
      expect(SizeClass.large.scale, 1.0);
      expect(SizeClass.fromId('small'), SizeClass.small);
      expect(SizeClass.fromId('bogus'), SizeClass.medium);
    });

    test('Clip.stampMode round-trips and omits at default', () {
      const clip = Clip(shapeId: 'passportPage', stampMode: 'entryOnly');
      expect(Clip.fromJson(clip.toJson()).stampMode, 'entryOnly');
      expect(const Clip(shapeId: 'circle').toJson().containsKey('stampMode'),
          isFalse);
    });

    test('Effects ports round-trip, gate isIdentity, omit at default', () {
      const fx = Effects(riso: 0.8, newsprint: 0.5, sunFaded: 0.3, photocopy: 0.6);
      final back = Effects.fromJson(fx.toJson());
      expect(back.riso, 0.8);
      expect(back.newsprint, 0.5);
      expect(back.sunFaded, 0.3);
      expect(back.photocopy, 0.6);
      expect(fx.isIdentity, isFalse);
      expect(const Effects(riso: 0.4).isIdentity, isFalse);
      expect(const Effects().isIdentity, isTrue);
      expect(const Effects().toJson().containsKey('riso'), isFalse);
    });
  });
}
