import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/providers.dart';
import '../memory/memory_anniversary_photo.dart';
import '../memory/memory_pulse_service.dart';
import '../memory/memory_reveal_sheet.dart';
import '../shared/hero_image_view.dart';

/// In-app travel anniversary card, shown on the map screen (M91, M114, ADR-136).
///
/// Displays a 72×72 photo thumbnail, years-ago copy, and action buttons
/// ("Reveal" + dismiss). Multiple anniversaries are shown as a horizontally
/// paged [PageView] (max 3).
class MemoryPulseCard extends ConsumerWidget {
  const MemoryPulseCard({
    super.key,
    required this.memories,
    required this.onViewTrip,
    required this.service,
  });

  final List<MemoryAnniversaryPhoto> memories;

  /// Called with the tripId when the user taps "View trip". Only invoked when
  /// [MemoryAnniversaryPhoto.tripId] is non-null.
  final void Function(String tripId) onViewTrip;

  final MemoryPulseService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(memoriesDismissedProvider);
    final visible =
        memories.where((m) => !dismissed.contains(m.assetId)).toList();
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

  final MemoryAnniversaryPhoto hero;
  final void Function(String tripId) onViewTrip;
  final MemoryPulseService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CardBody(
      hero: hero,
      onDismiss: () => _dismiss(ref),
      service: service,
    );
  }

  Future<void> _dismiss(WidgetRef ref) async {
    ref
        .read(memoriesDismissedProvider.notifier)
        .update((s) => {...s, hero.assetId});
    await service.dismiss(hero.assetId, DateTime.now());
  }
}

// ── Paged cards ───────────────────────────────────────────────────────────────

class _PagedCards extends StatefulWidget {
  const _PagedCards({
    required this.memories,
    required this.onViewTrip,
    required this.service,
  });

  final List<MemoryAnniversaryPhoto> memories;
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
                builder:
                    (_, ref, __) => _CardBody(
                      hero: hero,
                      onDismiss: () async {
                        ref
                            .read(memoriesDismissedProvider.notifier)
                            .update((s) => {...s, hero.assetId});
                        await widget.service.dismiss(
                          hero.assetId,
                          DateTime.now(),
                        );
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
            color:
                i == current
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
    required this.onDismiss,
    required this.service,
  });

  final MemoryAnniversaryPhoto hero;
  final VoidCallback onDismiss;
  final MemoryPulseService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final yearsAgo = hero.yearsAgo(today);
    final question = service.buildQuestion(hero, yearsAgo);

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
          // Photo thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: HeroImageView(
                assetId: hero.assetId,
                fallbackColor: const Color(0xFF2D4A5F),
                height: 72,
                thumbnailSize: const ThumbnailSize.square(200),
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
                  question,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed:
                          () => MemoryRevealSheet.show(
                            context,
                            hero: hero,
                            yearsAgo: yearsAgo,
                            service: service,
                          ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reveal \u25b8'),
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
