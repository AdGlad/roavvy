import 'package:flutter/material.dart';

import '../../core/country_names.dart';

// ── Shared constants ─────────────────────────────────────────────────────────

const _kAspectRatio = 3.0 / 2.0;

String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

const _kBrand = 'ROAVVY';

// ── GridFlagsCard ─────────────────────────────────────────────────────────────

/// Travel card template: flag emojis arranged in a flowing grid.
///
/// Dark navy background with amber accent. Up to 40 flags shown; overflow
/// shown as "+N more". Displays country count at the bottom.
class GridFlagsCard extends StatelessWidget {
  const GridFlagsCard({super.key, required this.countryCodes});

  final List<String> countryCodes;

  @override
  Widget build(BuildContext context) {
    const maxFlags = 40;
    final visible = countryCodes.take(maxFlags).toList();
    final overflow = countryCodes.length - visible.length;

    return AspectRatio(
      aspectRatio: _kAspectRatio,
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF0D2137)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              _kBrand,
              style: TextStyle(
                color: Color(0xFFD4A017),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: countryCodes.isEmpty
                  ? const Center(
                      child: Text(
                        'Scan your photos\nto fill your card',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final code in visible)
                          Text(_flag(code),
                              style: const TextStyle(fontSize: 18)),
                        if (overflow > 0)
                          Text(
                            '+$overflow',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${countryCodes.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'countries visited',
                    style: TextStyle(color: Color(0xFFD4A017), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── HeartFlagsCard ────────────────────────────────────────────────────────────

/// Travel card template: flag emojis on a warm amber gradient with a heart motif.
///
/// Simplified from a true ClipPath heart mask — uses a warm gradient background
/// and a semi-transparent ❤️ watermark. Visually distinct from GridFlagsCard
/// (ADR-092).
class HeartFlagsCard extends StatelessWidget {
  const HeartFlagsCard({super.key, required this.countryCodes});

  final List<String> countryCodes;

  @override
  Widget build(BuildContext context) {
    const maxFlags = 40;
    final visible = countryCodes.take(maxFlags).toList();
    final overflow = countryCodes.length - visible.length;

    return AspectRatio(
      aspectRatio: _kAspectRatio,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B2D3E), Color(0xFFB85C38)],
          ),
        ),
        child: Stack(
          children: [
            // Heart watermark
            const Positioned.fill(
              child: Center(
                child: Text(
                  '❤️',
                  style: TextStyle(fontSize: 120),
                ),
              ),
            ),
            // Content overlay
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    _kBrand,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: countryCodes.isEmpty
                        ? const Center(
                            child: Text(
                              'Scan your photos\nto fill your card',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final code in visible)
                                Text(_flag(code),
                                    style: const TextStyle(fontSize: 18)),
                              if (overflow > 0)
                                Text(
                                  '+$overflow',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${countryCodes.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'countries visited',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PassportStampsCard ────────────────────────────────────────────────────────

/// Travel card template: country "passport stamps" on a dark leather background.
///
/// Up to 12 stamps visible; each stamp shows the flag, ISO code, and country
/// name with a slight deterministic rotation. Overflow shown as "+N more".
class PassportStampsCard extends StatelessWidget {
  const PassportStampsCard({super.key, required this.countryCodes});

  final List<String> countryCodes;

  @override
  Widget build(BuildContext context) {
    const maxStamps = 12;
    final visible = countryCodes.take(maxStamps).toList();
    final overflow = countryCodes.length - visible.length;

    return AspectRatio(
      aspectRatio: _kAspectRatio,
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF2C1810)),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              _kBrand,
              style: TextStyle(
                color: Color(0xFFD4A017),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: countryCodes.isEmpty
                  ? const Center(
                      child: Text(
                        'Scan your photos\nto fill your passport',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final code in visible) _StampWidget(code: code),
                        if (overflow > 0)
                          _OverflowChip(overflow: overflow),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampWidget extends StatelessWidget {
  const _StampWidget({required this.code});

  final String code;

  /// Deterministic rotation in the range -3°..+3° based on the country code.
  double get _rotationRadians {
    final seed = (code.codeUnitAt(0) * 31 + code.codeUnitAt(1)) % 7 - 3;
    return seed * 3.14159 / 180;
  }

  @override
  Widget build(BuildContext context) {
    final name = kCountryNames[code] ?? code;
    final shortName = name.length > 10 ? name.substring(0, 9) : name;

    return Transform.rotate(
      angle: _rotationRadians,
      child: ClipRect(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD4A017), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_flag(code), style: const TextStyle(fontSize: 16)),
              Text(
                code,
                style: const TextStyle(
                  color: Color(0xFFD4A017),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                shortName,
                style: const TextStyle(color: Colors.white70, fontSize: 7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.overflow});

  final int overflow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border:
            Border.all(color: Colors.white30, width: 1.5, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '+$overflow',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
