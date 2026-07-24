// Verifies the globe's photo-heatmap/UNESCO-heritage overlay is a single
// mutually-exclusive selector defaulting to heatmap, replacing two
// independent booleans that could both be true at once (the reported bug:
// both overlays rendered together, and a tap near a heritage dot
// intercepted taps meant for the photo heatmap).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';

void main() {
  test('globeOverlayModeProvider defaults to heatmap', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(globeOverlayModeProvider),
      GlobeOverlayMode.heatmap,
    );
  });

  test('setting the mode replaces it rather than adding a second flag', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(globeOverlayModeProvider.notifier).state =
        GlobeOverlayMode.heritage;
    expect(container.read(globeOverlayModeProvider), GlobeOverlayMode.heritage);

    // There is exactly one enum value at a time — by construction, going
    // back to heatmap can never leave heritage "still on" the way the old
    // two independent StateProvider<bool>s could.
    container.read(globeOverlayModeProvider.notifier).state =
        GlobeOverlayMode.heatmap;
    expect(container.read(globeOverlayModeProvider), GlobeOverlayMode.heatmap);
  });
}
