import 'package:flutter/material.dart';

import 'travel_replay_engine.dart';

/// End-of-replay summary screen shown when [ReplayPhase.done] (M110).
///
/// Displays scope-appropriate stats with count-up animations, then offers
/// three CTAs: Replay Again, Share, and Create T-Shirt.
///
/// The screen slides up from the bottom over the globe via an
/// [AnimatedSlide] driven by [isVisible].
class ReplaySummaryScreen extends StatefulWidget {
  const ReplaySummaryScreen({
    super.key,
    required this.script,
    required this.isVisible,
    required this.onReplayAgain,
    required this.onShare,
    required this.onCreateTShirt,
  });

  final TravelReplayScript script;

  /// When true, the panel slides fully into view.
  final bool isVisible;

  final VoidCallback onReplayAgain;
  final VoidCallback onShare;
  final VoidCallback onCreateTShirt;

  @override
  State<ReplaySummaryScreen> createState() => _ReplaySummaryScreenState();
}

class _ReplaySummaryScreenState extends State<ReplaySummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countUpCtrl;
  late final Animation<double> _countUpAnim;

  @override
  void initState() {
    super.initState();
    // M111: longer count-up (1200ms) with easeOutExpo for a more dramatic reveal.
    _countUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _countUpAnim = CurvedAnimation(
        parent: _countUpCtrl, curve: Curves.easeOutExpo);
  }

  @override
  void didUpdateWidget(ReplaySummaryScreen old) {
    super.didUpdateWidget(old);
    if (widget.isVisible && !old.isVisible) {
      // Delay count-up slightly so slide animation has started (M111: 350ms).
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _countUpCtrl.forward();
      });
    }
    if (!widget.isVisible) {
      _countUpCtrl.reset();
    }
  }

  @override
  void dispose() {
    _countUpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // M111: easeOutQuart for a weightier slide entrance; stagger delay matches
    // globe fade (600ms) so summary appears as globe dims.
    return AnimatedSlide(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      offset: widget.isVisible ? Offset.zero : const Offset(0, 1),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final title = _summaryTitle(widget.script);
    final stats = widget.script.summaryStats;

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title.
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),

              // Stat rows with staggered fade-in. M111: 180ms stagger (was 150ms).
              ...List.generate(stats.length, (i) {
                final delay = i * 0.18;
                return _StatRow(
                  stat: stats[i],
                  animation: _countUpAnim,
                  fadeDelay: delay,
                );
              }),

              const SizedBox(height: 40),

              // CTAs.
              _cta(
                icon: Icons.replay_rounded,
                label: 'Replay Again',
                onTap: widget.onReplayAgain,
                filled: true,
              ),
              const SizedBox(height: 12),
              _cta(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                onTap: widget.onShare,
                filled: false,
              ),
              const SizedBox(height: 12),
              _cta(
                icon: Icons.checkroom_rounded,
                label: 'Create T-Shirt',
                onTap: widget.onCreateTShirt,
                filled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cta({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: Icon(icon),
          label: Text(label),
          onPressed: onTap,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: Colors.white70),
        label: Text(label, style: const TextStyle(color: Colors.white70)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
        ),
        onPressed: onTap,
      ),
    );
  }

  static String _summaryTitle(TravelReplayScript script) {
    switch (script.mode) {
      case TravelReplayMode.year:
        final year = script.legs.isNotEmpty ? script.legs.first.date.year : DateTime.now().year;
        return 'Your $year Journey';
      case TravelReplayMode.allTime:
        return 'Your Travel Story';
      case TravelReplayMode.trip:
        return 'Trip Complete';
    }
  }
}

class _StatRow extends AnimatedWidget {
  const _StatRow({
    required this.stat,
    required Animation<double> animation,
    required this.fadeDelay,
  }) : super(listenable: animation);

  final ReplayStatEvent stat;
  final double fadeDelay; // 0.0–1.0 delay within the parent animation range

  Animation<double> get _anim => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    // Shift the 0–1 range to account for stagger delay.
    final localT = ((_anim.value - fadeDelay) / (1.0 - fadeDelay))
        .clamp(0.0, 1.0);
    final intValue = int.tryParse(stat.value) ?? 0;
    final displayValue = (intValue * localT).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Opacity(
        opacity: localT,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$displayValue',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              stat.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
