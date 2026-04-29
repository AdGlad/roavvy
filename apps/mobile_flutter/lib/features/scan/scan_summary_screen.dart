import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/continent_emoji.dart';
import '../../core/country_names.dart';
import '../../core/flag_colours.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../map/country_visual_state.dart';
import '../map/country_celebration_carousel.dart';
import '../map/discovery_overlay.dart';
import '../map/rovy_bubble.dart';
import '../merch/merch_country_selection_screen.dart';
import '../cards/card_type_picker_screen.dart';
import '../shared/hero_image_view.dart';
import 'achievement_unlock_sheet.dart';
import 'hero_providers.dart';
import 'level_up_sheet.dart';
import 'milestone_card_sheet.dart';
import 'scan_reveal_mini_map.dart';

/// Returns the Unicode flag emoji for a 2-letter ISO country code.
String _flagEmoji(String code) {
  const base = 0x1F1E6 - 0x41; // regional indicator A offset
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime dt) =>
    '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

/// Shown after [ReviewScreen] save completes (ADR-054).
///
/// **State A** — new countries found: hero count, country list, achievements,
/// confetti animation, and staggered row fade-in (ADR-055).
/// **State B** — nothing new: "All up to date" with last scan date.
///
/// On the primary CTA, [_handleDone] registers all [newCodes] with
/// [recentDiscoveriesProvider] then pushes [DiscoveryOverlay] for the first
/// country (ADR-068). When [newCodes] is empty, [onDone] is called directly.
class ScanSummaryScreen extends ConsumerStatefulWidget {
  const ScanSummaryScreen({
    super.key,
    required this.newCountries,
    required this.newAchievementIds,
    required this.newCodes,
    required this.onDone,
    this.lastScanAt,
    this.newTripIds = const [],
  });

  /// Countries that are new since the pre-save snapshot.
  final List<EffectiveVisitedCountry> newCountries;

  /// Achievement IDs unlocked in this save operation.
  final List<String> newAchievementIds;

  /// ISO codes of newly discovered countries (sorted alphabetically).
  /// Used to populate [recentDiscoveriesProvider] and push [DiscoveryOverlay].
  final List<String> newCodes;

  /// Called when the user taps the primary CTA and [newCodes] is empty.
  final VoidCallback onDone;

  /// Last scan timestamp — shown in State B only.
  final DateTime? lastScanAt;

  /// Trip IDs newly inferred in this scan. When non-empty, the best-shot
  /// section queries [bestHeroFromScanProvider] (M90, ADR-135).
  final List<String> newTripIds;

  @override
  ConsumerState<ScanSummaryScreen> createState() => _ScanSummaryScreenState();
}

class _ScanSummaryScreenState extends ConsumerState<ScanSummaryScreen> {
  /// Posts a [RovyMessage] via [rovyMessageProvider] if the ref is still live.
  void _postRovyMessage(RovyMessage msg) {
    if (!mounted) return;
    ref.read(rovyMessageProvider.notifier).state = msg;
  }

  /// Shows the milestone card if a new threshold has been crossed, then
  /// proceeds with [next]. Returns without calling [next] if unmounted.
  Future<void> _checkAndShowLevelUp(VoidCallback next) async {
    final currentLevel = ref.read(xpNotifierProvider).level;
    final levelUpRepo = ref.read(levelUpRepositoryProvider);
    final lastShown = await levelUpRepo.getLastShownLevel();

    if (currentLevel > lastShown) {
      await levelUpRepo.markShown(currentLevel);
      if (!mounted) return;
      final levelLabel = ref.read(xpNotifierProvider).levelLabel;
      await LevelUpSheet.show(context, levelLabel: levelLabel);
    }

    if (!mounted) return;
    next();
  }

  Future<void> _checkAndShowMilestone(VoidCallback next) async {
    final allVisits =
        ref.read(effectiveVisitsProvider).valueOrNull ?? const [];
    final milestoneRepo = ref.read(milestoneRepositoryProvider);
    final shown = await milestoneRepo.getShownThresholds();
    final threshold =
        pendingMilestoneThreshold(allVisits.length, shown);

    if (threshold != null) {
      await milestoneRepo.markShown(threshold);
      if (!mounted) return;
      await showMilestoneCardSheet(
        context,
        threshold,
        onCreateCard: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CardTypePickerScreen(),
            ),
          );
        },
      );
    }

    if (!mounted) return;
    next();
  }

  Future<void> _handleDone() async {
    // Register all new codes so CountryPolygonLayer shows gold pulse.
    if (widget.newCodes.isNotEmpty) {
      await ref
          .read(recentDiscoveriesProvider.notifier)
          .addAll(widget.newCodes);
    }

    if (!mounted) return;

    if (widget.newCodes.isNotEmpty) {
      // Fire newCountry Rovy trigger.
      final firstName = widget.newCountries.isNotEmpty
          ? (kCountryNames[widget.newCountries.first.countryCode] ??
              widget.newCountries.first.countryCode)
          : null;
      _postRovyMessage(RovyMessage(
        text: firstName != null
            ? 'Nice! You added $firstName to your map!'
            : 'New country added to your map!',
        trigger: RovyTrigger.newCountry,
        emoji: '🗺️',
      ));

      // Check 10th-country milestone for Rovy.
      final allVisits =
          ref.read(effectiveVisitsProvider).valueOrNull ?? const [];
      if (allVisits.length == 10) {
        _postRovyMessage(const RovyMessage(
          text: '10 countries explored — you\'re a real traveller!',
          trigger: RovyTrigger.milestone,
          emoji: '🏆',
        ));
      }

      // Show milestone card then push discovery overlays
      // sequentially — up to 5, one per new country. (ADR-084)
      await _checkAndShowMilestone(() async {
        if (!mounted) return;
        await _checkAndShowLevelUp(() async {
          if (!mounted) return;
          await _pushDiscoveryOverlays();
        });
      });
    } else {
      widget.onDone();
    }
  }

  /// Launches the country celebration flow for all new countries (ADR-126).
  ///
  /// For a single discovery, [DiscoveryOverlay] is used (single-country path).
  /// For multiple discoveries, [CountryCelebrationCarousel] is pushed as a
  /// single route — eliminating the repeated push/pop stack and the flicker
  /// back to this screen between countries (ADR-084, ADR-108 superseded by
  /// ADR-126 for the multi-country path).
  Future<void> _pushDiscoveryOverlays() async {
    final codes = widget.newCodes;
    final firstVisitedByCode = {
      for (final c in widget.newCountries) c.countryCode: c.firstSeen,
    };

    if (codes.length == 1) {
      // Single-country path: retain DiscoveryOverlay (simpler, no carousel).
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: DiscoveryOverlay.routeName),
          builder: (_) => DiscoveryOverlay(
            isoCode: codes.first,
            xpEarned: 50,
            firstVisited: firstVisitedByCode[codes.first],
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } else {
      // Multi-country path: single carousel push, no intermediate navigation.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings:
              const RouteSettings(name: CountryCelebrationCarousel.routeName),
          builder: (_) => CountryCelebrationCarousel(
            codes: codes,
            firstVisitedByCode: firstVisitedByCode,
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _handleCaughtUp() async {
    _postRovyMessage(const RovyMessage(
      text: 'All caught up — your map is up to date.',
      trigger: RovyTrigger.caughtUp,
      emoji: '✅',
    ));
    await _checkAndShowMilestone(
      () => _checkAndShowLevelUp(widget.onDone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: widget.newCountries.isEmpty
            ? _NothingNewState(onDone: () => _handleCaughtUp(), lastScanAt: widget.lastScanAt)
            : _NewDiscoveriesState(
                newCountries: widget.newCountries,
                newAchievementIds: widget.newAchievementIds,
                newCodes: widget.newCodes,
                newTripIds: widget.newTripIds,
                onDone: _handleDone,
              ),
      ),
    );
  }
}

// ── State A — new discoveries ─────────────────────────────────────────────────

class _NewDiscoveriesState extends ConsumerStatefulWidget {
  const _NewDiscoveriesState({
    required this.newCountries,
    required this.newAchievementIds,
    required this.newCodes,
    required this.onDone,
    this.newTripIds = const [],
  });

  final List<EffectiveVisitedCountry> newCountries;
  final List<String> newAchievementIds;
  final List<String> newCodes;
  final List<String> newTripIds;
  final Future<void> Function() onDone;

  @override
  ConsumerState<_NewDiscoveriesState> createState() =>
      _NewDiscoveriesStateState();
}

class _NewDiscoveriesStateState extends ConsumerState<_NewDiscoveriesState>
    with TickerProviderStateMixin {
  ConfettiController? _confettiController;
  AnimationController? _staggerController;
  List<Animation<double>>? _rowOpacities;
  List<Color>? _confettiColors;

  @override
  void initState() {
    super.initState();
    // Defer animation setup until after the first frame so that
    // MediaQuery is available (ADR-055).
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAnimations());
    _scheduleNotifications();
    _loadConfettiColors();
  }

  /// Loads flag colours for up to the first 3 discovered countries (ADR-108).
  Future<void> _loadConfettiColors() async {
    final colors = <Color>[];
    for (final code in widget.newCodes.take(3)) {
      final flagColors = await flagColours(code);
      if (flagColors != null) colors.addAll(flagColors);
    }
    if (mounted && colors.isNotEmpty) {
      setState(() => _confettiColors = colors);
    }
  }

  Future<void> _scheduleNotifications() async {
    final service = NotificationService.instance;

    // Request permission once, on the first scan that finds new countries.
    final alreadyRequested = await service.hasRequestedPermission();
    if (!alreadyRequested) await service.requestPermission();

    // Fire an immediate notification for each newly unlocked achievement.
    final achievementById = {for (final a in kAchievements) a.id: a};
    for (final id in widget.newAchievementIds) {
      final achievement = achievementById[id];
      if (achievement == null) continue;
      await service.scheduleAchievementUnlock(
        title: achievement.title,
        body: achievement.description,
      );
    }

    // Schedule the 30-day scan nudge (cancels any previous one).
    await service.scheduleNudge();
  }

  void _initAnimations() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return; // rows render at full opacity; no controllers

    // Confetti — one-shot burst from top-center (ADR-055).
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 2500));
    _confettiController!.play();

    // Row stagger — single controller covers the full stagger window.
    final n = widget.newCountries.length;
    final lastStart = Duration(milliseconds: (n - 1).clamp(0, 7) * 80);
    final totalMs = lastStart.inMilliseconds + 250;
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    _rowOpacities = List.generate(n, (i) {
      final startMs = i.clamp(0, 7) * 80;
      final endMs = startMs + 250;
      return CurvedAnimation(
        parent: _staggerController!,
        curve: Interval(
          startMs / totalMs,
          endMs / totalMs,
          curve: Curves.easeOut,
        ),
      );
    });

    _staggerController!.forward();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    _staggerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.newCountries.length;
    final heroLabel =
        '$n new ${n == 1 ? 'country' : 'countries'} discovered';
    final colorScheme = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main content
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero block
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Semantics(
                label: heroLabel,
                child: Column(
                  children: [
                    Text(
                      '$n',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      'new ${n == 1 ? 'country' : 'countries'} discovered',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Country list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (widget.newCodes.length >= 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ScanRevealMiniMap(
                        newCodes: widget.newCodes,
                        onDoubleTap: widget.onDone,
                      ),
                    ),
                  _FlagTimelineList(
                    newCountries: widget.newCountries,
                    rowOpacities: _rowOpacities,
                  ),
                  if (widget.newAchievementIds.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _AchievementsSection(
                        achievementIds: widget.newAchievementIds),
                  ],
                  // Best shot — only shown when hero analysis has completed
                  // and returned a result for the new trips (M90, ADR-135).
                  if (widget.newTripIds.isNotEmpty)
                    _BestShotSection(tripIds: widget.newTripIds),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // Card creation nudge — scan commerce trigger (M40)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CardTypePickerScreen(),
                  ),
                ),
                child: const Text('Create a travel card →'),
              ),
            ),
            // Secondary CTA — commerce entry point (ADR-085)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MerchCountrySelectionScreen(
                      preSelectedCodes: widget.newCodes,
                    ),
                  ),
                ),
                child: const Text('Get a poster with your new discoveries →'),
              ),
            ),
            // Primary CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: FilledButton(
                onPressed: widget.onDone,
                child: const Text('Explore your map'),
              ),
            ),
          ],
        ),
        // Confetti overlay — fills full stack area so particles can fall down
        // the entire screen (ADR-108). IgnorePointer prevents gesture conflicts.
        if (_confettiController != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController!,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.04,
                gravity: 0.2,
                shouldLoop: false,
                colors: _confettiColors ?? [
                  colorScheme.primary,
                  colorScheme.secondary,
                  Colors.amber[400]!,
                  Colors.amber[700]!,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Flag timeline — Task 149 (M43). Larger flag cards with staggered reveal.
class _FlagTimelineList extends StatelessWidget {
  const _FlagTimelineList({
    required this.newCountries,
    this.rowOpacities,
  });

  final List<EffectiveVisitedCountry> newCountries;

  /// Per-row opacity animations. When null, rows render at full opacity
  /// (reduceMotion path or before initState completes).
  final List<Animation<double>>? rowOpacities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final seenContinents = <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(newCountries.length, (i) {
        final v = newCountries[i];
        final name = kCountryNames[v.countryCode] ?? v.countryCode;
        final continent = kCountryContinent[v.countryCode];
        final isFirstOnContinent =
            continent != null && seenContinents.add(continent);

        final semanticLabel = isFirstOnContinent
            ? '$name. First country in $continent.'
            : name;

        final card = Semantics(
          label: semanticLabel,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _flagEmoji(v.countryCode),
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isFirstOnContinent)
                          Text(
                            '${kContinentEmoji[continent] ?? ''} First country in $continent',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.tertiary,
                            ),
                          )
                        else if (continent != null)
                          Text(
                            continent,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final opacity = rowOpacities != null && i < rowOpacities!.length
            ? rowOpacities![i]
            : null;
        if (opacity == null) return card;

        return FadeTransition(opacity: opacity, child: card);
      }),
    );
  }
}

/// Best shot section — shown in State A when [bestHeroFromScanProvider]
/// returns a non-null hero for the new trips (M90, ADR-135).
///
/// Hidden when hero analysis has not yet completed or found no candidates.
/// No shimmer — intentionally absent to avoid false promise of an image.
class _BestShotSection extends ConsumerWidget {
  const _BestShotSection({required this.tripIds});

  final List<String> tripIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroAsync = ref.watch(bestHeroFromScanProvider(tripIds));

    // Only render when analysis has completed AND returned a result.
    final hero = heroAsync.valueOrNull;
    if (hero == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final countryName = kCountryNames[hero.countryCode] ?? hero.countryCode;
    final fallbackColor = _continentFallback(hero.countryCode);
    final labels = [
      if (hero.primaryScene != null) hero.primaryScene!,
      if (hero.mood.isNotEmpty) hero.mood.first,
    ].take(2).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best shot from this scan',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                HeroImageView(
                  assetId: hero.assetId,
                  fallbackColor: fallbackColor,
                  height: 180,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$countryName · ${hero.capturedAt.month}/${hero.capturedAt.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (labels.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: labels
                                .map(
                                  (l) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _continentFallback(String countryCode) {
    switch (kCountryContinent[countryCode]) {
      case 'Europe':
        return const Color(0xFF2563EB);
      case 'Asia':
        return const Color(0xFF7C3AED);
      case 'North America':
        return const Color(0xFF059669);
      case 'South America':
        return const Color(0xFFD97706);
      case 'Africa':
        return const Color(0xFFDC2626);
      case 'Oceania':
        return const Color(0xFF0891B2);
      default:
        return const Color(0xFF374151);
    }
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.achievementIds});

  final List<String> achievementIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = achievementIds.length;
    final achievementById = {for (final a in kAchievements) a.id: a};
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          n == 1 ? 'Achievement unlocked' : 'Achievements unlocked',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievementIds.map((id) {
            final achievement = achievementById[id];
            final title = achievement?.title ?? id;
            return Semantics(
              label: '$title achievement unlocked. Tap to view.',
              child: ActionChip(
                avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                label: Text(title),
                onPressed: achievement == null
                    ? null
                    : () => AchievementUnlockSheet.show(
                          context,
                          achievement: achievement,
                          unlockedAt: now,
                        ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── State B — nothing new ─────────────────────────────────────────────────────

class _NothingNewState extends StatefulWidget {
  const _NothingNewState({required this.onDone, this.lastScanAt});

  final VoidCallback onDone;
  final DateTime? lastScanAt;

  @override
  State<_NothingNewState> createState() => _NothingNewStateState();
}

class _NothingNewStateState extends State<_NothingNewState> {
  @override
  void initState() {
    super.initState();
    // Schedule nudge even when nothing new found — scan still completed.
    NotificationService.instance.scheduleNudge();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'All up to date',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No new countries found this time.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.lastScanAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last scanned ${_fmtDate(widget.lastScanAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: widget.onDone,
            child: const Text('Back to map'),
          ),
        ],
      ),
    );
  }
}
