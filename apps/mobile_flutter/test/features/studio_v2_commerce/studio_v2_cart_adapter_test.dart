import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart' show CardTemplateType;
import 'package:mobile_flutter/features/merch/merch_variant_lookup.dart'
    show tshirtColors;
import 'package:mobile_flutter/features/studio_v2/commerce/garment_cart_request.dart';
import 'package:mobile_flutter/features/studio_v2_commerce/studio_v2_cart_adapter.dart';

/// M8 — Studio V2 → commerce adapter. Verifies the thin, pure mapping from the
/// neutral [GarmentCartRequest] onto the inputs the EXISTING commerce screen
/// consumes: front/back artwork + placement + garment colour + travel metadata
/// transfer correctly, physical size stays a cart concern, and no V1 commerce
/// logic is duplicated (the adapter only maps + navigates).
void main() {
  DesignRecipe recipe(int seed) => DesignRecipe(
    seed: seed,
    content: const RecipeContent(flags: [FlagRef('us')]),
    composition: const Composition(family: DesignFamily.grid),
  );

  GarmentCartRequest request({
    String colourName = 'Navy',
    String frontPosition = 'left_chest',
    String backPosition = 'center',
    String? title = 'Wanderer',
    bool frontPrint = true,
  }) => GarmentCartRequest(
    garment: GarmentDesign(
      back: recipe(1),
      front: recipe(2),
      garmentColour: '#22303A',
      themeSeed: 3,
    ),
    renderBackArtwork: () async => Uint8List.fromList([1, 2, 3, 4]),
    renderFrontArtwork:
        frontPrint ? () async => Uint8List.fromList([5, 6, 7, 8]) : null,
    garmentColourHex: '#22303A',
    garmentColourName: colourName,
    selectedCountryCodes: const ['us', 'fr', 'jp'],
    trips: [
      Trip(
        countryCode: 'us',
        startedOn: DateTime(2020, 6, 1),
        endedOn: DateTime(2020, 6, 8),
        photoCount: 12,
      ),
      Trip(
        countryCode: 'fr',
        startedOn: DateTime(2021, 3, 1),
        endedOn: DateTime(2021, 3, 9),
      ),
    ],
    frontPosition: frontPosition,
    backPosition: backPosition,
    aspectRatio: 4 / 5,
    title: title,
  );

  test(
    'back artwork renders lazily; fixed-artwork flag set (hero is the print)',
    () async {
      final r = request();
      final input = StudioV2CartAdapter.map(r);
      expect(input.fixedArtwork, isTrue); // never re-rendered from a template
      expect(input.template, CardTemplateType.grid);
      // The print file is produced on demand via the request's render closure.
      final png = await r.renderBackArtwork();
      expect(png, isNotEmpty);
    },
  );

  test('placement transfers in the existing commerce vocabulary', () {
    final input = StudioV2CartAdapter.map(request());
    expect(input.frontPosition, 'left_chest');
    expect(input.backPosition, 'center'); // main artwork prints on the back
  });

  test('front face renders lazily when a front print is enabled (M9)', () async {
    final r = request(frontPosition: 'right_chest');
    // The real V2 front artwork is carried as a deferred render, so it — not the
    // V1 flag ribbon — becomes the front print.
    expect(r.renderFrontArtwork, isNotNull);
    final png = await r.renderFrontArtwork!();
    expect(png, isNotEmpty);
    // Chest placement is preserved through the mapping.
    expect(StudioV2CartAdapter.map(r).frontPosition, 'right_chest');
  });

  test('Front None carries no front render → blank front print (M9)', () {
    final r = request(frontPosition: 'none', frontPrint: false);
    // No front render closure ⇒ the commerce screen sends no front image.
    expect(r.renderFrontArtwork, isNull);
    expect(StudioV2CartAdapter.map(r).frontPosition, 'none');
  });

  test('garment colour maps onto a colour the store actually carries', () {
    // Exact where the store carries the same shirt.
    expect(StudioV2CartAdapter.v1ColourName('Black'), 'Black');
    expect(StudioV2CartAdapter.v1ColourName('White'), 'White');
    expect(StudioV2CartAdapter.v1ColourName('Red'), 'Red');
    // Nearest stocked relative for the rest of the supplier's range.
    // 'Blue' is the Shopify label for what is really the Navy variant.
    expect(StudioV2CartAdapter.v1ColourName('Navy'), 'Blue');
    // Royal is NOT mapped: the store's only blue is Navy (see unstockedColours).
    expect(StudioV2CartAdapter.v1ColourName('Dark Heather'), 'Grey');
    expect(StudioV2CartAdapter.v1ColourName('Sport Grey'), 'Grey');
    // Designs saved under the retired palette still resolve.
    expect(StudioV2CartAdapter.v1ColourName('Sand'), 'White');
    expect(StudioV2CartAdapter.v1ColourName('Olive'), 'Grey');
    // Mapped colour flows through the input.
    expect(StudioV2CartAdapter.map(request()).colourName, 'Blue');
  });

  test('a colour the store cannot make resolves to null, not a substitute', () {
    // The failure this guards against is silent: resolveVariantGid falls back
    // to its FIRST entry, so an unmapped colour would take payment for one
    // shirt and ship a black S.
    for (final colour in StudioV2CartAdapter.unstockedColours) {
      expect(
        StudioV2CartAdapter.v1ColourName(colour),
        isNull,
        reason: '\$colour must not resolve to some other shirt',
      );
    }
    expect(StudioV2CartAdapter.v1ColourName('Chartreuse'), isNull);
  });

  test(
    'every Studio garment colour is either stocked or declared unstocked',
    () {
      // The Studio offers the blank's full range; this is what keeps the two
      // lists honest. A colour added to the palette without deciding its variant
      // fails here rather than at a customer's door.
      for (final (hex, name) in StudioController.garments) {
        final mapped = StudioV2CartAdapter.v1ColourName(name);
        if (mapped == null) {
          expect(
            StudioV2CartAdapter.unstockedColours,
            contains(name),
            reason:
                '\$name (\$hex) has no variant and is not declared unstocked',
          );
        } else {
          expect(
            tshirtColors,
            contains(mapped),
            reason: '\$name maps to \$mapped, which the store does not carry',
          );
        }
      }
    },
  );

  test('travel metadata transfers; trips convert to TripRecords', () {
    final input = StudioV2CartAdapter.map(request());
    expect(input.selectedCodes, ['us', 'fr', 'jp']);
    expect(input.allCodes, ['us', 'fr', 'jp']);
    expect(input.trips.length, 2);
    expect(input.trips.first.countryCode, 'us');
    expect(input.trips.first.photoCount, 12);
    expect(input.title, 'Wanderer');
    expect(input.aspectRatio, 4 / 5);
  });

  test('physical garment size (XS–XXL) is NOT part of the Studio hand-off', () {
    // The neutral request itself has no size axis; neither does the mapped
    // commerce input. Physical size stays a cart/checkout concern owned by the
    // existing preview screen (which defaults size='L' with its own picker).
    final r = request();
    expect(r.selectedCountryCodes, isNotEmpty); // request is well-formed…
    final input = StudioV2CartAdapter.map(r);
    // …and the mapped input exposes only artwork/placement/travel fields — the
    // absence of any size field is enforced structurally by StudioV2CommerceInput.
    expect(input.colourName, isNotEmpty);
    expect(input.backPosition, 'center');
  });
}
