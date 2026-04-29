import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../memory/memory_pulse_service.dart';
import '../shared/hero_image_view.dart';

/// In-app travel anniversary card, shown on the map screen (M91, ADR-136).
///
/// Displays a 80×80 hero thumbnail, years-ago copy, country name, top labels,
/// and action buttons ("View trip" + dismiss). Calls [onViewTrip] when the
/// user taps "View trip" and dismisses itself (via [memoriesDismissedProvider]
/// + SharedPreferences) when the user taps the dismiss button.
///
/// Multiple anniversaries are shown as a horizontally paged [PageView] (max 3).
class MemoryPulseCard extends ConsumerWidget {
  const MemoryPulseCard({
    super.key,
    required this.memories,
    required this.onViewTrip,
    required this.service,
  });

  final List<HeroImage> memories;

  /// Called with the tripId when the user taps "View trip".
  final void Function(String tripId) onViewTrip;

  final MemoryPulseService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(memoriesDismissedProvider);
    final visible = memories.where((m) => !dismissed.contains(m.tripId)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    if (visible.length == 1) {
      return _SingleCard(
        hero: visible.first,
        onViewTrip: onViewTrip,
        service: service,
      );
    }

    return _PagedCards(
      memories: visible,
      onViewTrip: onViewTrip,
      service: service,
    );
  }
}

// ── Single card ───────────────────────────────────────────────────────────────

class _SingleCard extends ConsumerWidget {
  const _SingleCard({
    required this.hero,
    required this.onViewTrip,
    required this.service,
  });

  final HeroImage hero;
  final void Function(String tripId) onViewTrip;
  final MemoryPulseService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CardBody(
      hero: hero,
      onViewTrip: onViewTrip,
      onDismiss: () => _dismiss(ref),
      service: service,
    );
  }

  Future<void> _dismiss(WidgetRef ref) async {
    ref.read(memoriesDismissedProvider.notifier).update((s) => {...s, hero.tripId});
    await service.dismiss(hero.tripId, DateTime.now());
  }
}

// ── Paged cards ───────────────────────────────────────────────────────────────

class _PagedCards extends StatefulWidget {
  const _PagedCards({
    required this.memories,
    required this.onViewTrip,
    required this.service,
  });

  final List<HeroImage> memories;
  final void Function(String tripId) onViewTrip;
  final MemoryPulseService service;

  @override
  State<_PagedCards> createState() => _PagedCardsState();
}

class _PagedCardsState extends State<_PagedCards> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _kCardHeight,
          child: PageView.builder(
            itemCount: widget.memories.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final hero = widget.memories[i];
              return Consumer(
                builder: (_, ref, __) => _CardBody(
                  hero: hero,
                  onViewTrip: widget.onViewTrip,
                  onDismiss: () async {
                    ref
                        .read(memoriesDismissedProvider.notifier)
                        .update((s) => {...s, hero.tripId});
                    await widget.service.dismiss(hero.tripId, DateTime.now());
                  },
                  service: widget.service,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _DotsIndicator(count: widget.memories.length, current: _page),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        return Container(
          width: i == current ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i == current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Card body ─────────────────────────────────────────────────────────────────

const double _kCardHeight = 100.0;

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.hero,
    required this.onViewTrip,
    required this.onDismiss,
    required this.service,
  });

  final HeroImage hero;
  final void Function(String tripId) onViewTrip;
  final VoidCallback onDismiss;
  final MemoryPulseService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final yearsAgo = today.year - hero.capturedAt.year;
    final copy = service.buildCopy(hero, yearsAgo);
    final countryName = kCountryNames[hero.countryCode] ?? hero.countryCode;
    final topLabels = [
      if (hero.primaryScene != null) hero.primaryScene!,
      ...hero.mood.take(1),
    ].take(2).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3550),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: HeroImageView(
                assetId: hero.assetId,
                fallbackColor: const Color(0xFF2D4A5F),
                height: 72,
                thumbnailSize: 200,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  copy.title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  countryName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (topLabels.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: topLabels
                        .map(
                          (l) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l.replaceAll('_', ' '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () => onViewTrip(hero.tripId),
                      child: Text(
                        'View trip',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onDismiss,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
