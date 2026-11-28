import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country_names.dart';
import 'signature_tee_widgets.dart';
import 'signature_tees.dart';

/// Opens the tee page for a pair (A on the left). Supplied by
/// `CommerceEntry`, so every tap goes through the commerce seam.
typedef OpenPairTee = void Function(BuildContext context, TeePair pair);

/// "Two countries" (M213): choose two countries for one shirt.
///
/// Suggested pairs come first ([pairSuggestionsProvider]: countries from the
/// same journey, then the two most visited); below them the traveller can
/// pick any two of their countries, in order, with a swap. The pair opens on
/// the signature tee page, which offers every two-country design.
///
/// Opened only through `CommerceEntry.openPairTees`.
class PairTeesScreen extends ConsumerStatefulWidget {
  const PairTeesScreen({super.key, required this.onOpenPair});

  final OpenPairTee onOpenPair;

  @override
  ConsumerState<PairTeesScreen> createState() => _PairTeesScreenState();
}

class _PairTeesScreenState extends ConsumerState<PairTeesScreen> {
  /// The picked countries, in print order (first = left).
  final List<String> _picked = [];

  void _toggle(String cc) => setState(() {
    if (_picked.remove(cc)) return;
    if (_picked.length == 2) _picked.removeAt(0);
    _picked.add(cc);
  });

  void _swap() => setState(() {
    if (_picked.length == 2) _picked.setAll(0, [_picked[1], _picked[0]]);
  });

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(pairCountriesProvider);
    final suggestions = ref.watch(pairSuggestionsProvider);
    final hasPacks = ref.watch(pairPacksProvider).isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String name(String cc) => kCountryNames[cc] ?? cc;

    return Scaffold(
      appBar: AppBar(title: const Text('Two countries')),
      body:
          !hasPacks || countries.length < 2
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Two-country tees need two countries. '
                    'Scan your photos to find yours.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (suggestions.isNotEmpty) ...[
                    Text('Suggested', style: text.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 172,
                      child: ListView.separated(
                        key: const Key('pair-suggestions'),
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final p = suggestions[i];
                          return _PairTile(
                            key: Key('pair-suggestion-${p.a}-${p.b}'),
                            pair: p,
                            onTap: () => widget.onOpenPair(context, p),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text('Pick any two', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'The first prints on the left.',
                    style: text.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _picked.isEmpty
                              ? 'Choose two countries'
                              : _picked.length == 1
                              ? '${name(_picked[0])} & …'
                              : '${name(_picked[0])} & ${name(_picked[1])}',
                          key: const Key('pair-picked'),
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('pair-swap'),
                        tooltip: 'Swap sides',
                        onPressed: _picked.length == 2 ? _swap : null,
                        icon: const Icon(Icons.swap_horiz),
                      ),
                      FilledButton(
                        key: const Key('pair-open'),
                        onPressed:
                            _picked.length == 2
                                ? () => widget.onOpenPair(
                                  context,
                                  teePair(_picked[0], _picked[1]),
                                )
                                : null,
                        child: const Text('See tees'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final cc in countries)
                        FilterChip(
                          key: Key('pair-pick-$cc'),
                          label: Text(
                            _picked.contains(cc)
                                ? '${_picked.indexOf(cc) + 1}. ${name(cc)}'
                                : name(cc),
                          ),
                          selected: _picked.contains(cc),
                          showCheckmark: false,
                          onSelected: (_) => _toggle(cc),
                        ),
                    ],
                  ),
                ],
              ),
    );
  }
}

/// A suggested pair: its default design on a shirt and its name.
class _PairTile extends StatelessWidget {
  const _PairTile({super.key, required this.pair, required this.onTap});

  final TeePair pair;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${pairTitle(pair)} tee',
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 128,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: SignatureTeeArt(
                      countryCode: pair.a,
                      pairWith: pair.b,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pairTitle(pair),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Two countries" row at the top of My tees: opens the pair chooser.
/// Builds nothing unless a two-country design exists and the traveller has
/// two countries ([pairTeesAvailableProvider]).
class PairTeesCard extends ConsumerWidget {
  const PairTeesCard({super.key, required this.onOpen});

  final void Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(pairTeesAvailableProvider)) return const SizedBox.shrink();
    final suggestions = ref.watch(pairSuggestionsProvider);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final first = suggestions.isEmpty ? null : suggestions.first;
    return Material(
      key: const Key('pair-tees-card'),
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (first != null)
                SizedBox(
                  width: 72,
                  height: 80,
                  child: SignatureTeeArt(
                    countryCode: first.a,
                    pairWith: first.b,
                  ),
                ),
              if (first != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Two countries',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      first == null
                          ? 'Two flags, one shirt'
                          : 'Two flags, one shirt · ${pairTitle(first)}',
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
    );
  }
}

/// The trip sheet's pair tee: for a trip whose journey reached two or more
/// countries, this trip's country with its neighbour on the journey
/// ([journeyPairFor]). Builds nothing otherwise, or without a pair design.
class TripPairTeeCard extends ConsumerWidget {
  const TripPairTeeCard({
    super.key,
    required this.pair,
    required this.onOpen,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final TeePair? pair;
  final OpenPairTee onOpen;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pair;
    if (p == null) return const SizedBox.shrink();
    if (ref.watch(signaturePairTeesProvider(p)).isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Material(
        key: Key('trip-pair-tee-${p.a}-${p.b}'),
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(context, p),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 80,
                  child: SignatureTeeArt(countryCode: p.a, pairWith: p.b),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One tee, two countries',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pairTitle(p),
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
