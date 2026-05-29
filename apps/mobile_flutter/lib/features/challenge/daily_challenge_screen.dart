import 'dart:math' as math;
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'challenge_stats_screen.dart';
import 'daily_challenge_notifier.dart';
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset progress',
            onPressed: () => _showDevResetDialog(context, ref),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(dailyChallengeProvider)),
        data: (state) => _ChallengeBody(state: state),
      ),
    );
  }

  /// DEV ONLY: dialog to clear local progress so the challenge can be replayed.
  Future<void> _showDevResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset today\'s challenge?'),
        content: const Text(
          'This will clear your progress for today so you can replay from the beginning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    final repo = ref.read(dailyChallengeRepositoryProvider);
    await repo.deleteProgress(today);
    // Also clear the stats row so streak isn't affected by dev resets.
    await ref.read(challengeStatsServiceProvider).deleteForDate(today);
    ref.invalidate(dailyChallengeProgressProvider);
    ref.invalidate(dailyChallengeNotifierProvider);
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
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No challenge today — check back later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
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
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String siteName) async {
    if (siteName.isEmpty) return;
    final notifier = ref.read(dailyChallengeNotifierProvider.notifier);
    final correct = await notifier.submitGuess(siteName);
    if (!correct && mounted) {
      await _shakeCtrl.forward(from: 0);
    }
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
              // Remaining guess counter.
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
              ),
              if (progress.cluesRevealed < 5)
                _RevealClueButton(
                  nextClueNumber: progress.cluesRevealed + 1,
                  onPressed: () => ref
                      .read(dailyChallengeNotifierProvider.notifier)
                      .revealNextClue(),
                ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: style.color.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(style.icon, size: 15, color: style.color),
                  ),
                  const SizedBox(width: 12),
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
                        Text(clue.text, style: theme.textTheme.bodyLarge),
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

// ── Heritage site search input (autocomplete) ─────────────────────────────────

/// Autocomplete guess input backed by the bundled UNESCO WHS dataset.
///
/// Suggestions open upward (above the keyboard). Selecting a site immediately
/// submits it as a guess — the autocomplete selection IS the confirmation.
class _HeritageSiteSearchInput extends StatefulWidget {
  const _HeritageSiteSearchInput({
    required this.sites,
    required this.shakeAnimation,
    required this.onSelected,
  });

  final List<WorldHeritageSite> sites;
  final Animation<double> shakeAnimation;
  final void Function(String siteName) onSelected;

  @override
  State<_HeritageSiteSearchInput> createState() =>
      _HeritageSiteSearchInputState();
}

class _HeritageSiteSearchInputState extends State<_HeritageSiteSearchInput> {
  Key _key = UniqueKey();

  void _onSelected(WorldHeritageSite site) {
    widget.onSelected(site.name);
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
        animation: widget.shakeAnimation,
        builder: (context, child) {
          final offset =
              math.sin(widget.shakeAnimation.value * math.pi * 6) * 8;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: Autocomplete<WorldHeritageSite>(
          key: _key,
          displayStringForOption: (s) => s.name,
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          optionsBuilder: (value) {
            final q = normalizeForGuess(value.text);
            if (q.length < 2) return const Iterable.empty();
            return widget.sites
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
                        site.name,
                        style: theme.textTheme.bodyMedium
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

class _ChallengeResultOverlayState
    extends ConsumerState<_ChallengeResultOverlay> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 800));
    if (widget.solved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confetti.play();
      });
    }
    // Fly globe to site as soon as overlay opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final site = widget.state.site;
      ref.read(globeTargetProvider.notifier).state =
          (site.latitude, site.longitude);
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _goToSite() {
    Navigator.of(context).pop();
    // Globe target already set in initState; just close the screen.
  }

  void _share() {
    final p = widget.state.progress;
    final site = widget.state.site;
    final clueCount = p.solvedAtClue ?? p.cluesRevealed;
    final guessCount = p.guesses.length;
    final date = DateFormat('d MMMM yyyy').format(DateTime.now());
    final flag = _flag(site.countryCode);
    final grid = List.generate(5, (i) => i < clueCount ? '⬛' : '⬜').join();
    final resultLine = widget.solved
        ? 'Solved in $clueCount clue${clueCount == 1 ? '' : 's'}'
        : 'Not solved';
    final text =
        'Roavvy Daily — $date\n${site.name} $flag\n$resultLine · '
        '$guessCount wrong guess${guessCount == 1 ? '' : 'es'}\n$grid\nroavvy.app/daily';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
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
        // Confetti (solved only)
        if (widget.solved)
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            colors: const [
              Colors.amber,
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.purple,
            ],
          ),
        // Content sheet
        Positioned.fill(
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  // ── Hero image ────────────────────────────────────────────
                  if (site.imageUrl != null && site.imageUrl!.isNotEmpty) ...[
                    _RevealHeroImage(imageUrl: site.imageUrl!),
                    const SizedBox(height: 16),
                  ],
                  // Drag handle (shown only when no image)
                  if (site.imageUrl == null || site.imageUrl!.isEmpty)
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
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
                  // Share
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.copy),
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
