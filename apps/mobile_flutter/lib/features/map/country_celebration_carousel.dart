import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/country_names.dart';
import '../../core/flag_colours.dart';
import 'celebration_globe_widget.dart';

final _firstVisitedFmt = DateFormat('MMMM y');

String _flagEmoji(String code) {
  const base = 0x1F1E6 - 0x41;
  if (code.length < 2) return '🌍';
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
}

/// Full-screen horizontal carousel shown after a scan finds multiple new
/// countries (ADR-126).
///
/// Replaces the sequential [DiscoveryOverlay] push/pop model: all country
/// celebrations happen inside a single route, using [PageView] for horizontal
/// progression. This eliminates:
/// - the flicker back to [ScanSummaryScreen] between countries
/// - the N-deep navigation stack (one push per country)
/// - the double-pop Skip-All bug
///
/// When [onDone] is called (last page "Done" or "Skip all"), the caller
/// is responsible for popping this route.
class CountryCelebrationCarousel extends StatefulWidget {
  const CountryCelebrationCarousel({
    super.key,
    required this.codes,
    required this.firstVisitedByCode,
    required this.onDone,
    this.xpPerCountry = 50,
  }) : assert(codes.length > 0);

  static const routeName = '/celebration-carousel';

  /// Ordered list of ISO codes to celebrate, one page each.
  final List<String> codes;

  /// First-visited date per ISO code (value may be null if unknown).
  final Map<String, DateTime?> firstVisitedByCode;

  /// Called when the user taps "Done" on the final page or "Skip all".
  /// Caller should pop this route in this callback.
  final VoidCallback onDone;

  /// XP to display per discovery.
  final int xpPerCountry;

  @override
  State<CountryCelebrationCarousel> createState() =>
      _CountryCelebrationCarouselState();
}

class _CountryCelebrationCarouselState
    extends State<CountryCelebrationCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (_currentPage < widget.codes.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.codes.length;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen gradient — consistent with DiscoveryOverlay.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
              ),
            ),
          ),
          // Page content.
          SafeArea(
            child: Column(
              children: [
                // Top bar: Skip all (right-aligned).
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: const Text(
                        'Skip all',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
                // Carousel pages.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    itemCount: total,
                    itemBuilder: (context, index) {
                      return _CelebrationPage(
                        isoCode: widget.codes[index],
                        currentIndex: index,
                        totalCount: total,
                        xpEarned: widget.xpPerCountry,
                        firstVisited: widget.firstVisitedByCode[widget.codes[index]],
                        isActive: index == _currentPage,
                        onPrimary: _advance,
                      );
                    },
                  ),
                ),
                // Page dots (≤10 countries) or text indicator (>10).
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: total <= 10
                      ? _DotIndicator(count: total, active: _currentPage)
                      : Text(
                          '${_currentPage + 1} of $total',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
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
}

// ── Individual celebration page ────────────────────────────────────────────────

class _CelebrationPage extends StatefulWidget {
  const _CelebrationPage({
    required this.isoCode,
    required this.currentIndex,
    required this.totalCount,
    required this.xpEarned,
    required this.isActive,
    required this.onPrimary,
    this.firstVisited,
  });

  final String isoCode;
  final int currentIndex;
  final int totalCount;
  final int xpEarned;
  final DateTime? firstVisited;
  final bool isActive;
  final VoidCallback onPrimary;

  bool get isLast => currentIndex == totalCount - 1;

  @override
  State<_CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<_CelebrationPage> {
  late final AudioPlayer _audioPlayer;
  late final ConfettiController _confettiController;
  List<Color> _confettiColors = const [Colors.amber, Colors.orange];
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 3000));
    flagColours(widget.isoCode).then((colors) {
      if (mounted && colors != null) {
        setState(() => _confettiColors = colors);
      }
    });
  }

  @override
  void didUpdateWidget(_CelebrationPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _onActivated();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Activate immediately if this is the first page (index 0).
    if (widget.isActive && !_activated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onActivated();
      });
    }
  }

  void _onActivated() {
    if (_activated) return;
    _activated = true;
    HapticFeedback.heavyImpact();
    _playCelebrationAudio();
    // Fire confetti after globe settles (~1.8s into the 2.8s animation).
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _confettiController.play();
    });
  }

  Future<void> _playCelebrationAudio() async {
    try {
      await _audioPlayer.play(AssetSource('audio/celebration.mp3'));
    } catch (_) {
      // Silently suppressed in test environments.
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countryName = kCountryNames[widget.isoCode] ?? widget.isoCode;
    final flag = _flagEmoji(widget.isoCode);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Animated globe — re-keyed per country so animation replays.
            CelebrationGlobeWidget(
              key: ValueKey(widget.isoCode),
              isoCode: widget.isoCode,
            ),
            const SizedBox(height: 16),
            Text(
              flag,
              style: const TextStyle(fontSize: 56),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You discovered $countryName!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '+${widget.xpEarned} XP',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.firstVisited != null) ...[
              const SizedBox(height: 6),
              Text(
                'First visited: ${_firstVisitedFmt.format(widget.firstVisited!)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: FilledButton(
                onPressed: widget.onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF6F00),
                ),
                child: Text(widget.isLast ? 'Done' : 'Next →'),
              ),
            ),
          ],
        ),
        // Confetti fires from the top-centre after globe settles.
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.04,
            gravity: 0.2,
            colors: _confettiColors,
          ),
        ),
      ],
    );
  }
}

// ── Dot progress indicator ──────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
