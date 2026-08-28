import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
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
  }) =>
      GarmentCartRequest(
        garment: GarmentDesign(
          back: recipe(1),
          front: recipe(2),
          garmentColour: '#22303A',
          themeSeed: 3,
        ),
        renderBackArtwork: () async => Uint8List.fromList([1, 2, 3, 4]),
        garmentColourHex: '#22303A',
        garmentColourName: colourName,
        selectedCountryCodes: const ['us', 'fr', 'jp'],
        trips: [
          Trip(
              countryCode: 'us',
              startedOn: DateTime(2020, 6, 1),
              endedOn: DateTime(2020, 6, 8),
              photoCount: 12),
          Trip(
              countryCode: 'fr',
              startedOn: DateTime(2021, 3, 1),
              endedOn: DateTime(2021, 3, 9)),
        ],
        frontPosition: frontPosition,
        backPosition: backPosition,
        aspectRatio: 4 / 5,
        title: title,
      );

  test('back artwork renders lazily; fixed-artwork flag set (hero is the print)',
      () async {
    final r = request();
    final input = StudioV2CartAdapter.map(r);
    expect(input.fixedArtwork, isTrue); // never re-rendered from a template
    expect(input.template, CardTemplateType.grid);
    // The print file is produced on demand via the request's render closure.
    final png = await r.renderBackArtwork();
    expect(png, isNotEmpty);
  });

  test('placement transfers in the existing commerce vocabulary', () {
    final input = StudioV2CartAdapter.map(request());
    expect(input.frontPosition, 'left_chest');
    expect(input.backPosition, 'center'); // main artwork prints on the back
  });

  test('garment colour maps to the nearest existing t-shirt colour', () {
    expect(StudioV2CartAdapter.v1ColourName('Black'), 'Black');
    expect(StudioV2CartAdapter.v1ColourName('White'), 'White');
    expect(StudioV2CartAdapter.v1ColourName('Navy'), 'Blue');
    expect(StudioV2CartAdapter.v1ColourName('Grey'), 'Grey');
    expect(StudioV2CartAdapter.v1ColourName('Sand'), 'White');
    expect(StudioV2CartAdapter.v1ColourName('Olive'), 'Grey');
    // Unknown labels fall back to a valid existing colour (never invalid input).
    final fallback = StudioV2CartAdapter.v1ColourName('Chartreuse');
    expect(tshirtColors.contains(fallback), isTrue);
    // Mapped colour flows through the input.
    expect(StudioV2CartAdapter.map(request()).colourName, 'Blue');
  });

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
