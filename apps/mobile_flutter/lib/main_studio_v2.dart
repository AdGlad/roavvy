import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Wire the real on-device travel database so the studio boots with the user's
  // actual trips. Without this override `roavvyDatabaseProvider` throws,
  // `tripListProvider` errors, and StudioV2App would hang on a blank spinner.
  final db = RoavvyDatabase(driftDatabase(name: 'roavvy'));
  // Wire the Studio V2 → commerce bridge here (the top level is the only place
  // that may know BOTH the isolated V2 feature and the V1 merch flow). Review →
  // Add to cart then reuses the existing cart/checkout/Printful pipeline.
  const adapter = StudioV2CartAdapter();
  runApp(ProviderScope(
    overrides: [roavvyDatabaseProvider.overrideWithValue(db)],
    child: StudioV2App(onAddToCart: adapter.addToCart),
  ));
}
