import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../merch/merch_country_selection_screen.dart';
import 'country_scene_icons.dart';

final _kDayMonthYear = DateFormat('d MMM yyyy');

// ── Trip detail sheet ─────────────────────────────────────────────────────────

class TripDetailSheet extends StatelessWidget {
  const TripDetailSheet({
    super.key,
    required this.trip,
    required this.isFirstVisit,
    this.onViewOnMap,
  });

  final TripRecord trip;
  final bool isFirstVisit;
  final void Function(String countryCode)? onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.40,
      maxChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return _TripDetailContent(
          trip: trip,
          isFirstVisit: isFirstVisit,
          onViewOnMap: onViewOnMap,
          scrollController: scrollController,
        );
      },
    );
  }
}

class _TripDetailContent extends StatelessWidget {
  const _TripDetailContent({
    required this.trip,
    required this.isFirstVisit,
    required this.onViewOnMap,
    required this.scrollController,
  });

  final TripRecord trip;
  final bool isFirstVisit;
  final void Function(String countryCode)? onViewOnMap;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cc = trip.countryCode.toUpperCase();
    final countryName = kCountryNames[cc] ?? cc;
    final scene = countrySceneIcon(cc);
    final dateStr = _kDayMonthYear.format(trip.startedOn);
    final nights = trip.endedOn.difference(trip.startedOn).inDays;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Drag handle
          _DragHandle(),

          // Flag hero
          _FlagHero(cc: cc, countryName: countryName, scene: scene),

          // First-visit banner
          if (isFirstVisit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              color: cs.tertiaryContainer,
              child: Row(
                children: [
                  Text(
                    '✨ First time in $countryName',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Date row
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: dateStr,
          ),

          // Duration row
          if (nights > 0)
            _DetailRow(
              icon: Icons.nights_stay_outlined,
              label: '$nights ${nights == 1 ? 'night' : 'nights'}',
            )
          else
            _DetailRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Day trip',
            ),

          const SizedBox(height: 20),

          // Action row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'View on Map',
                    icon: Icons.map_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      onViewOnMap?.call(cc);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Design a shirt',
                    icon: Icons.checkroom_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder:
                              (_) => MerchCountrySelectionScreen(
                                preSelectedCodes: [cc],
                              ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Share',
                    icon: Icons.share_outlined,
                    onTap: () async {
                      await Share.share(
                        'I visited $countryName on $dateStr via Roavvy',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Achievement detail sheet ───────────────────────────────────────────────────

class AchievementDetailSheet extends StatelessWidget {
  const AchievementDetailSheet({super.key, required this.achievement});

  final Achievement achievement;

  static const _kEmojis = {
    1: '🌱',
    3: '⭐',
    5: '🎯',
    10: '🥈',
    15: '🥇',
    20: '🏆',
    25: '🌍',
    30: '🌎',
    40: '🌏',
    50: '💎',
    75: '👑',
    100: '🏅',
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.60,
      expand: false,
      builder: (context, scrollController) {
        return _AchievementDetailContent(
          achievement: achievement,
          scrollController: scrollController,
          emoji: _kEmojis[achievement.progressTarget] ?? '🏆',
        );
      },
    );
  }
}

class _AchievementDetailContent extends StatelessWidget {
  const _AchievementDetailContent({
    required this.achievement,
    required this.scrollController,
    required this.emoji,
  });

  final Achievement achievement;
  final ScrollController scrollController;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Drag handle
          _DragHandle(),

          const SizedBox(height: 8),

          // Achievement emoji
          Center(
            child: Text(emoji, style: const TextStyle(fontSize: 48)),
          ),

          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Countries chip
          Center(
            child: Chip(
              label: Text(
                '${achievement.progressTarget} countries reached',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: cs.secondaryContainer,
            ),
          ),

          const SizedBox(height: 20),

          // CTA button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const MerchCountrySelectionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.checkroom_outlined),
              label: const Text('Design your achievement shirt'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _FlagHero extends StatelessWidget {
  const _FlagHero({
    required this.cc,
    required this.countryName,
    required this.scene,
  });

  final String cc;
  final String countryName;
  final String scene;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // SVG flag
          SvgPicture.asset(
            'assets/flags/svg/${cc.toLowerCase()}.svg',
            fit: BoxFit.cover,
            placeholderBuilder:
                (_) => Container(
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    flagEmoji(cc),
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    cs.surface.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Country name — bottom left
          Positioned(
            left: 16,
            bottom: 12,
            right: 48,
            child: Text(
              countryName,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Scene badge — bottom right
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerLow.withValues(alpha: 0.85),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(scene, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.60)),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
