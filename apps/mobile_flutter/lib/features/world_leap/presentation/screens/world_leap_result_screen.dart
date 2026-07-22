// lib/features/world_leap/presentation/screens/world_leap_result_screen.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_flutter/features/world_leap/domain/models/world_leap_failure_reason.dart';
import 'package:mobile_flutter/features/world_leap/domain/models/world_leap_run.dart';

// ── Package-private helpers (top-level, testable) ─────────────────────────────

/// Builds the share text for [run]. Package-private for testing.
String buildShareText(WorldLeapRun run) {
  final sb = StringBuffer();
  sb.writeln('🌍 World Leap — ${run.date}');
  sb.writeln('Score: ${run.totalScore}');
  sb.writeln('Countries: ${run.countryCount}');
  if (run.longestLaunchKm > 0) {
    sb.writeln('Longest launch: ${run.longestLaunchKm.toStringAsFixed(0)} km');
  }
  if (run.failureReason != null) {
    sb.writeln('Ended: ${run.failureReason!.displayName}');
  }
  sb.writeln('\nPlayed on Roavvy 🦘');
  return sb.toString();
}

/// Returns the result header message for [run]. Package-private for testing.
String resultHeader(WorldLeapRun run) {
  if (run.failureReason != null) return run.failureReason!.displayName;
  return 'Well Played!';
}

/// Returns the ordered list of country codes in the run trail.
/// Package-private for testing.
List<String> runTrail(WorldLeapRun run) => [
      run.startCountryCode,
      ...run.launches.map((l) => l.toCountryCode),
    ];

// ── Screen ────────────────────────────────────────────────────────────────────

class WorldLeapResultScreen extends StatefulWidget {
  final WorldLeapRun run;

  /// Resets the run and plays again (stays in game).
  final VoidCallback onPlayAgain;

  /// Exits the game back to the lobby.
  final VoidCallback onDone;

  const WorldLeapResultScreen({
    super.key,
    required this.run,
    required this.onPlayAgain,
    required this.onDone,
  });

  @override
  State<WorldLeapResultScreen> createState() => _WorldLeapResultScreenState();
}

class _WorldLeapResultScreenState extends State<WorldLeapResultScreen> {
  static const _gold = Color(0xFFFFD700);
  static const _darkGreen = Color(0xFF1A2A1A);
  static const _kBestScoreKey = 'world_leap_best_score';

  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _checkPersonalBest();
  }

  Future<void> _checkPersonalBest() async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getInt(_kBestScoreKey) ?? 0;
    final current = widget.run.totalScore;
    if (current > prev) {
      await prefs.setInt(_kBestScoreKey, current);
      if (mounted) setState(() => _isNewBest = true);
    }
  }

  String get _headerEmoji {
    if (widget.run.failureReason == null) return '🌍';
    switch (widget.run.failureReason!) {
      case WorldLeapFailureReason.water:
        return '💦';
      case WorldLeapFailureReason.repeatCountry:
        return '🔄';
      case WorldLeapFailureReason.sameCountry:
        return '📍';
      case WorldLeapFailureReason.invalidDestination:
        return '❌';
      case WorldLeapFailureReason.wrongCountry:
        return '🎯';
      case WorldLeapFailureReason.timeout:
        return '⏱️';
    }
  }

  Future<void> _shareResult(BuildContext context) async {
    final shareText = buildShareText(widget.run);
    await Share.share(shareText, subject: 'World Leap — ${widget.run.date}');
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final trail = runTrail(run);
    final header = resultHeader(run);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, _darkGreen],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ─────────────────────────────────────────────────
                _Header(
                  emoji: _headerEmoji,
                  title: header,
                  isSuccess: run.failureReason == null,
                  goldColor: _gold,
                ),
                if (_isNewBest) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFF8F00),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🏆',
                            style: TextStyle(fontSize: 22)),
                        SizedBox(width: 10),
                        Text(
                          'NEW PERSONAL BEST!',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('🏆',
                            style: TextStyle(fontSize: 22)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // ── Stats cards ────────────────────────────────────────────
                _StatCard(
                  label: 'Total Score',
                  value: run.totalScore.toString(),
                  isHighlight: true,
                  goldColor: _gold,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Countries',
                        value: run.countryCount.toString(),
                        goldColor: _gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Longest launch',
                        value: '${run.longestLaunchKm.toStringAsFixed(0)} km',
                        goldColor: _gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatCard(
                  label: 'Date',
                  value: run.date,
                  goldColor: _gold,
                ),
                const SizedBox(height: 32),

                // ── Country trail ──────────────────────────────────────────
                if (trail.isNotEmpty) ...[
                  Text(
                    'Your journey',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: trail.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white.withValues(alpha:0.4),
                          size: 14,
                        ),
                      ),
                      itemBuilder: (context, index) => Chip(
                        label: Text(
                          trail[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        backgroundColor: Colors.white.withValues(alpha:0.12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha:0.2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],

                // ── Actions ────────────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: () => _shareResult(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onPlayAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Play Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: widget.onDone,
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String emoji;
  final String title;
  final bool isSuccess;
  final Color goldColor;

  const _Header({
    required this.emoji,
    required this.title,
    required this.isSuccess,
    required this.goldColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 56),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        if (isSuccess) ...[
          const SizedBox(height: 8),
          Icon(Icons.star_rounded, color: goldColor, size: 36),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final Color goldColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.goldColor,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? goldColor : Colors.black87,
              fontSize: isHighlight ? 36 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
