import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/country_names.dart';

/// Returns the Unicode flag emoji for a 2-letter ISO country code.
String _flagEmoji(String code) {
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
}

/// Full-screen discovery moment shown after a scan finds a new country.
///
/// Fired from [ScanSummaryScreen._handleDone()] (ADR-068) for the first
/// (alphabetically sorted) newly discovered country. Fires [HeavyImpact]
/// haptic on first frame.
///
/// The "Explore your map" CTA calls [Navigator.popUntil] with route name `'/'`
/// so the full scan stack is cleared and the user lands on [MapScreen].
class DiscoveryOverlay extends StatefulWidget {
  const DiscoveryOverlay({
    super.key,
    required this.isoCode,
    required this.xpEarned,
  });

  static const routeName = '/discovery';

  /// ISO 3166-1 alpha-2 code of the discovered country.
  final String isoCode;

  /// XP awarded for this discovery — displayed as "+N XP".
  final int xpEarned;

  @override
  State<DiscoveryOverlay> createState() => _DiscoveryOverlayState();
}

class _DiscoveryOverlayState extends State<DiscoveryOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final countryName = kCountryNames[widget.isoCode] ?? widget.isoCode;
    final flag = _flagEmoji(widget.isoCode);

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
              const Spacer(),
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
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil(ModalRoute.withName('/')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF6F00),
                  ),
                  child: const Text('Explore your map'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
