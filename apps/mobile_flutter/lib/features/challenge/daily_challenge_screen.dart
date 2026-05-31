import 'dart:math' as math;
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'challenge_audio_service.dart';
import 'challenge_stats_screen.dart';
import 'daily_challenge_notifier.dart';
import 'daily_challenge_service.dart';
import 'guess_normalizer.dart';

/// Full-screen modal for the Daily Heritage Challenge.
///
/// Pushed via [Navigator.of(context).push(MaterialPageRoute(...))] from the
/// map screen. Popped automatically when the user closes or taps "Go to site".
class DailyChallengeScreen extends ConsumerWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dailyChallengeNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Challenge',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            Text(
              DateFormat('d MMMM yyyy').format(DateTime.now()),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // If the game is over, fly to the site when the screen closes.
            final state =
                ref.read(dailyChallengeNotifierProvider).valueOrNull;
            if (state != null &&
                (state.progress.solved || state.progress.failed)) {
              ref.read(globeTargetProvider.notifier).state =
                  (state.site.latitude, state.site.longitude);
              ref.read(challengeSiteHighlightProvider.notifier).state =
                  (state.site.latitude, state.site.longitude);
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh challenge',
            onPressed: () => _forceRefresh(context, ref),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading today\'s challenge…',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (e, _) => _ErrorState(onRetry: () {
          // Kick off background generation then re-fetch.
          const DailyChallengeService().prefetch();
          ref.invalidate(dailyChallengeProvider);
        }),
        data: (state) => _ChallengeBody(state: state),
      ),
    );
  }

  /// Calls the Cloud Function to generate (or re-fetch) today's challenge,
  /// then invalidates the provider so the screen reloads with fresh data.
  Future<void> _forceRefresh(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await const DailyChallengeService().forceRefresh();
      ref.invalidate(dailyChallengeProvider);
      ref.invalidate(dailyChallengeProgressProvider);
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not refresh — check your connection.')),
        );
      }
    }
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              "Today's challenge is being generated.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Retry in a few seconds.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _ChallengeBody extends ConsumerStatefulWidget {
  const _ChallengeBody({required this.state});

  final DailyChallengeState state;

  @override
  ConsumerState<_ChallengeBody> createState() => _ChallengeBodyState();
}

class _ChallengeBodyState extends ConsumerState<_ChallengeBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  final _audio = ChallengeAudioService();
  int _lastCluesRevealed = 0;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _audio.preload().ignore();
    // Record initial clue count so we can detect new reveals.
    _lastCluesRevealed = widget.state.progress.cluesRevealed;
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _submit(String siteName) async {
    if (siteName.isEmpty) return;
    final notifier = ref.read(dailyChallengeNotifierProvider.notifier);
    final correct = await notifier.submitGuess(siteName);
    if (!correct && mounted) {
      // If the game just ended (5th wrong guess), play the full fail fanfare.
      final nowOver =
          ref.read(dailyChallengeNotifierProvider).valueOrNull?.progress.failed ?? false;
      if (nowOver) {
        _audio.playFail();
      } else {
        _audio.playWrong();
        await _shakeCtrl.forward(from: 0);
        // Auto-reveal next clue after each wrong guess.
        if (mounted) {
          await ref.read(dailyChallengeNotifierProvider.notifier).revealNextClue();
        }
      }
    }
  }

  Future<void> _revealAnswer() async {
    _audio.playFail();
    await ref.read(dailyChallengeNotifierProvider.notifier).revealAnswer();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(dailyChallengeNotifierProvider);
    final state = stateAsync.valueOrNull ?? widget.state;
    final progress = state.progress;
    final clues = state.challenge.clues;
    final lastResult = state.lastGuessResult;
    final sites = ref.watch(allWhsSitesProvider).valueOrNull ?? const [];
    final guessesLeft = DailyChallengeState.maxGuesses - progress.guesses.length;
    final gameOver = progress.solved || progress.failed;

    // Play clue-reveal chime whenever a new clue becomes visible.
    ref.listen<AsyncValue<DailyChallengeState>>(dailyChallengeNotifierProvider,
        (_, next) {
      final revealed = next.valueOrNull?.progress.cluesRevealed ?? 0;
      if (revealed > _lastCluesRevealed) {
        _audio.playClue(revealed);
        _lastCluesRevealed = revealed;
      }
    });

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: progress.cluesRevealed.clamp(0, clues.length),
                itemBuilder: (context, index) => _ClueCard(
                  number: index + 1,
                  clue: clues[index],
                  imageUrl: index == 4 ? state.site.imageUrl : null,
                ),
              ),
            ),
            if (progress.guesses.isNotEmpty)
              _GuessHistory(guesses: progress.guesses),
            if (!gameOver) ...[
              // Hot/cold chip — animated in after first wrong guess.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: lastResult != null
                    ? _HotColdChip(key: ValueKey(lastResult.guess), result: lastResult)
                    : const SizedBox.shrink(),
              ),
              // Remaining guess counter — only shown after the first wrong guess.
              if (progress.guesses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      guessesLeft == 1 ? '1 guess left' : '$guessesLeft guesses left',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: guessesLeft <= 1
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              _HeritageSiteSearchInput(
                sites: sites,
                shakeAnimation: _shakeAnim,
                onSelected: _submit,
                defaultRegion: state.site.region,
              ),
              if (progress.cluesRevealed < 5)
                _RevealClueButton(
                  nextClueNumber: progress.cluesRevealed + 1,
                  onPressed: () => ref
                      .read(dailyChallengeNotifierProvider.notifier)
                      .revealNextClue(),
                )
              else
                _RevealAnswerButton(onPressed: _revealAnswer),
              const SizedBox(height: 16),
            ],
          ],
        ),
        if (gameOver)
          _ChallengeResultOverlay(state: state, solved: progress.solved),
      ],
    );
  }
}

// ── Clue card ─────────────────────────────────────────────────────────────────

class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.number, required this.clue, this.imageUrl});

  final int number;
  final ChallengeClue clue;
  final String? imageUrl;

  static ({IconData icon, Color color}) _typeStyle(String type) => switch (type) {
        'geography'   => (icon: Icons.public, color: const Color(0xFF1976D2)),
        'historical'  => (icon: Icons.history_edu_outlined, color: const Color(0xFFF9A825)),
        'location'    => (icon: Icons.place_outlined, color: const Color(0xFFFF6F00)),
        'natural'     => (icon: Icons.park_outlined, color: const Color(0xFF388E3C)),
        'direct'      => (icon: Icons.lightbulb_outlined, color: const Color(0xFF26C6DA)),
        'atmosphere'  => (icon: Icons.wb_sunny_outlined, color: const Color(0xFFFF8F00)),
        'pop_culture' => (icon: Icons.movie_outlined, color: const Color(0xFF7B1FA2)),
        _             => (icon: Icons.help_outline, color: Colors.white38),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _typeStyle(clue.type);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: style.color.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(style.icon, size: 13, color: style.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clue $number',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: style.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(clue.text, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: Image.network(
                  imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Reveal clue button ────────────────────────────────────────────────────────

class _RevealClueButton extends StatelessWidget {
  const _RevealClueButton({
    required this.nextClueNumber,
    required this.onPressed,
  });

  final int nextClueNumber;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Reveal Clue $nextClueNumber'),
      ),
    );
  }
}

// ── Reveal answer button ───────────────────────────────────────────────────────

/// Shown when all 5 clues are revealed and the player hasn't solved it yet.
/// Tapping immediately ends the game as failed and shows the result overlay.
class _RevealAnswerButton extends StatelessWidget {
  const _RevealAnswerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: const Text('Reveal Answer'),
      ),
    );
  }
}

// ── Heritage site search input (autocomplete) ─────────────────────────────────

/// Autocomplete guess input backed by the bundled UNESCO WHS dataset.
///
/// Suggestions open upward (above the keyboard). Selecting a site immediately
/// submits it as a guess — the autocomplete selection IS the confirmation.
///
/// Includes a region dropdown pre-filled with [defaultRegion] (from the first
/// clue) so the user can narrow guesses to a UNESCO region.
class _HeritageSiteSearchInput extends StatefulWidget {
  const _HeritageSiteSearchInput({
    required this.sites,
    required this.shakeAnimation,
    required this.onSelected,
    required this.defaultRegion,
  });

  final List<WorldHeritageSite> sites;
  final Animation<double> shakeAnimation;
  final void Function(String siteName) onSelected;

  /// The challenge site's UNESCO region — pre-fills the region dropdown since
  /// the first clue already reveals this information.
  final String defaultRegion;

  @override
  State<_HeritageSiteSearchInput> createState() =>
      _HeritageSiteSearchInputState();
}

/// All UNESCO regions in display order, plus the "All regions" option.
const _kAllRegions = [
  null, // null = All regions
  'Africa',
  'Arab States',
  'Asia and the Pacific',
  'Europe and North America',
  'Latin America and the Caribbean',
];

/// Returns a shorter display label for a site name, truncating at common
/// UNESCO separators while preserving enough context to identify the site.
String _shortSiteName(String name) {
  if (name.length <= 45) return name;
  for (final sep in [', the ', ' — ', ': ', ' (']) {
    final idx = name.indexOf(sep);
    if (idx > 15) return name.substring(0, idx);
  }
  return '${name.substring(0, 45)}…';
}

class _HeritageSiteSearchInputState extends State<_HeritageSiteSearchInput> {
  Key _key = UniqueKey();
  late String? _regionFilter;

  @override
  void initState() {
    super.initState();
    _regionFilter = widget.defaultRegion;
  }

  void _onSelected(WorldHeritageSite site) {
    widget.onSelected(site.name);
    setState(() => _key = UniqueKey());
  }

  List<WorldHeritageSite> get _filteredSites => _regionFilter == null
      ? widget.sites
      : widget.sites.where((s) => s.region == _regionFilter).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Region filter row
          Row(
            children: [
              const Icon(Icons.public, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _regionFilter,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('All regions',
                        style: TextStyle(fontSize: 13)),
                    style: theme.textTheme.bodySmall,
                    items: _kAllRegions
                        .map((r) => DropdownMenuItem<String?>(
                              value: r,
                              child: Text(
                                r ?? 'All regions',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (r) {
                      setState(() {
                        _regionFilter = r;
                        _key = UniqueKey();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Search autocomplete
          AnimatedBuilder(
            animation: widget.shakeAnimation,
            builder: (context, child) {
              final offset =
                  math.sin(widget.shakeAnimation.value * math.pi * 6) * 8;
              return Transform.translate(offset: Offset(offset, 0), child: child);
            },
            child: Autocomplete<WorldHeritageSite>(
              key: _key,
              displayStringForOption: (s) => _shortSiteName(s.name),
              optionsViewOpenDirection: OptionsViewOpenDirection.up,
              optionsBuilder: (value) {
                final q = normalizeForGuess(value.text);
                if (q.length < 2) return const Iterable.empty();
                return _filteredSites
                    .where((s) => normalizeForGuess(s.name).contains(q))
                    .take(8);
              },
              onSelected: _onSelected,
              fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search World Heritage Sites…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                );
              },
              optionsViewBuilder: (ctx, onSelected, options) {
                return Align(
                  alignment: Alignment.bottomLeft,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final site = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          leading: Text(
                            _flag(site.countryCode),
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            _shortSiteName(site.name),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onSelected(site),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hot/cold chip ─────────────────────────────────────────────────────────────

class _HotColdChip extends StatelessWidget {
  const _HotColdChip({super.key, required this.result});

  final GuessResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.hotColdColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.hotColdEmoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${result.hotColdLabel} — '
                '${result.distanceKm.round()} km · '
                'Travel ${result.direction}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guess history ─────────────────────────────────────────────────────────────

class _GuessHistory extends StatelessWidget {
  const _GuessHistory({required this.guesses});

  final List<String> guesses;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: guesses
            .map((g) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(g, style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Result overlay ────────────────────────────────────────────────────────────

class _ChallengeResultOverlay extends ConsumerStatefulWidget {
  const _ChallengeResultOverlay({
    required this.state,
    required this.solved,
  });

  final DailyChallengeState state;
  final bool solved;

  @override
  ConsumerState<_ChallengeResultOverlay> createState() =>
      _ChallengeResultOverlayState();
}

class _ChallengeResultOverlayState extends ConsumerState<_ChallengeResultOverlay>
    with WidgetsBindingObserver {
  late final ConfettiController _confetti;
  late final DraggableScrollableController _sheetCtrl;
  final _audio = ChallengeAudioService();

  @override
  void initState() {
    super.initState();
    _sheetCtrl = DraggableScrollableController();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addObserver(this);
    _audio.preload().then((_) {
      if (!mounted) return;
      if (widget.solved) {
        _audio.playSolve();
      } else {
        _audio.playFail();
      }
    });
    if (widget.solved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confetti.play();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetCtrl.dispose();
    _confetti.dispose();
    _audio.dispose();
    super.dispose();
  }

  /// When the app returns from background (e.g. after sharing to Messages),
  /// snap the sheet back to its initial position. This recovers from a stuck
  /// drag state caused by iOS interrupting the gesture cycle when the system
  /// share sheet opens.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sheetCtrl.isAttached) {
          _sheetCtrl.animateTo(
            0.82,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _goToSite() {
    final site = widget.state.site;
    ref.read(globeTargetProvider.notifier).state =
        (site.latitude, site.longitude);
    ref.read(challengeSiteHighlightProvider.notifier).state =
        (site.latitude, site.longitude);
    Navigator.of(context).pop();
  }

  void _share() {
    final p = widget.state.progress;
    final clueCount = p.solvedAtClue ?? p.cluesRevealed;
    final date = DateFormat('d MMMM yyyy').format(DateTime.now());
    final challengeNumber = DateTime.now()
            .toUtc()
            .difference(DateTime.utc(2026, 5, 31))
            .inDays +
        1;
    final grid = List.generate(5, (i) => i < clueCount ? '⬛' : '⬜').join();
    final text = 'Roavvy Daily #$challengeNumber — $date\n$grid';
    // No sharePositionOrigin — passing a Rect triggers UIPopoverPresentationController
    // on iOS, which can leave the touch responder chain broken after dismissal.
    Share.share(text).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final site = state.site;
    final progress = state.progress;
    final theme = Theme.of(context);
    final clueCount = progress.solvedAtClue ?? progress.cluesRevealed;
    final guessCount = progress.guesses.length;
    final flag = _flag(site.countryCode);
    final country = kCountryNames[site.countryCode] ?? site.countryCode;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Blurred backdrop
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: Colors.black54),
          ),
        ),
        // Confetti falls from top center (solved only).
        if (widget.solved)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.directional,
                blastDirection: math.pi / 2, // straight down
                numberOfParticles: 20,
                maxBlastForce: 18,
                minBlastForce: 6,
                emissionFrequency: 0.04,
                gravity: 0.3,
                colors: const [
                  Colors.amber,
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.purple,
                ],
              ),
            ),
          ),
        // Content sheet
        Positioned.fill(
          child: DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.82,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  // Drag handle — always shown at top so scrollability is clear.
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // ── Hero image ────────────────────────────────────────────
                  if (site.imageUrl != null && site.imageUrl!.isNotEmpty) ...[
                    _RevealHeroImage(imageUrl: site.imageUrl!),
                    const SizedBox(height: 16),
                  ],
                  // Solve / fail header
                  Text(
                    widget.solved ? '✅ Solved!' : '❌ Better luck tomorrow',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.solved
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Site name
                  Text(
                    site.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // Country
                  Text(
                    '$flag $country',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Metadata chips
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(label: site.inscriptionYear.toString()),
                      _MetaChip(label: _capitalise(site.category)),
                      _MetaChip(label: site.region),
                      if (site.criteria.isNotEmpty)
                        _MetaChip(
                          label: site.criteria.map((c) => 'Criterion $c').join(' · '),
                        ),
                    ],
                  ),
                  if (site.shortDescription != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      site.shortDescription!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Score summary
                  if (widget.solved) ...[
                    Text(
                      'Solved in $clueCount clue${clueCount == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (guessCount > 0)
                      Text(
                        '$guessCount wrong guess${guessCount == 1 ? '' : 'es'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  // Clue grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final revealed = i < clueCount;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          revealed
                              ? Icons.square_rounded
                              : Icons.square_outlined,
                          size: 24,
                          color: revealed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Go to site
                  FilledButton.icon(
                    onPressed: _goToSite,
                    icon: const Icon(Icons.public),
                    label: const Text('Go to site on globe'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: const Text('Share result'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  // View stats
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChallengeStatsScreen(),
                        ),
                      ),
                      child: const Text('View Stats'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reveal hero image ─────────────────────────────────────────────────────────

/// Wikipedia hero image shown at the top of the result overlay when available.
class _RevealHeroImage extends StatelessWidget {
  const _RevealHeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.landscape_outlined,
                        color: Theme.of(context).colorScheme.outline, size: 40),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© Wikipedia / CC BY-SA',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Small supporting widgets ──────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

String _capitalise(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
