import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../merch/shopify_pricing_repository.dart';
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
class StudioV2Entry extends ConsumerWidget {
  const StudioV2Entry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(shopifyPricingProvider);
    return StudioV2App(
      onAddToCart: const StudioV2CartAdapter().addToCart,
      // The entrypoint is the only layer that may know both sides, so this is
      // where the store's stock reaches the Studio.
      unavailableGarments: StudioV2CartAdapter.unstockedColours,
      priceLabel: prices.whenOrNull(data: (p) => p.tshirtFromPrice),
    );
  }
}
