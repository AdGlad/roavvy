import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import 'journey_share_card.dart';

/// Renders [JourneyShareCard] off-screen at 1080×1920 (pixelRatio: 3)
/// and shares the resulting PNG via the platform share sheet.
class JourneyShareExporter {
  JourneyShareExporter._();

  static Future<void> export({
    required BuildContext context,
    required int countryCount,
    required int continentCount,
    required int sinceYear,
    required List<TripRecord> trips,
  }) async {
    // 1. Key for the off-screen RepaintBoundary.
    final key = GlobalKey();

    // 2. Insert an OverlayEntry positioned far off-screen.
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => Positioned(
            left: -4000,
            top: -4000,
            width: 360,
            height: 640,
            child: RepaintBoundary(
              key: key,
              child: Material(
                type: MaterialType.transparency,
                child: JourneyShareCard(
                  countryCount: countryCount,
                  continentCount: continentCount,
                  sinceYear: sinceYear,
                  trips: trips,
                ),
              ),
            ),
          ),
    );
    overlay.insert(entry);

    // 3. Wait for two frames so the card is fully laid out and painted.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    // 4. Capture the render object.
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    // 5. Render to image (pixelRatio: 3 → 1080×1920).
    final image = await boundary?.toImage(pixelRatio: 3.0);

    // 6. Remove the overlay entry immediately after capturing.
    entry.remove();

    if (image == null) return;

    // 7. Convert to PNG bytes.
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();

    // 8. Write to a temp file.
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/roavvy_journey_$timestamp.png');
    await file.writeAsBytes(bytes);

    // 9. Share via platform sheet.
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'My Roavvy Journey',
    );
  }
}
