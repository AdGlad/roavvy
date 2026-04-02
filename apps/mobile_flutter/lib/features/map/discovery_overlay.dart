import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/country_names.dart';

/// Gap inserted between sequential country celebrations (ADR-108).
const int kCelebrationGapMs = 300;

final _firstVisitedFmt = DateFormat('MMMM y');

/// Returns the Unicode flag emoji for a 2-letter ISO country code.
String _flagEmoji(String code) {
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
}

/// Full-screen discovery moment shown after a scan finds new countries.
///
/// When [totalCount] > 1, shows "Country N of M" below the flag and the
/// primary CTA reads "Next →" (all but the last) or "Done" (last).
/// A "Skip all" button is shown on every overlay when [totalCount] > 1.
///
/// The [onDone] callback is invoked when the user taps the primary CTA on
/// the last overlay or taps "Done". [onSkipAll] is invoked when the user
/// taps "Skip all" or navigates back. Callers use these callbacks to control
/// navigation rather than relying on [popUntil] (ADR-084).
class DiscoveryOverlay extends StatefulWidget {
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
  State<DiscoveryOverlay> createState() => _DiscoveryOverlayState();
}

class _DiscoveryOverlayState extends State<DiscoveryOverlay> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _playCelebrationAudio();
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
    widget.onSkipAll?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final countryName = kCountryNames[widget.isoCode] ?? widget.isoCode;
    final flag = _flagEmoji(widget.isoCode);
    final isMulti = widget.totalCount > 1;

    return Scaffold(
        body: Container(
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
                  const SizedBox(height: 44), // maintain consistent top spacing
                const Spacer(),
                // Sequence indicator
                if (isMulti)
                  Text(
                    'Country ${widget.currentIndex + 1} of ${widget.totalCount}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (isMulti) const SizedBox(height: 12),
                Text(
                  flag,
                  style: const TextStyle(fontSize: 64),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'You discovered $countryName!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '+${widget.xpEarned} XP',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.firstVisited != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'First visited: ${_firstVisitedFmt.format(widget.firstVisited!)}',
                    style: const TextStyle(
                      fontSize: 14,
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
                          ? (widget.totalCount == 1 ? 'Explore your map' : 'Done')
                          : 'Next →',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
