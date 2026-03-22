import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/continent_emoji.dart';
import '../../core/country_names.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../map/country_visual_state.dart';
import '../map/discovery_overlay.dart';
import '../map/rovy_bubble.dart';
import 'achievement_unlock_sheet.dart';
import 'milestone_card_sheet.dart';

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
  });

  /// Countries that are new since the pre-save snapshot.
  final List<EffectiveVisitedCountry> newCountries;

  /// Achievement IDs unlocked in this save operation.
  final List<String> newAchievementIds;

  /// ISO codes of newly discovered countries (sorted alphabetically).
  /// Used to populate [recentDiscoveriesProvider] and push [DiscoveryOverlay].
  final List<String> newCodes;

  /// Called when the user taps the primary CTA and [newCodes] is empty.
  /// The caller is responsible for dismissing [ScanSummaryScreen] and
  /// returning the user to the Map tab (ADR-054).
  final VoidCallback onDone;

  /// Last scan timestamp — shown in State B only.
  final DateTime? lastScanAt;

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
      await showMilestoneCardSheet(context, threshold);
    }

    if (!mounted) return;
    next();
  }

  Future<void> _handleDone() async {
    // Register all new codes so CountryPolygonLayer shows amber pulse.
    if (widget.newCodes.isNotEmpty) {
      await ref
          .read(recentDiscoveriesProvider.notifier)
          .addAll(widget.newCodes);
    }

    if (!mounted) return;

    if (widget.newCodes.isNotEmpty) {
      // Fire newCountry Rovy trigger before the discovery overlay.
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

      // Show milestone card if a threshold was crossed, then push discovery.
      await _checkAndShowMilestone(() async {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: DiscoveryOverlay.routeName),
            builder: (_) => DiscoveryOverlay(
              isoCode: widget.newCodes.first,
              xpEarned: 50,
            ),
          ),
        );
      });
    } else {
      widget.onDone();
    }
  }

  Future<void> _handleCaughtUp() async {
    _postRovyMessage(const RovyMessage(
      text: 'All caught up — your map is up to date.',
      trigger: RovyTrigger.caughtUp,
      emoji: '✅',
    ));
    await _checkAndShowMilestone(widget.onDone);
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
                onDone: _handleDone,
              ),
      ),
    );
  }
}

// ── State A — new discoveries ─────────────────────────────────────────────────

class _NewDiscoveriesState extends StatefulWidget {
  const _NewDiscoveriesState({
    required this.newCountries,
    required this.newAchievementIds,
    required this.onDone,
  });

  final List<EffectiveVisitedCountry> newCountries;
  final List<String> newAchievementIds;
  final Future<void> Function() onDone;

  @override
  State<_NewDiscoveriesState> createState() => _NewDiscoveriesStateState();
}

class _NewDiscoveriesStateState extends State<_NewDiscoveriesState>
    with TickerProviderStateMixin {
  ConfettiController? _confettiController;
  AnimationController? _staggerController;
  List<Animation<double>>? _rowOpacities;

  @override
  void initState() {
    super.initState();
    // Defer animation setup until after the first frame so that
    // MediaQuery is available (ADR-055).
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAnimations());
    _scheduleNotifications();
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
                  _CountryList(
                    newCountries: widget.newCountries,
                    rowOpacities: _rowOpacities,
                  ),
                  if (widget.newAchievementIds.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _AchievementsSection(
                        achievementIds: widget.newAchievementIds),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // Sticky CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: widget.onDone,
                child: const Text('Explore your map'),
              ),
            ),
          ],
        ),
        // Confetti overlay — only added to tree when controller is active
        if (_confettiController != null)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              gravity: 0.2,
              shouldLoop: false,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
                Colors.amber[400]!,
                Colors.amber[700]!,
              ],
            ),
          ),
      ],
    );
  }
}

class _CountryList extends StatelessWidget {
  const _CountryList({
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

        final row = Semantics(
          label: semanticLabel,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  _flagEmoji(v.countryCode),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.bodyLarge),
                      if (isFirstOnContinent)
                        Text(
                          '${kContinentEmoji[continent] ?? ''} First country in $continent',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        final opacity = rowOpacities != null && i < rowOpacities!.length
            ? rowOpacities![i]
            : null;
        if (opacity == null) return row;

        return FadeTransition(opacity: opacity, child: row);
      }),
    );
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
