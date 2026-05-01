import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_custom_carousel/flutter_custom_carousel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import 'journal_providers.dart';
import 'trip_carousel_card.dart';
import 'trip_detail_screen.dart';

/// Redesigned Journal screen using a vertical 3D 3D Rolodex Carousel.
///
/// Each trip is presented as a full-image card with animated transitions.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key, required this.onNavigateToScan});

  final VoidCallback onNavigateToScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);

    // Design Principle 3: no spinner — render nothing while loading.
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

  @override
  void initState() {
    super.initState();
    // Restore previous scroll position.
    final initialIndex = ref.read(journalCarouselIndexProvider);
    _controller = CustomCarouselScrollController(initialItem: initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('JOURNAL', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: CustomCarousel(
        controller: _controller,
        scrollDirection: Axis.vertical,
        onSelectedItemChanged: (index) {
          ref.read(journalCarouselIndexProvider.notifier).state = index;
        },
        effectsBuilder: CustomCarousel.effectsBuilderFromAnimate(
          effects: EffectList()
              // 1. Vertical Path
              .align(
                begin: const Alignment(0, -0.8),
                end: const Alignment(0, 0.8),
                curve: Curves.easeOutCubic,
              )
              // 2. Rotation (Generic rotate for now)
              .rotate(
                begin: -0.1, 
                end: 0.1,
                curve: Curves.easeInOutSine,
              )
              // 3. Dynamic Scale (Large at center)
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1.0, 1.0),
                duration: 100.ms,
                curve: Curves.easeOut,
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(0.7, 0.7),
                delay: 100.ms,
                curve: Curves.easeIn,
              )
              // 4. Fade at edges
              .fade(
                begin: 0.3,
                end: 1.0,
                duration: 100.ms,
              )
              .fade(
                begin: 1.0,
                end: 0.3,
                delay: 100.ms,
              ),
        ),
        children: widget.trips.map((trip) {
          return TripCarouselCard(
            trip: trip,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(trip: trip),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

