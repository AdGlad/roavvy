import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country_names.dart';
import '../../merch/shopify_pricing_repository.dart'
    show shopifyPricingProvider;
import '../../studio_v2/widgets/shirt_preview.dart';
import 'torn_flag_tees.dart';

/// Opens a tee. Supplied by `CommerceEntry`, so every tap goes through the
/// commerce seam (and is a no-op when commerce is off).
typedef OpenTee = void Function(BuildContext context);

/// A country's torn flag on a shirt, rendered off the UI thread and cached.
///
/// Builds nothing when there is no tee for [countryCode] (no pack, or the
/// pack cannot produce one) and a quiet placeholder until the render lands.
class TornFlagTeeArt extends ConsumerWidget {
  const TornFlagTeeArt({
    super.key,
    required this.countryCode,
    this.garmentColour,
  });

  final String countryCode;

  /// `#RRGGBB`; null shows the first orderable colour.
  final String? garmentColour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(tornFlagRecipeProvider(countryCode));
    if (recipe == null) return const SizedBox.shrink();
    final service = ref.watch(tornFlagRenderServiceProvider);
    if (service == null) return const TeePlaceholder();
    return ShirtPreview(
      service: service,
      recipe: recipe,
      front: false,
      longSide: kTornFlagPreviewLongSide,
      garmentColour: garmentColour ?? tornFlagGarments.first.$1,
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

/// "Your torn flag tee" — the card on the country page and the trip sheet.
class TornFlagTeeCard extends ConsumerWidget {
  const TornFlagTeeCard({
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
    if (ref.watch(tornFlagRecipeProvider(countryCode)) == null) {
      return const SizedBox.shrink();
    }
    final cc = countryCode.toUpperCase();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final price = ref
        .watch(shopifyPricingProvider)
        .whenOrNull(data: (p) => p.tshirtFromPrice);
    final name = kCountryNames[cc] ?? cc;
    return Padding(
      padding: padding,
      child: Material(
        key: Key('torn-flag-tee-card-$cc'),
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 104,
                  child: TornFlagTeeArt(countryCode: cc),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your torn flag tee',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price == null ? name : '$name · from $price',
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
    if (ref.watch(tornFlagRecipeProvider(countryCode)) == null) {
      return const SizedBox.shrink();
    }
    final cc = countryCode.toUpperCase();
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
                  child: TornFlagTeeArt(countryCode: cc),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ${kCountryNames[cc] ?? cc} torn flag tee',
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
                        onPressed: () => onOpen(context),
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

  final OpenTee onOpen;

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
                  '$n torn flag ${n == 1 ? 'tee' : 'tees'} — '
                  'one for every country you\'ve been to',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: Row(
                    children: [
                      for (final cc in codes.take(3))
                        Expanded(child: TornFlagTeeArt(countryCode: cc)),
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
