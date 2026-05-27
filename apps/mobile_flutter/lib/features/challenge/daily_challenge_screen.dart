import 'dart:math' as math;
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/country_names.dart';
import '../../core/providers.dart';
import 'daily_challenge_notifier.dart';

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
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(dailyChallengeProvider)),
        data: (state) => _ChallengeBody(state: state),
      ),
    );
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
  final _controller = TextEditingController();
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
    _controller.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final notifier = ref.read(dailyChallengeNotifierProvider.notifier);
    final correct = await notifier.submitGuess(text);
    if (!correct && mounted) {
      _controller.clear();
      await _shakeCtrl.forward(from: 0);
    } else if (correct && mounted) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(dailyChallengeNotifierProvider);
    final state = stateAsync.valueOrNull ?? widget.state;
    final progress = state.progress;
    final clues = state.challenge.clues;

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
                  text: clues[index],
                ),
              ),
            ),
            if (progress.guesses.isNotEmpty)
              _GuessHistory(guesses: progress.guesses),
            if (!progress.solved) ...[
              _GuessInput(
                controller: _controller,
                shakeAnimation: _shakeAnim,
                onSubmit: _submit,
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
        if (progress.solved)
          _ChallengeResultOverlay(state: state),
      ],
    );
  }
}

// ── Clue card ─────────────────────────────────────────────────────────────────

class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: theme.textTheme.bodyLarge),
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

// ── Guess input ───────────────────────────────────────────────────────────────

class _GuessInput extends StatelessWidget {
  const _GuessInput({
    required this.controller,
    required this.shakeAnimation,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final Animation<double> shakeAnimation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
        animation: shakeAnimation,
        builder: (context, child) {
          final offset = math.sin(shakeAnimation.value * math.pi * 6) * 8;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: 'Type the site name…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: onSubmit,
            ),
          ),
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
  const _ChallengeResultOverlay({required this.state});

  final DailyChallengeState state;

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
    // Fire confetti on the next frame so the overlay is fully laid out first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _goToSite() {
    final site = widget.state.site;
    Navigator.of(context).pop();
    ref.read(globeTargetProvider.notifier).state = (site.latitude, site.longitude);
  }

  void _share() {
    final p = widget.state.progress;
    final clueCount = p.solvedAtClue ?? p.cluesRevealed;
    final guessCount = p.guesses.length;
    final date = DateFormat('d MMMM yyyy').format(DateTime.now());
    final grid = List.generate(5, (i) => i < clueCount ? '⬛' : '⬜').join();
    final text =
        'Roavvy Daily — $date\n$clueCount clue${clueCount == 1 ? '' : 's'} · '
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
        // Confetti
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
        // Content card
        Positioned.fill(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Site name
                      Text(
                        site.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      // Country
                      Text(
                        '$flag $country',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Score
                      Text(
                        'Solved in $clueCount clue${clueCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (guessCount > 0)
                        Text(
                          '$guessCount wrong guess${guessCount == 1 ? '' : 'es'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 16),
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
                              size: 28,
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
                        label: const Text('Go to site'),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
