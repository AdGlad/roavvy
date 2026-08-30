import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/host/bundle_asset_resolver.dart';
import 'package:mobile_flutter/features/studio_v2/host/passport_stamp_inventory.g.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Passport asset integration on mobile. The app bundles the real entry/exit
/// stamp artwork (`assets/mobile_png/` + `assets/mobile_meta/`), but Studio V2
/// shipped without exposing it: the generator saw no `passportStampOutline`
/// inventory and the bundle resolver had no stamp lookup, so the Passport
/// direction had no available subjects and rendered as an ordinary flag design.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the generated stamp inventory matches the bundled manifest', () async {
    final raw = await rootBundle.loadString(
      'assets/mobile_meta/stamp_manifest.json',
    );
    final manifest = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final expected = <String>{
      for (final key in manifest.keys)
        if (key.length > 3 && key.lastIndexOf('-') == 2)
          '${key.substring(0, 2).toLowerCase()}_'
              '${key.substring(3).toLowerCase()}',
    };
    expect(kStudioV2PassportStampSlugs, isNotEmpty);
    expect(
      kStudioV2PassportStampSlugs.toSet(),
      expected,
      reason: 'run tool/generate_studio_v2_passport_stamps.dart',
    );
  });

  test(
    'Passport has available subjects on mobile (no flag fallback)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = buildStudioV2ControllerFor(
        const DesignContext(
          flagCodes: ['au', 'fr', 'gb'],
          scopeKey: 'test:passport',
        ),
      );
      addTearDown(controller.dispose);

      final passportIndex = StudioController.subjects.indexWhere(
        (s) => s.$1 == LabGenre.passport,
      );
      controller.selectSubject(passportIndex);
      final clip = controller.current.clip;
      expect(
        clip,
        isNotNull,
        reason: 'Passport degraded to a plain flag design',
      );
      expect(const {
        'passportPage',
        'passportStampOutline',
      }, contains(clip!.shapeId));

      // Every Vibe keeps the Passport family.
      for (final (style, styled) in controller.vibeStyleOptions()) {
        expect(
          styled.clip?.shapeId,
          clip.shapeId,
          reason: '$style broke Passport',
        );
      }
    },
  );

  test('a stamp slug maps to its bundled manifest key', () {
    expect(BundledPassportStamps.manifestKey('au_entry'), 'AU-entry');
    expect(BundledPassportStamps.manifestKey('gb_exit'), 'GB-exit');
    expect(BundledPassportStamps.manifestKey('au'), isNull);
    expect(BundledPassportStamps.manifestKey('au_middle'), isNull);
  });

  test('the bundle resolver loads real stamp artwork + metadata', () async {
    final stamps = BundledPassportStamps();
    final meta = jsonDecode(await stamps.meta('au_entry')) as Map;
    expect(meta['png_asset'], isA<String>());
    expect((meta['date'] as Map)['x'], isA<num>());
    expect((await stamps.png('au_entry')).length, greaterThan(100));
    await expectLater(stamps.png('zz_entry'), throwsA(anything));
  });

  testWidgets('the resolver rasterises a real stamp and a passport collage', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final resolver = createBundleAssetResolver();

      final mask = await resolver.resolveClipMask(
        ClipShape.passportStampOutline,
        'au_entry|12 MAR 24',
        width: 128,
        height: 128,
      );
      expect(mask, isNotNull, reason: 'no real stamp mask on device');
      expect(mask!.width, 128);

      final collage = await resolver.resolvePassportCollage(
        const [
          PassportStampRef('au_entry', '12 MAR 24'),
          PassportStampRef('au_exit', '28 MAR 24'),
          PassportStampRef('fr_entry', '04 JUN 25'),
        ],
        width: 160,
        height: 160,
        seed: 3,
      );
      expect(collage, isNotNull, reason: 'no passport collage on device');
      expect(collage!.width, 160);

      // A country with no bundled stamp resolves to null — the renderer then
      // falls back to built-in stamp geometry (see design_forge_render).
      expect(
        await resolver.resolvePassportCollage(
          const [PassportStampRef('zz_entry', '01 JAN 20')],
          width: 64,
          height: 64,
        ),
        isNull,
      );
    });
  });
}
