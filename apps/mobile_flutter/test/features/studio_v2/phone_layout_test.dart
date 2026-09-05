// Every step of the Studio, at the size of an actual phone, with no overflow.
//
// The overflows keep coming back one control row at a time — a hero toolbar
// here, a footer there — because each was fixed where it was reported rather
// than looked for. This walks the whole flow at 390x844 (iPhone 14/15) and at
// the smallest iPhone still running a current iOS, so a striped bar has to
// survive a test run to reach a phone.
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudioController controller;
  setUp(() => controller = buildStudioV2Controller());
  tearDown(() => controller.dispose());

  /// Real map data, so the Travels step is exercised like every other — it is
  /// the step that has had the least coverage and the most trouble.
  Future<Uint8List> geodata(String path) async =>
      (await rootBundle.load(path)).buffer.asUint8List();

  for (final (label, size) in [
    ('an iPhone 15', const Size(390, 844)),
    // The smallest iPhone that runs a current iOS — 320x568 is the SE 1st
    // gen, which iOS 26 does not support.
    ('an iPhone SE', const Size(375, 667)),
  ]) {
    testWidgets('no step overflows on $label', (tester) async {
      late Uint8List countries, regions;
      await tester.runAsync(() async {
        countries = await geodata('assets/geodata/ne_countries.bin');
        regions = await geodata('assets/geodata/ne_admin1.bin');
      });
      // The globe asks the lookup engines for polygons and they assert if the
      // map data has not reached them — the same bootstrap the entrypoints do.
      initCountryLookup(countries);
      initRegionLookup(regions);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey<StudioV2ScreenState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geodataBytesProvider.overrideWithValue(countries),
            regionGeodataBytesProvider.overrideWithValue(regions),
          ],
          child: MaterialApp(
            home: StudioV2Screen(key: key, controller: controller),
          ),
        ),
      );
      await tester.pump();

      // Collected rather than thrown one at a time: a single run should name
      // every step that does not fit, not just the first.
      final broken = <String>[];
      void check(String where) {
        final e = tester.takeException();
        if (e != null) broken.add('$where: $e');
      }

      check('opening the studio');
      for (final stage in StudioStage.values) {
        key.currentState!.goToStage(stage);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        check(stage.name);
      }
      expect(broken, isEmpty, reason: 'steps that do not fit $label');
    });
  }
}
