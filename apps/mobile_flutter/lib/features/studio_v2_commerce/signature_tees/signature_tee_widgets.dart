import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country_names.dart';
import '../../merch/shopify_pricing_repository.dart'
    show shopifyPricingProvider;
import '../../studio_v2/widgets/shirt_preview.dart';
import 'signature_tees.dart';

/// Opens a tee. Supplied by `CommerceEntry`, so every tap goes through the
/// commerce seam (and is a no-op when commerce is off).
///
/// [packId] is the design to open; null opens the country's default design.
typedef OpenTee = void Function(BuildContext context, String? packId);

/// One of a country's signature designs on a shirt, rendered off the UI
/// thread and cached.
///
/// Builds nothing when there is no such tee (no pack, or the pack cannot
/// produce one for [countryCode]) and a quiet placeholder until the render
/// lands.
class SignatureTeeArt extends ConsumerWidget {
  const SignatureTeeArt({
    super.key,
    required this.countryCode,
    this.packId,
    this.garmentColour,
  });

  final String countryCode;

  /// The design; null is the country's default (first) design.
  final String? packId;

  /// `#RRGGBB`; null shows the first orderable colour.
  final String? garmentColour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tee = ref.watch(
      signatureTeeProvider((countryCode: countryCode, packId: packId)),
    );
    if (tee == null) return const SizedBox.shrink();
    final service = ref.watch(signatureTeeRenderServiceProvider);
    if (service == null) return const TeePlaceholder();
    final shirt = garmentColour ?? teeGarments.first.$1;
    return ShirtPreview(
      service: service,
      // The shirt's own ink for a design whose ink follows it (Passport
      // Stamp: white on a dark shirt); the approved recipe otherwise.
      recipe: teeRecipe(tee, shirt),
      front: false,
      longSide: kTeePreviewLongSide,
      garmentColour: shirt,
      placeholder: const TeePlaceholder(),
    );
  }
}

/// Shown while a tee renders.
class TeePlaceholder extends StatelessWidget {
  const TeePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.checkroom_outlined,
      size: 36,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
    ),
  );
}

/// "Your (country) tees" — the card on the country page and the trip sheet:
/// every signature design the country has, in a row. Tapping a design opens
/// it; tapping the header opens the default design.
class SignatureTeeCard extends ConsumerWidget {
  const SignatureTeeCard({
    super.key,
    required this.countryCode,
    required this.onOpen,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final String countryCode;
  final OpenTee onOpen;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = countryCode.toUpperCase();
    final tees = ref.watch(signatureTeesProvider(cc));
    if (tees.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final price = ref
        .watch(shopifyPricingProvider)
        .whenOrNull(data: (p) => p.tshirtFromPrice);
    final name = kCountryNames[cc] ?? cc;
    final n = tees.length;
    final designs = '$n ${n == 1 ? 'design' : 'designs'}';
    return Padding(
      padding: padding,
      child: Material(
        key: Key('signature-tee-card-$cc'),
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: Key('signature-tee-card-open-$cc'),
              onTap: () => onOpen(context, null),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your $name tees',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            price == null ? designs : '$designs · from $price',
                            style: text.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: tees.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final id = tees[i].pack.id;
                  return Semantics(
                    button: true,
                    label: '${tees[i].pack.title} tee',
                    child: InkWell(
                      key: Key('signature-tee-$cc-$id'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onOpen(context, id),
                      child: SizedBox(
                        width: 96,
                        child: SignatureTeeArt(countryCode: cc, packId: id),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tee on the new-country celebration: a compact strip with
/// "Get this tee". Gives way to the celebration on a short screen rather than
/// pushing its buttons off it.
class CelebrationTee extends ConsumerWidget {
  const CelebrationTee({
    super.key,
    required this.countryCode,
    required this.onOpen,
  });

  final String countryCode;
  final OpenTee onOpen;

  static const double _minHeight = 84;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = countryCode.toUpperCase();
    if (ref.watch(signatureTeesProvider(cc)).isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight < _minHeight) return const SizedBox.shrink();
        return Center(
          child: Container(
            key: Key('celebration-tee-$cc'),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            constraints: BoxConstraints(
              maxHeight: box.maxHeight.clamp(_minHeight, 132),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 0.85,
                  child: SignatureTeeArt(countryCode: cc),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ${kCountryNames[cc] ?? cc} tee',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton(
                        key: const Key('celebration-get-tee'),
                        onPressed: () => onOpen(context, null),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1C1E),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Get this tee'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The Stats entry into "My tees": how many tees the traveller has, with the
/// three newest on show. Builds nothing until there is at least one.
class MyTeesCard extends ConsumerWidget {
  const MyTeesCard({super.key, required this.onOpen});

  final void Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(myTeesProvider).valueOrNull ?? const <String>[];
    if (codes.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = codes.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Material(
        key: const Key('my-tees-card'),
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My tees',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tees for ${n == 1 ? 'the country' : 'all $n countries'} '
                  'you\'ve been to',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: Row(
                    children: [
                      for (final cc in codes.take(3))
                        Expanded(child: SignatureTeeArt(countryCode: cc)),
                      for (var i = codes.length; i < 3; i++) const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
