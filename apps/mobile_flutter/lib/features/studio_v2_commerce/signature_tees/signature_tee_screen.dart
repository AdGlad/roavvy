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
import 'signature_tee_widgets.dart';
import 'signature_tees.dart';

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

/// The signature tee product page (M200): the design, the shirt colour, a
/// size, the price, Add to cart. The traveller picks one of the country's
/// signature designs, but nothing about a design can be changed here — each
/// is the approved Signature hero for [countryCode], exactly.
///
/// Opened only through `CommerceEntry.openSignatureTee`.
class SignatureTeeScreen extends ConsumerStatefulWidget {
  const SignatureTeeScreen({
    super.key,
    required this.countryCode,
    this.packId,
    this.onAddToCart = _studioCart,
  });

  final String countryCode;

  /// The design shown first; null (or a design the country doesn't have)
  /// shows the country's default design.
  final String? packId;
  final TeeAddToCart onAddToCart;

  @override
  ConsumerState<SignatureTeeScreen> createState() =>
      _SignatureTeeScreenState();
}

class _SignatureTeeScreenState extends ConsumerState<SignatureTeeScreen> {
  late (String, String) _garment = teeGarments.first;
  late String? _packId = widget.packId;
  String? _size;
  bool _adding = false;

  String get _cc => widget.countryCode.toUpperCase();

  /// The selected tee, falling back to the default design.
  SignatureTee? _tee(WidgetRef ref) =>
      ref.watch(signatureTeeProvider((countryCode: _cc, packId: _packId))) ??
      ref.watch(signatureTeeProvider((countryCode: _cc, packId: null)));

  Future<void> _addToCart() async {
    final tee = _tee(ref);
    final service = ref.read(signatureTeeRenderServiceProvider);
    final size = _size;
    if (tee == null || service == null || size == null || _adding) return;
    setState(() => _adding = true);
    try {
      final request = buildSignatureTeeCartRequest(
        service: service,
        tee: tee,
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
    final tee = _tee(ref);
    final tees = ref.watch(signatureTeesProvider(_cc));
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
          tee == null
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
                        child: SignatureTeeArt(
                          key: Key('tee-preview-${tee.pack.id}'),
                          countryCode: _cc,
                          packId: tee.pack.id,
                          garmentColour: _garment.$1,
                        ),
                      ),
                    ),
                    if (tees.length > 1)
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          key: const Key('tee-designs'),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          itemCount: tees.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final t = tees[i];
                            return _DesignChoice(
                              key: Key('tee-design-${t.pack.id}'),
                              countryCode: _cc,
                              packId: t.pack.id,
                              title: t.pack.title,
                              garmentColour: _garment.$1,
                              selected: t.pack.id == tee.pack.id,
                              onTap: () => setState(() => _packId = t.pack.id),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${tee.pack.title} · $name',
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
                              for (final g in teeGarments)
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

/// One design in the product page's design row: a small shirt, outlined when
/// selected.
class _DesignChoice extends StatelessWidget {
  const _DesignChoice({
    super.key,
    required this.countryCode,
    required this.packId,
    required this.title,
    required this.garmentColour,
    required this.selected,
    required this.onTap,
  });

  final String countryCode;
  final String packId;
  final String title;
  final String garmentColour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: SignatureTeeArt(
            countryCode: countryCode,
            packId: packId,
            garmentColour: garmentColour,
          ),
        ),
      ),
    );
  }
}
