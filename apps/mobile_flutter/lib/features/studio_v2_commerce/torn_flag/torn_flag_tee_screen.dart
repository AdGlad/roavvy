import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country_names.dart';
import '../../../core/providers.dart';
import '../../merch/merch_variant_lookup.dart' show tshirtSizes;
import '../../merch/shopify_pricing_repository.dart'
    show shopifyPricingProvider;
import '../../studio_v2/commerce/garment_cart_request.dart';
import '../studio_v2_cart_adapter.dart';
import '../studio_v2_cart_service.dart' show StudioV2PurchaseOptions;
import 'torn_flag_tee_widgets.dart';
import 'torn_flag_tees.dart';

/// Puts a tee in the cart. The default is the Studio V2 cart adapter; tests
/// inject a recorder.
typedef TeeAddToCart =
    Future<void> Function(
      BuildContext context,
      GarmentCartRequest request,
      StudioV2PurchaseOptions options,
    );

Future<void> _studioCart(
  BuildContext context,
  GarmentCartRequest r,
  StudioV2PurchaseOptions options,
) => const StudioV2CartAdapter().addToCart(context, r, options: options);

/// The torn-flag tee product page (M200): the shirt, its colour, a size, the
/// price, Add to cart. Nothing about the design can be changed here — it is
/// the approved Signature hero for [countryCode], exactly.
///
/// Opened only through `CommerceEntry.openTornFlagTee`.
class TornFlagTeeScreen extends ConsumerStatefulWidget {
  const TornFlagTeeScreen({
    super.key,
    required this.countryCode,
    this.onAddToCart = _studioCart,
  });

  final String countryCode;
  final TeeAddToCart onAddToCart;

  @override
  ConsumerState<TornFlagTeeScreen> createState() => _TornFlagTeeScreenState();
}

class _TornFlagTeeScreenState extends ConsumerState<TornFlagTeeScreen> {
  late (String, String) _garment = tornFlagGarments.first;
  String? _size;
  bool _adding = false;

  String get _cc => widget.countryCode.toUpperCase();

  Future<void> _addToCart() async {
    final recipe = ref.read(tornFlagRecipeProvider(_cc));
    final service = ref.read(tornFlagRenderServiceProvider);
    final size = _size;
    if (recipe == null || service == null || size == null || _adding) return;
    setState(() => _adding = true);
    try {
      final request = buildTornFlagCartRequest(
        service: service,
        recipe: recipe,
        countryCode: _cc,
        garment: _garment,
        trips: ref.read(tripListProvider).valueOrNull ?? const [],
      );
      await widget.onAddToCart(
        context,
        request,
        StudioV2PurchaseOptions(size: size),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(tornFlagRecipeProvider(_cc));
    final loading = ref.watch(signatureCatalogProvider).isLoading;
    final name = kCountryNames[_cc] ?? _cc;
    final price = ref
        .watch(shopifyPricingProvider)
        .whenOrNull(data: (p) => p.tshirtFromPrice);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body:
          recipe == null
              ? Center(
                child:
                    loading
                        ? const CircularProgressIndicator()
                        : const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "This tee isn't available yet.",
                            textAlign: TextAlign.center,
                          ),
                        ),
              )
              : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The shirt stays in view; the controls scroll under it.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TornFlagTeeArt(
                          key: const Key('tee-preview'),
                          countryCode: _cc,
                          garmentColour: _garment.$1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Torn flag · $name',
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            key: const Key('tee-price'),
                            price ?? 'Price confirmed at checkout',
                            style: text.titleMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Colour · ${_garment.$2}',
                            style: text.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              for (final g in tornFlagGarments)
                                _Swatch(
                                  key: Key('tee-colour-${g.$2}'),
                                  hex: g.$1,
                                  name: g.$2,
                                  selected: g == _garment,
                                  onTap: () => setState(() => _garment = g),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Size', style: text.labelLarge),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final s in tshirtSizes)
                                ChoiceChip(
                                  key: Key('tee-size-$s'),
                                  label: Text(s),
                                  selected: _size == s,
                                  onSelected: (_) => setState(() => _size = s),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('tee-add-to-cart'),
                              onPressed:
                                  _size == null || _adding ? null : _addToCart,
                              child: Text(
                                _size == null
                                    ? 'Choose a size'
                                    : price == null
                                    ? 'Add to cart'
                                    : 'Add to cart · $price',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.hex,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colour = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
