import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_models/shared_models.dart';

import 'travel_card_widget.dart';

/// Renders [summary] as a [TravelCardWidget], captures it as a PNG, and opens
/// the iOS share sheet.
///
/// The widget is added to the [Overlay] at an off-screen position so it is
/// painted (giving [RepaintBoundary] a compositing layer) without being
/// visible to the user.
Future<void> captureAndShare(
  BuildContext context,
  TravelSummary summary,
  String subject,
) async {
  final key = GlobalKey();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: -10000,
      width: 300,
      height: 200,
      child: RepaintBoundary(
        key: key,
        child: TravelCardWidget(summary),
      ),
    ),
  );

  // Read MediaQuery values before any async gap.
  final screenSize = MediaQuery.sizeOf(context);
  final topPadding = MediaQuery.paddingOf(context).top;

  Overlay.of(context).insert(entry);

  // Wait for layout + paint to complete before capturing.
  await WidgetsBinding.instance.endOfFrame;

  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/roavvy_travel_card.png');
    await file.writeAsBytes(bytes);

    // iOS requires a non-zero sharePositionOrigin to anchor the share sheet.
    // We approximate the position of the ⋮ button in the top-right corner.
    final shareOrigin = Rect.fromLTWH(
      screenSize.width - 48,
      topPadding + 8,
      44,
      44,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      sharePositionOrigin: shareOrigin,
    );
  } finally {
    entry.remove();
  }
}
