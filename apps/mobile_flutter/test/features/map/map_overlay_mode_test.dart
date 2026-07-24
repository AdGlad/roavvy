// Verifies the map's photo-heatmap/UNESCO-heritage overlay is a single
// mutually-exclusive selector defaulting to heatmap, shared by both the
// globe and the flat map — replacing independent flags that could both be
// true at once (the reported bug: both overlays rendered together on both
// views, and on the globe a tap near a heritage dot intercepted taps meant
// for the photo heatmap).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';

void main() {
  test('mapOverlayModeProvider defaults to heatmap', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(mapOverlayModeProvider),
      MapOverlayMode.heatmap,
    );
  });

  test('setting the mode replaces it rather than adding a second flag', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(mapOverlayModeProvider.notifier).state =
        MapOverlayMode.heritage;
    expect(container.read(mapOverlayModeProvider), MapOverlayMode.heritage);

    // There is exactly one enum value at a time — by construction, going
    // back to heatmap can never leave heritage "still on" the way
    // independent StateProvider<bool>s could.
    container.read(mapOverlayModeProvider.notifier).state =
        MapOverlayMode.heatmap;
    expect(container.read(mapOverlayModeProvider), MapOverlayMode.heatmap);
  });
}
