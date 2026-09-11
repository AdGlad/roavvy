import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../merch/shopify_pricing_repository.dart';
import '../studio_v2/host/studio_identity.dart';
import '../studio_v2/host/studio_v2_trace.dart';
import '../studio_v2/studio_v2_app.dart';
import 'studio_v2_cart_adapter.dart';

/// The Studio, wired to the store.
///
/// This is the bridge layer — the one place allowed to know both the Studio and
/// the V1 merch flow (`features/studio_v2` may import neither, and a structural
/// test enforces it). Every entrypoint opens the Studio through here so the
/// wiring is written once: the cart adapter, the colours the store cannot
/// currently make, and the store's own price.
///
/// The price is the live Shopify "from" price via [shopifyPricingProvider] —
/// never a constant. While it is loading, or if the lookup fails, the Studio is
/// handed null and Review says the price is confirmed at checkout rather than
/// showing a number nobody promised.
///
/// Identity arrives the same way: this is where the Roavvy account becomes a
/// [StudioOwner], so the Studio saves into the right person's wardrobe without
/// ever importing Firebase or reading auth state itself.
class StudioV2Entry extends ConsumerWidget {
  const StudioV2Entry({super.key, this.embedded = false});

  /// True when the Studio is pushed as a route inside the running Roavvy app
  /// (Shop → Studio) rather than being the whole app, as it is from the dev
  /// entrypoints. Passed through so the Studio does not install a second
  /// [MaterialApp] over the host's — see [StudioV2App.embedded].
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Who is signing in is settled long before anyone reaches the Shop, but
    // opening the wardrobe under the device scope and finding out a moment
    // later would file this session's saves under the wrong owner — and a
    // wardrobe is not something to guess at.
    //
    // Reading it must not be able to stop the Studio opening, though. The
    // dev entrypoints run without Firebase, and asking an uninitialised
    // FirebaseAuth for a stream throws straight out of build() — which is a
    // black screen, not a degraded one. No account simply means the designs
    // belong to the device.
    String? uid;
    var authLoading = false;
    try {
      final auth = ref.watch(authStateProvider);
      authLoading = auth.isLoading;
      uid = auth.value?.uid;
    } catch (e) {
      v2trace('auth unavailable, saving to the device scope: $e');
    }
    if (authLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0F12),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final prices = ref.watch(shopifyPricingProvider);
    return StudioV2App(
      owner: StudioOwner.of(uid),
      embedded: embedded,
      onAddToCart: const StudioV2CartAdapter().addToCart,
      // The entrypoint is the only layer that may know both sides, so this is
      // where the store's stock reaches the Studio.
      unavailableGarments: StudioV2CartAdapter.unstockedColours,
      priceLabel: prices.whenOrNull(data: (p) => p.tshirtFromPrice),
    );
  }
}
