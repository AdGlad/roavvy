import 'dart:typed_data';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:country_lookup/country_lookup.dart';
import 'package:region_lookup/region_lookup.dart';

import 'core/providers.dart';
import 'data/db/roavvy_database.dart';
import 'features/studio_v2/studio_v2_app.dart';
import 'features/studio_v2_commerce/studio_v2_cart_adapter.dart';

/// Dedicated **developer entrypoint** for Roavvy T-Shirt Studio V2.
///
/// Launch V2 independently of the production app with:
///   flutter run -t lib/main_studio_v2.dart
///
/// (The production `lib/main.dart` also boots V2 when built with
/// `--dart-define=STUDIO_V2=true`; both paths are debug/dev-only and leave the
/// V1 flow completely untouched.)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wire the real on-device travel database so the studio boots with the user's
  // actual trips. Without this override `roavvyDatabaseProvider` throws,
  // `tripListProvider` errors, and StudioV2App would hang on a blank spinner.
  final db = RoavvyDatabase(driftDatabase(name: 'roavvy'));
  // The Travels step hosts the real globe, which reads the bundled map data.
  // Without these the studio boots fine and then throws the moment anyone
  // reaches Travels — production loads them the same way at startup.
  final (countryBytes, regionBytes) = await _loadGeodata();
  // The globe asks the lookup engines for polygons; they assert if the map
  // data has not been handed to them first. Production does this at startup.
  initCountryLookup(countryBytes);
  initRegionLookup(regionBytes);
  // Wire the Studio V2 → commerce bridge here (the top level is the only place
  // that may know BOTH the isolated V2 feature and the V1 merch flow). Review →
  // Add to cart then reuses the existing cart/checkout/Printful pipeline.
  const adapter = StudioV2CartAdapter();
  runApp(
    ProviderScope(
      overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
        geodataBytesProvider.overrideWithValue(countryBytes),
        regionGeodataBytesProvider.overrideWithValue(regionBytes),
      ],
      child: StudioV2App(
        onAddToCart: adapter.addToCart,
        // The entrypoint is the only layer that may know both sides, so this is
        // where the store's stock reaches the Studio.
        unavailableGarments: StudioV2CartAdapter.unstockedColours,
      ),
    ),
  );
}

/// The bundled map data the globe draws from.
Future<(Uint8List, Uint8List)> _loadGeodata() async {
  final (countries, regions) =
      await (
        rootBundle.load('assets/geodata/ne_countries.bin'),
        rootBundle.load('assets/geodata/ne_admin1.bin'),
      ).wait;
  return (countries.buffer.asUint8List(), regions.buffer.asUint8List());
}
