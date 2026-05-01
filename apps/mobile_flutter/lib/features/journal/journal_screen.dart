import 'package:flutter/material.dart';
import 'package:flutter_custom_carousel/flutter_custom_carousel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'journal_providers.dart';
import 'trip_carousel_card.dart';
import 'trip_detail_screen.dart';

/// Journal screen — vertical rolodex carousel of trip cards.
///
/// Cards use a custom [effectsBuilder] for correct 3D perspective: the selected
/// card is full-size and centred; adjacent cards peek above/below at ~10% scale
/// reduction with a subtle X-axis tilt and 50% opacity.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key, required this.onNavigateToScan});

  final VoidCallback onNavigateToScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);

    // No spinner — render nothing while loading.
    final trips = tripsAsync.valueOrNull;
    if (trips == null) return const SizedBox.shrink();

    if (trips.isEmpty) {
      return _EmptyState(onScanTap: onNavigateToScan);
    }

    // Sort trips descending by start date.
    final sortedTrips = List<TripRecord>.from(trips)
      ..sort((a, b) => b.startedOn.compareTo(a.startedOn));

    return _JournalCarousel(trips: sortedTrips);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScanTap});

  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, size: 48, color: secondary),
            const SizedBox(height: 16),
            Text(
              'Your journal is empty',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your photos to build your travel history.',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onScanTap,
              child: const Text('Scan Photos'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Journal Carousel ──────────────────────────────────────────────────────────

class _JournalCarousel extends ConsumerStatefulWidget {
  const _JournalCarousel({required this.trips});

  final List<TripRecord> trips;

  @override
  ConsumerState<_JournalCarousel> createState() => _JournalCarouselState();
}

class _JournalCarouselState extends ConsumerState<_JournalCarousel> {
  late final CustomCarouselScrollController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = ref.read(journalCarouselIndexProvider);
    _controller = CustomCarouselScrollController(initialItem: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.trips.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'JOURNAL',
          style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1} / $count',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topInset =
              MediaQuery.paddingOf(context).top + kToolbarHeight;
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          // Available height below the AppBar and above the home indicator.
          final availH = constraints.maxHeight - topInset - bottomInset;
          // Card takes 78 % of available height so ~11 % peeks above and below.
          final cardH = (availH * 0.78).clamp(260.0, 620.0);

          return Padding(
            padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
            child: ClipRect(
              child: CustomCarousel(
                controller: _controller,
                scrollDirection: Axis.vertical,
                // Selected card always renders in front of adjacent cards.
                depthOrder: DepthOrder.selectedInFront,
                // Show 2 cards above and below the selected card.
                itemCountBefore: 2,
                itemCountAfter: 2,
                // All cards start centred; the effectsBuilder translates them.
                alignment: Alignment.center,
                onSelectedItemChanged: (index) {
                  setState(() => _currentIndex = index);
                  ref.read(journalCarouselIndexProvider.notifier).state =
                      index;
                },
                // ── Effects ────────────────────────────────────────────────
                // scrollRatio: -1 = furthest before, 0 = selected, +1 = furthest after.
                // Adjacent cards (|t| ≈ 0.5) translate ~10 % of cardH so they
                // peek visibly; edge items translate ~20 %, shrink 10 %, and
                // fade to 50 % opacity.
                effectsBuilder: (_, scrollRatio, child) {
                  final t = scrollRatio.clamp(-1.0, 1.0);
                  final absT = t.abs();
                  return Opacity(
                    opacity: (1.0 - 0.50 * absT).clamp(0.0, 1.0),
                    child: Transform.translate(
                      // Screen-space vertical separation between cards.
                      offset: Offset(0, t * cardH * 0.20),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0007)              // perspective
                          ..scaleByDouble(1.0 - 0.10 * absT, 1.0 - 0.10 * absT, 1.0, 1.0)  // subtle size reduction
                          ..rotateX(t * 0.12),                   // ~7° X-axis tilt
                        child: child,
                      ),
                    ),
                  );
                },
                children: widget.trips.map((trip) {
                  return SizedBox(
                    height: cardH,
                    child: TripCarouselCard(
                      trip: trip,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripDetailScreen(trip: trip),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

