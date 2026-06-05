import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'travel_story_data.dart';

/// Shareable PNG summary card rendered from [TravelStoryData] (M146).
///
/// Placed off-screen inside a [RepaintBoundary] so that [capture] can call
/// [RenderRepaintBoundary.toImage] to produce a PNG. The same technique is
/// used by [YearInReviewScreen] (ADR-139).
class TravelStorySummaryCard extends StatelessWidget {
  const TravelStorySummaryCard({super.key, required this.data});

  final TravelStoryData data;

  /// Captures the widget bound to [key] as a PNG byte list.
  ///
  /// Returns `null` if the render object is not available.
  static Future<List<int>?> capture(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Writes PNG bytes to a temp file and opens the system share sheet.
  static Future<void> shareBytes({
    required BuildContext context,
    required List<int> pngBytes,
    required int year,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/roavvy_travel_story_$year.png');
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'My $year travel story — built with Roavvy 🌍',
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = data.countryCodes.length;
    final c = data.continentCount;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E1A2B), Color(0xFF060A0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            data.identity.emoji,
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 12),
          Text(
            data.identity.displayName,
            style: const TextStyle(
              color: Color(0xFFD4A017),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.year}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$n ${n == 1 ? "country" : "countries"} · '
            '$c ${c == 1 ? "continent" : "continents"}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _FlagStrip(codes: data.countryCodes),
          const SizedBox(height: 24),
          const Text(
            'Roavvy',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flag strip (shared with story screen, local copy to avoid cross-imports) ──

class _FlagStrip extends StatelessWidget {
  const _FlagStrip({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: List.generate(math.min(codes.length, 16), (i) {
        return Text(
          _flagEmoji(codes[i]),
          style: const TextStyle(fontSize: 20),
        );
      }),
    );
  }

  String _flagEmoji(String code) {
    if (code.length != 2) return '🏳️';
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCode(base + code.codeUnitAt(0)) +
        String.fromCharCode(base + code.codeUnitAt(1));
  }
}
