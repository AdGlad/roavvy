import 'package:design_studio/design_studio.dart' show PrintLayout, PrintSide;
import 'package:design_studio/garment_mockup.dart'
    show
        PrintLayoutControls,
        TeeBackdrop,
        teeBackdropFor,
        TeeSidesPreview,
        TeeView,
        TeeViewSwitcher;
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

/// The signature tee product page (M200): the design, where it prints, the
/// shirt colour, a size, the price, Add to cart. The traveller picks one of
/// the country's signature designs, but nothing about a design can be changed
/// here — each is the approved Signature hero for [countryCode], exactly.
///
/// Where it prints can: a print layout (presets such as Crest + back, or a
/// zone and size per face), opening on the layout the pack was approved with.
/// The shirt turns with Front / Back / Both or a sideways swipe, and the
/// zone's largest printable area is outlined once the layout is being edited.
///
/// Opened only through `CommerceEntry.openSignatureTee`.
class SignatureTeeScreen extends ConsumerStatefulWidget {
  const SignatureTeeScreen({
    super.key,
    required this.countryCode,
    this.packId,
    this.pairWith,
    this.onAddToCart = _studioCart,
  });

  /// The country — for a pair tee, the first (left) country.
  final String countryCode;

  /// The second (right) country of a pair tee (M213, ADR-185); null for a
  /// one-country tee. The page then offers the two-country designs, titled
  /// "Greece & Italy", with a swap that reverses the order.
  final String? pairWith;

  /// The design shown first; null (or a design the country doesn't have)
  /// shows the country's default design.
  final String? packId;
  final TeeAddToCart onAddToCart;

  @override
  ConsumerState<SignatureTeeScreen> createState() => _SignatureTeeScreenState();
}

class _SignatureTeeScreenState extends ConsumerState<SignatureTeeScreen> {
  late (String, String) _garment = teeGarments.first;
  late String? _packId = widget.packId;
  late String _a = widget.countryCode.toUpperCase();
  late String? _b = widget.pairWith?.toUpperCase();
  String? _size;
  bool _adding = false;

  /// The traveller's layout per design, once they change it.
  final Map<String, PrintLayout> _layouts = {};
  TeeView? _view;
  bool _guides = false;

  PrintLayout _layoutFor(SignatureTee tee) =>
      _layouts[tee.pack.id] ?? teeLayout(tee);

  TeeView _viewFor(SignatureTee tee) =>
      _view ?? TeeView.forLayout(_layoutFor(tee));

  void _setLayout(SignatureTee tee, PrintLayout l) => setState(() {
    _layouts[tee.pack.id] = l;
    _guides = true;
    // Keep looking at a face that prints.
    final side = _viewFor(tee).side;
    if (side != null && !l.prints(side)) _view = TeeView.forLayout(l);
  });

  void _focus(PrintSide side) => setState(() {
    _guides = true;
    if (_view != TeeView.both) _view = TeeView.of(side);
  });

  String get _cc => _a;

  TeePair? get _pair => _b == null ? null : teePair(_a, _b!);

  /// The selected tee, falling back to the default design.
  SignatureTee? _tee(WidgetRef ref) {
    final pair = _pair;
    if (pair != null) {
      return ref.watch(
            signaturePairTeeProvider((pair: pair, packId: _packId)),
          ) ??
          ref.watch(signaturePairTeeProvider((pair: pair, packId: null)));
    }
    return ref.watch(
          signatureTeeProvider((countryCode: _cc, packId: _packId)),
        ) ??
        ref.watch(signatureTeeProvider((countryCode: _cc, packId: null)));
  }

  /// Every design on offer for this country, or this pair.
  List<SignatureTee> _tees(WidgetRef ref) {
    final pair = _pair;
    return pair == null
        ? ref.watch(signatureTeesProvider(_cc))
        : ref.watch(signaturePairTeesProvider(pair));
  }

  /// Pair tees: reverse the order. The design is a different one (ADR-185:
  /// A sits left), so the view and guides start fresh; the chosen layout and
  /// design are kept.
  void _swap() => setState(() {
    final b = _b;
    if (b == null) return;
    _b = _a;
    _a = b;
  });

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
        layout: _layoutFor(tee),
        pairWith: _b,
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
    final tees = _tees(ref);
    final loading = ref.watch(signatureCatalogProvider).isLoading;
    final pair = _pair;
    final name = pair == null ? kCountryNames[_cc] ?? _cc : pairTitle(pair);
    final price = ref
        .watch(shopifyPricingProvider)
        .whenOrNull(data: (p) => p.tshirtFromPrice);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final service = ref.watch(signatureTeeRenderServiceProvider);

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
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          children: [
                            if (pair != null) ...[
                              _PairHeader(pair: pair, onSwap: _swap),
                              const SizedBox(height: 6),
                            ],
                            TeeViewSwitcher(
                              view: _viewFor(tee),
                              layout: _layoutFor(tee),
                              onChanged: (v) => setState(() => _view = v),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: TeeBackdrop(
                                garmentColour: _garment.$1,
                                borderRadius: BorderRadius.circular(16),
                                child:
                                    service == null
                                        ? const TeePlaceholder()
                                        : TeeSidesPreview(
                                          key: Key(
                                            pair == null
                                                ? 'tee-preview-${tee.pack.id}'
                                                : 'tee-preview-${tee.pack.id}-'
                                                    '${pair.a}-${pair.b}',
                                          ),
                                          service: service,
                                          recipe: teeRecipe(tee, _garment.$1),
                                          layout: _layoutFor(tee),
                                          view: _viewFor(tee),
                                          onViewChanged:
                                              (v) => setState(() => _view = v),
                                          garmentColour: _garment.$1,
                                          longSide: kTeePreviewLongSide,
                                          showGuides: _guides,
                                          placeholder: const TeePlaceholder(),
                                        ),
                              ),
                            ),
                          ],
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
                              pairWith: _b,
                              packId: t.pack.id,
                              title: t.pack.title,
                              garmentColour: _garment.$1,
                              selected: t.pack.id == tee.pack.id,
                              onTap:
                                  () => setState(() {
                                    _packId = t.pack.id;
                                    _view = null;
                                    _guides = false;
                                  }),
                            );
                          },
                        ),
                      ),
                    Flexible(
                      flex: 6,
                      child: SingleChildScrollView(
                        key: const Key('tee-controls'),
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
                            PrintLayoutControls(
                              key: const Key('tee-layout'),
                              layout: _layoutFor(tee),
                              onChanged: (l) => _setLayout(tee, l),
                              onFocus: _focus,
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
                                    onSelected:
                                        (_) => setState(() => _size = s),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const Key('tee-add-to-cart'),
                                onPressed:
                                    _size == null || _adding
                                        ? null
                                        : _addToCart,
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
    this.pairWith,
  });

  final String countryCode;
  final String? pairWith;
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
            // The same backdrop as the big shirt, so dark shirts read here too.
            color: teeBackdropFor(garmentColour),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: SignatureTeeArt(
            countryCode: countryCode,
            pairWith: pairWith,
            packId: packId,
            garmentColour: garmentColour,
          ),
        ),
      ),
    );
  }
}

/// Pair tees: "Greece ⇄ Italy" — the two countries in print order, with a
/// swap that reverses them.
class _PairHeader extends StatelessWidget {
  const _PairHeader({required this.pair, required this.onSwap});

  final TeePair pair;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget country(String cc, String key) => Flexible(
      child: Text(
        kCountryNames[cc] ?? cc,
        key: Key(key),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        country(pair.a, 'tee-pair-a'),
        IconButton(
          key: const Key('tee-pair-swap'),
          tooltip: 'Swap sides',
          visualDensity: VisualDensity.compact,
          color: cs.primary,
          onPressed: onSwap,
          icon: const Icon(Icons.swap_horiz),
        ),
        country(pair.b, 'tee-pair-b'),
      ],
    );
  }
}
