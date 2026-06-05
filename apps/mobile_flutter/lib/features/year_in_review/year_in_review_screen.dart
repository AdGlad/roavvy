import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/providers.dart';
import '../../core/country_names.dart';
import '../merch/travel_story_data.dart';
import '../merch/travel_story_screen.dart';
import '../shared/hero_image_view.dart';
import 'year_in_review_card.dart';
import 'year_in_review_providers.dart';
import 'year_in_review_service.dart';

const _kGold = Color(0xFFD4A017);

/// Full-screen annual travel summary screen (M94, ADR-139).
///
/// Shows a hero-image trip timeline, key stats, label-driven highlights,
/// and a "Share Card" button that exports a 1080x1920 mosaic PNG.
class YearInReviewScreen extends ConsumerStatefulWidget {
  const YearInReviewScreen({super.key, required this.year});

  final int year;

  @override
  ConsumerState<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends ConsumerState<YearInReviewScreen> {
  final _shareKey = GlobalKey();
  bool _thumbsReady = false;
  bool _sharing = false;

  Future<void> _openStory(YearInReviewData data) async {
    final allVisits =
        ref.read(effectiveVisitsProvider).valueOrNull ?? const [];
    final allTrips = ref.read(tripListProvider).valueOrNull ?? const [];
    final rows =
        await ref.read(achievementRepositoryProvider).loadAllRows();
    final unlocked = {for (final r in rows) r.achievementId: r.unlockedAt};
    if (!mounted) return;
    final storyData = TravelStoryData.build(
      year: widget.year,
      allVisits: allVisits,
      allTrips: allTrips,
      unlockedAchievements: unlocked,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TravelStoryScreen(data: storyData),
      ),
    );
  }

  Future<void> _share(YearInReviewData data) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roavvy_${widget.year}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final screenSize = MediaQuery.sizeOf(context);
      final topPadding = MediaQuery.paddingOf(context).top;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My ${widget.year} in Travel — Roavvy',
        sharePositionOrigin: Rect.fromLTWH(
          screenSize.width - 48,
          topPadding + 8,
          44,
          44,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(yearInReviewDataProvider(widget.year));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: Text(
          '${widget.year} in Review',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: dataAsync.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error:
            (e, _) => Center(
              child: Text(
                'Failed to load. $e',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Text(
                'No trips recorded for ${widget.year}.',
                style: const TextStyle(fontSize: 15, color: Colors.white54),
              ),
            );
          }
          // Stack: scroll content + off-screen RepaintBoundary for share capture.
          // Off-screen placement (ADR-139) ensures the widget is painted and
          // toImage() captures real pixels (Offstage suppresses painting).
          return Stack(
            children: [
              _YearInReviewBody(
                data: data,
                thumbsReady: _thumbsReady,
                sharing: _sharing,
                onShare: () => _share(data),
                onStory: () => _openStory(data),
              ),
              Positioned(
                left: -10000,
                top: -10000,
                width: 360,
                child: RepaintBoundary(
                  key: _shareKey,
                  child: YearInReviewCardLoader(
                    data: data,
                    onThumbsReady: () => setState(() => _thumbsReady = true),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _YearInReviewBody extends StatelessWidget {
  const _YearInReviewBody({
    required this.data,
    required this.thumbsReady,
    required this.sharing,
    required this.onShare,
    required this.onStory,
  });

  final YearInReviewData data;
  final bool thumbsReady;
  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onStory;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _Header(data: data)),

        // Highlights row
        if (data.topScene != null ||
            data.topMood != null ||
            data.topActivity != null)
          SliverToBoxAdapter(child: _HighlightsRow(data: data)),

        // Section label
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'TRIPS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white38,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),

        // Trip timeline
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _TripTile(
              trip: data.trips[i],
              hero: data.heroByTripId[data.trips[i].id],
            ),
            childCount: data.trips.length,
          ),
        ),

        // Share button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: FilledButton(
              onPressed: thumbsReady && !sharing ? onShare : null,
              style: FilledButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              child:
                  sharing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                      : const Text('Share Card'),
            ),
          ),
        ),

        // Travel story entry point
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextButton.icon(
              onPressed: onStory,
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: const Text('See your travel story'),
              style: TextButton.styleFrom(foregroundColor: _kGold),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.year}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: _kGold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Year in Travel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                value: '${data.countryCount}',
                label: data.countryCount == 1 ? 'Country' : 'Countries',
              ),
              const SizedBox(width: 8),
              _StatChip(
                value: '${data.tripCount}',
                label: data.tripCount == 1 ? 'Trip' : 'Trips',
              ),
              const SizedBox(width: 8),
              _StatChip(value: '${data.totalPhotos}', label: 'Photos'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

const Map<String, String> _kLabelEmoji = {
  'beach': '🏖',
  'mountain': '⛰',
  'city': '🏙',
  'forest': '🌲',
  'desert': '🏜',
  'snow': '🌨',
  'lake': '🌊',
  'coast': '🏖',
  'island': '🏝',
  'sunset': '🌅',
  'sunrise': '🌄',
  'golden_hour': '🌅',
  'night': '🌃',
  'boat': '⛵',
  'hiking': '🥾',
  'food': '🍽',
  'people': '👥',
};

class _HighlightsRow extends StatelessWidget {
  const _HighlightsRow({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (data.topScene != null) chips.add(data.topScene!);
    if (data.topMood != null && data.topMood != data.topScene) {
      chips.add(data.topMood!);
    }
    if (data.topActivity != null && !chips.contains(data.topActivity)) {
      chips.add(data.topActivity!);
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            chips.map((label) {
              final emoji = _kLabelEmoji[label] ?? '';
              final display = _capitalise(label.replaceAll('_', ' '));
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$emoji $display',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, required this.hero});

  final TripRecord trip;
  final HeroImage? hero;

  @override
  Widget build(BuildContext context) {
    final countryName = kCountryNames[trip.countryCode] ?? trip.countryCode;
    final dateRange = _fmtRange(trip.startedOn, trip.endedOn);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: HeroImageView(
                assetId: hero?.assetId,
                fallbackColor: const Color(0xFF1A2233),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countryName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateRange,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.photoCount} photos',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _fmtRange(DateTime start, DateTime end) {
    final startStr = '${_months[start.month - 1]} ${start.day}';
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return startStr;
    }
    final endStr =
        start.month == end.month
            ? '${end.day}'
            : '${_months[end.month - 1]} ${end.day}';
    return '$startStr – $endStr';
  }
}
