import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'paper_texture_painter.dart';
import 'passport_layout_engine.dart';
import 'passport_stamp_model.dart';
import 'stamp_painter.dart';

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

/// Travel card template: authentic ink-style passport stamps on parchment.
///
/// Paper texture and stamps are drawn in a single [CustomPainter] so that
/// [BlendMode.multiply] correctly composites ink over paper texture (ADR-097).
///
/// When [trips] is non-empty, stamps show real trip dates and ENTRY/EXIT labels.
/// When empty (fallback), stamps show codes only with no date label.
class PassportStampsCard extends StatelessWidget {
  const PassportStampsCard({
    super.key,
    required this.countryCodes,
    this.trips = const [],
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _kAspectRatio,
      child: countryCodes.isEmpty
          ? const _PassportEmptyState()
          : LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    // Single unified painter: paper + stamps with BlendMode.multiply
                    Positioned.fill(
                      child: _PassportPagePainter(
                        countryCodes: countryCodes,
                        trips: trips,
                        canvasSize: size,
                      ),
                    ),
                    // ROAVVY watermark
                    Positioned(
                      bottom: 6,
                      right: 10,
                      child: Text(
                        _kBrand,
                        style: const TextStyle(
                          color: Color(0xFF8B6914),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PassportEmptyState extends StatelessWidget {
  const _PassportEmptyState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: PaperTexturePainter()),
        ),
        const Center(
          child: Text(
            'Scan your photos\nto fill your passport',
            style: TextStyle(color: Color(0xFF8B6914), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PassportPagePainter extends StatelessWidget {
  const _PassportPagePainter({
    required this.countryCodes,
    required this.trips,
    required this.canvasSize,
  });

  final List<String> countryCodes;
  final List<TripRecord> trips;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final stamps = PassportLayoutEngine.layout(
      trips: trips,
      countryCodes: countryCodes,
      canvasSize: canvasSize,
    );

    return CustomPaint(
      painter: _MultiStampPainter(stamps),
    );
  }
}

/// Unified painter: draws parchment background then stamps with
/// [BlendMode.multiply] so ink darkens the paper texture (ADR-097 Decision 9).
class _MultiStampPainter extends CustomPainter {
  const _MultiStampPainter(this.stamps);

  final List<StampData> stamps;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paper texture background (drawn directly — not in saveLayer so it
    //    acts as the "destination" for the multiply blend)
    const PaperTexturePainter().paint(canvas, size);

    // 2. Open saveLayer with BlendMode.multiply: stamps multiply over paper
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..blendMode = BlendMode.multiply,
    );

    for (final stamp in stamps) {
      // Apply edge clipping if set (partial stamp at page boundary)
      final hasClip = stamp.edgeClip != null;
      if (hasClip) {
        canvas.save();
        canvas.clipRect(stamp.edgeClip!);
      }
      StampPainter(stamp).paint(canvas, size);
      if (hasClip) {
        canvas.restore();
      }
    }

    canvas.restore(); // end BlendMode.multiply layer

    // 3. Wavy cancel lines: 2–3 faint ink strokes crossing the page
    if (stamps.isNotEmpty) {
      _drawWavyCancelLines(canvas, size, stamps.first.seed);
    }

    // 4. Vignette: subtle corner darkening (replaces PaperTexturePainter corner
    //    aging which was removed in M45)
    _drawVignette(canvas, size);
  }

  void _drawWavyCancelLines(Canvas canvas, Size size, int seed) {
    final rng = math.Random(seed ^ 0xCAB0);
    final lineCount = 2 + rng.nextInt(2); // 2–3 lines

    for (var i = 0; i < lineCount; i++) {
      final baseY = size.height * (0.22 + i * 0.28 + rng.nextDouble() * 0.06);
      final path = Path();
      path.moveTo(0, baseY);

      const segments = 8;
      final segW = size.width / segments;
      var prevY = baseY;
      for (var s = 0; s < segments; s++) {
        final x1 = s * segW + segW * 0.33;
        final x2 = s * segW + segW * 0.67;
        final x3 = (s + 1) * segW;
        final amp = size.height * 0.018 * (rng.nextDouble() * 2 - 1);
        path.cubicTo(x1, prevY + amp, x2, prevY - amp, x3, prevY + amp * 0.4);
        prevY = prevY + amp * 0.4;
      }

      final opacity = 0.06 + rng.nextDouble() * 0.06;
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3B2A1A).withValues(alpha: opacity)
          ..strokeWidth = 0.7 + rng.nextDouble() * 0.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final cornerRadius = math.min(size.width, size.height) * 0.28;
    for (final alignment in const [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ]) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: alignment,
            radius: cornerRadius / math.min(size.width, size.height),
            colors: const [
              Color(0x14000000), // 8% black
              Color(0x00000000), // transparent
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(_MultiStampPainter old) => old.stamps != stamps;
}
