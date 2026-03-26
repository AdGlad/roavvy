import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_models/shared_models.dart';

import 'card_templates.dart';

/// Renders any [CardTemplateType] to PNG bytes without requiring an on-screen
/// widget. Inserts an [OverlayEntry] off-screen, captures after one frame,
/// then removes it.
///
/// Requires a live [BuildContext] (for [Overlay.of]).
class CardImageRenderer {
  CardImageRenderer._();

  /// Width of the logical card used for rendering.
  static const double _logicalWidth = 340;

  /// Renders [template] for [codes] (and optionally [trips]) to PNG bytes.
  ///
  /// [pixelRatio] controls output resolution (default 3.0 → 1020 × 680 px for
  /// the default 3:2 aspect ratio).
  static Future<Uint8List> render(
    BuildContext context,
    CardTemplateType template, {
    required List<String> codes,
    List<TripRecord> trips = const [],
    double pixelRatio = 3.0,
  }) async {
    final repaintKey = GlobalKey();
    final completer = Completer<Uint8List>();
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Place far off-screen so it is invisible to the user.
        left: -10000,
        top: -10000,
        child: SizedBox(
          width: _logicalWidth,
          child: RepaintBoundary(
            key: repaintKey,
            child: _cardWidget(template, codes, trips),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          completer.completeError(
              Exception('CardImageRenderer: render boundary not found'));
          return;
        }
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          completer.completeError(
              Exception('CardImageRenderer: failed to encode image'));
          return;
        }
        completer.complete(byteData.buffer.asUint8List());
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        entry?.remove();
      }
    });

    return completer.future;
  }

  static Widget _cardWidget(
      CardTemplateType template, List<String> codes, List<TripRecord> trips) {
    switch (template) {
      case CardTemplateType.grid:
        return GridFlagsCard(countryCodes: codes);
      case CardTemplateType.heart:
        return HeartFlagsCard(countryCodes: codes);
      case CardTemplateType.passport:
        return PassportStampsCard(countryCodes: codes, trips: trips);
    }
  }
}
