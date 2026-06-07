import 'package:flutter/material.dart';

import '../../../core/theme/roavvy_colours.dart';

/// Year-in-review summary card for the Stats screen (M147).
///
/// Shows how many countries the user has visited in the current calendar year
/// with an animated counter and an encouraging progress bar toward a personal
/// yearly target (default: 5 countries).
class YearInReviewCard extends StatelessWidget {
  const YearInReviewCard({
    super.key,
    required this.thisYearCount,
    this.yearlyTarget = 5,
  });

  final int thisYearCount;
  final int yearlyTarget;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final effective = yearlyTarget.clamp(1, 195);
    final progress = (thisYearCount / effective).clamp(0.0, 1.0);
    final remaining = (effective - thisYearCount).clamp(0, effective);
    final hitTarget = thisYearCount >= effective;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF1565C0), Color(0xFF2F80ED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F80ED).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  '$year in Review',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (hitTarget)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: RoavvyColours.roavvyGold.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: RoavvyColours.roavvyGold.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Text(
                      'Target hit!',
                      style: TextStyle(
                        color: RoavvyColours.roavvyGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Animated counter ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: thisYearCount.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => Text(
                    '${v.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    thisYearCount == 1 ? 'country' : 'countries',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Progress bar ─────────────────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  hitTarget
                      ? RoavvyColours.roavvyGold
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hitTarget
                  ? 'You hit your goal of $effective countries — amazing!'
                  : '$remaining more ${remaining == 1 ? 'country' : 'countries'} to reach your $effective-country goal',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
