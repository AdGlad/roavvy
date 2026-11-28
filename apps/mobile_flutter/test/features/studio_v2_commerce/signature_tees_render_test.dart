import 'dart:ui' as ui;

import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/studio_v2/host/bundle_asset_resolver.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/production_print_specs.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/signature_tees/signature_tees.dart';
import 'package:shared_models/shared_models.dart' show TripRecord;
import 'package:flutter/services.dart' show rootBundle;

/// Every bundled Signature pack renders in the app, from the app's own asset
/// bundle (flags, passport stamps, silhouettes) through the production
/// resolver — the Lab renders from disk, so a design that looks right there
/// could still be missing an asset here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Includes a non-rectangular flag (NP) and a tricky one (ZA).
  const countries = ['us', 'jp', 'np', 'br', 'za'];

  testWidgets('every pack renders a visible tee for every sample country', (
    tester,
  ) async {
    late SignatureCatalog catalog;
    final problems = <String>[];
    await tester.runAsync(() async {
      catalog = await SignatureCatalog.load(rootBundle.loadString);
      final service = RenderService(createBundleAssetResolver());
      for (final cc in countries) {
        final trip = TripRecord(
          id: '${cc}1',
          countryCode: cc.toUpperCase(),
          startedOn: DateTime(2024, 3, 12),
          endedOn: DateTime(2024, 3, 26),
          photoCount: 10,
          isManual: false,
        );
        final tees = teesFor(catalog.packs, cc, trip: trip);
        if (tees.length != catalog.packs.length) {
          problems.add('$cc: only ${tees.length} of ${catalog.packs.length}');
        }
        for (final tee in tees) {
          try {
            final r = await service.renderArtwork(
              tee.recipe,
              longSide: kTeePreviewLongSide ~/ 2,
            );
            final cover = await _coverage(r.image);
            // Line-art stamps carry little ink; an empty render has none.
            if (cover < 0.02) {
              problems.add('${tee.pack.id}/$cc: almost empty ($cover)');
            }
          } catch (e) {
            problems.add('${tee.pack.id}/$cc: $e');
          }
        }
      }
    });
    expect(catalog.packs, hasLength(greaterThanOrEqualTo(10)));
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('every pack produces its print file through the cart path', (
    tester,
  ) async {
    final problems = <String>[];
    await tester.runAsync(() async {
      final catalog = await SignatureCatalog.load(rootBundle.loadString);
      final service = RenderService(createBundleAssetResolver());
      final trip = TripRecord(
        id: 'jp1',
        countryCode: 'JP',
        startedOn: DateTime(2024, 3, 12),
        endedOn: DateTime(2024, 3, 26),
        photoCount: 10,
        isManual: false,
      );
      for (final tee in teesFor(catalog.packs, 'jp', trip: trip)) {
        try {
          final request = buildSignatureTeeCartRequest(
            service: service,
            tee: tee,
            countryCode: 'JP',
            garment: teeGarments.first,
            trips: [trip],
          );
          final files = await renderPrintFiles(request.session);
          if (files.length != 1) {
            problems.add('${tee.pack.id}: ${files.length} print files');
            continue;
          }
          final back = files.single;
          if (back.recipeId != tee.recipe.recipeId) {
            problems.add('${tee.pack.id}: print recipe differs');
          }
          if (back.bytes.length < 10000 || back.widthPx < 1500) {
            problems.add(
              '${tee.pack.id}: print file ${back.widthPx}px, '
              '${back.bytes.length} bytes',
            );
          }
        } catch (e) {
          problems.add('${tee.pack.id}: $e');
        }
      }
    });
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Share of pixels with real ink.
Future<double> _coverage(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  var ink = 0;
  for (var i = 3; i < px.length; i += 4) {
    if (px[i] > 128) ink++;
  }
  return ink / (px.length / 4);
}
