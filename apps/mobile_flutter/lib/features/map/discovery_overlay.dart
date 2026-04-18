import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/country_names.dart';
import '../../core/flag_colours.dart';
import 'celebration_globe_widget.dart';

/// Gap inserted between sequential country celebrations (ADR-108).
const int kCelebrationGapMs = 300;

final _firstVisitedFmt = DateFormat('MMMM y');

/// Returns the Unicode flag emoji for a 2-letter ISO country code.
String _flagEmoji(String code) {
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
}

/// Full-screen discovery moment shown after a scan finds new countries (ADR-123).
///
/// Embeds an animated [CelebrationGlobeWidget] (spin → travel → pulse) in the
/// top half of the screen. Confetti fires with national flag colours ~2.2s
/// after the screen opens (after the globe settles).
///
/// When [totalCount] > 1, shows "Country N of M" and "Next →" / "Done" CTAs.
/// A "Skip all" button is shown on every overlay when [totalCount] > 1.
///
/// The [onDone] callback is invoked when the user taps the primary CTA on
/// the last overlay or taps "Done". [onSkipAll] is invoked when the user
/// taps "Skip all" or navigates back. Callers use these callbacks to control
/// navigation rather than relying on [popUntil] (ADR-084).
class DiscoveryOverlay extends ConsumerStatefulWidget {
  const DiscoveryOverlay({
    super.key,
    required this.isoCode,
    required this.xpEarned,
    required this.onDone,
    this.currentIndex = 0,
    this.totalCount = 1,
    this.firstVisited,
    this.onSkipAll,
  });

  static const routeName = '/discovery';

  /// ISO 3166-1 alpha-2 code of the discovered country.
  final String isoCode;

  /// XP awarded for this discovery — displayed as "+N XP".
  final int xpEarned;

  /// 0-based index of this overlay in the sequence.
  final int currentIndex;

  /// Total number of overlays in the sequence.
  final int totalCount;

  /// Earliest photo evidence date for this country, if known.
  final DateTime? firstVisited;

  /// Called when the user taps the primary CTA on the final overlay.
  final VoidCallback onDone;

  /// Called when the user taps "Skip all" or the back button.
  /// Null when [totalCount] == 1.
  final VoidCallback? onSkipAll;

  bool get _isLast => currentIndex == totalCount - 1;

  @override
  ConsumerState<DiscoveryOverlay> createState() => _DiscoveryOverlayState();
}

class _DiscoveryOverlayState extends ConsumerState<DiscoveryOverlay> {
  late final AudioPlayer _audioPlayer;
  late final ConfettiController _confettiController;
  List<Color> _confettiColors = const [Colors.amber, Colors.orange];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 3000));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _playCelebrationAudio();
      // Fire confetti after the globe settles (~2.2s into the 3s animation).
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) _confettiController.play();
      });
    });

    // Load flag colours asynchronously; update confetti when ready.
    flagColours(widget.isoCode).then((colors) {
      if (mounted && colors != null) {
        setState(() => _confettiColors = colors);
      }
    });
  }

  Future<void> _playCelebrationAudio() async {
    try {
      await _audioPlayer.play(AssetSource('audio/celebration.mp3'));
    } catch (_) {
      // Silently suppressed in test environments (MissingPluginException).
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handlePrimary() {
    if (widget._isLast) {
      widget.onDone();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleSkipAll() {
    // onSkipAll is responsible for popping this route (set by ScanSummaryScreen).
    // Do NOT call Navigator.pop() here — that would cause a double-pop and
    // remove ScanSummaryScreen, leaving the app on a blank screen (ADR-126).
    widget.onSkipAll?.call();
  }

  @override
  Widget build(BuildContext context) {
    final countryName = kCountryNames[widget.isoCode] ?? widget.isoCode;
    final flag = _flagEmoji(widget.isoCode);
    final isMulti = widget.totalCount > 1;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Skip all — top right, only in multi-country sequences.
                  if (isMulti && widget.onSkipAll != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: _handleSkipAll,
                        child: const Text(
                          'Skip all',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 44),
                  // Animated globe — the centrepiece of the celebration.
                  CelebrationGlobeWidget(isoCode: widget.isoCode),
                  const SizedBox(height: 16),
                  // Sequence indicator.
                  if (isMulti) ...[
                    Text(
                      'Country ${widget.currentIndex + 1} of ${widget.totalCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: FilledButton(
                      onPressed: _handlePrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFF6F00),
                      ),
                      child: Text(
                        widget._isLast
                            ? (widget.totalCount == 1
                                ? 'Explore your map'
                                : 'Done')
                            : 'Next →',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Confetti overlay — fires with national flag colours after globe settles.
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
      ),
    );
  }
}
