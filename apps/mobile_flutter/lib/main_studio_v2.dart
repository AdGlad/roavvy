import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/studio_v2/studio_v2_app.dart';

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
  runApp(const ProviderScope(child: StudioV2App()));
}
