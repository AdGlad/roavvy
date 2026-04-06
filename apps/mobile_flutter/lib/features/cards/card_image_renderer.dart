import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_models/shared_models.dart';

import 'card_templates.dart';
import 'heart_layout_engine.dart';
import 'timeline_card.dart';

/// The result of a [CardImageRenderer.render] call.
///
/// [bytes] is the PNG-encoded image. [imageHash] is the SHA-256 hex digest of
/// [bytes] (64 lowercase hex characters), suitable for storing in an
/// [ArtworkConfirmation] to tie the approval to the exact rendered pixels
/// (ADR-100).
class CardRenderResult {
  const CardRenderResult({
    required this.bytes,
    required this.imageHash,
    this.wasForced = false,
  });

  final Uint8List bytes;

  /// SHA-256 hex digest of [bytes]. Always 64 lowercase hex characters.
  final String imageHash;

  /// `true` when the passport template was rendered with `forPrint=true` and
  /// the stamp count forced `entryOnly=true` (ADR-102 / ADR-103).
  final bool wasForced;
}

/// Renders any [CardTemplateType] to PNG bytes without requiring an on-screen
/// widget. Inserts an [OverlayEntry] off-screen, captures after one frame,
/// then removes it.
///
/// Requires a live [BuildContext] (for [Overlay.of]).
class CardImageRenderer {
  CardImageRenderer._();

  /// Width of the logical card used for rendering.
  static const double _logicalWidth = 340;

  /// Renders [template] for [codes] (and optionally [trips]) to a
  /// [CardRenderResult] containing the PNG bytes and their SHA-256 hash.
  ///
  /// [pixelRatio] controls output resolution (default 3.0 → 1020 × 680 px for
  /// the default 3:2 aspect ratio).
  ///
  /// When [forPrint] is `true`, the passport template is rendered with
  /// `forPrint=true` (safe-zone margins, no edge clips, adaptive radius —
  /// ADR-102). [CardRenderResult.wasForced] will be `true` if the stamp count
  /// forced `entryOnly=true` (ADR-103).
  ///
  /// [entryOnly] — passed to [PassportStampsCard] (ADR-112).
  /// [cardAspectRatio] — aspect ratio forwarded to all templates (ADR-112).
  /// [heartOrder] — flag ordering for [HeartFlagsCard] (ADR-112).
  /// [dateLabel] — date label forwarded to all templates (ADR-112).
  static Future<CardRenderResult> render(
    BuildContext context,
    CardTemplateType template, {
    required List<String> codes,
    List<TripRecord> trips = const [],
    double pixelRatio = 3.0,
    bool forPrint = false,
    bool entryOnly = false,
    double cardAspectRatio = 3.0 / 2.0,
    HeartFlagOrder heartOrder = HeartFlagOrder.randomized,
    String dateLabel = '',
    String? titleOverride,
    Color? stampColor,
    Color? dateColor,
    bool transparentBackground = false,
  }) async {
    final repaintKey = GlobalKey();
    final completer = Completer<CardRenderResult>();
    OverlayEntry? entry;

    // Capture wasForced from PassportStampsCard.onWasForced callback (ADR-103).
    bool wasForced = false;

    // ADR-112 fix: PassportStampsCard loads SVG stamp assets asynchronously in
    // _PassportPagePainterState._loadAssets(). A single addPostFrameCallback
    // fires after frame 1, before _loadAssets() has completed, so _assets is
    // still empty and _MultiStampPainter falls back to the old procedural
    // StampPainter. We wait for the onAssetsLoaded signal (fired after
    // setState(_assets = loaded)) before scheduling the capture frame.
    final assetsCompleter = template == CardTemplateType.passport
        ? Completer<void>()
        : null;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Place far off-screen so it is invisible to the user.
        left: -10000,
        top: -10000,
        child: SizedBox(
          width: _logicalWidth,
          child: RepaintBoundary(
            key: repaintKey,
            child: _cardWidget(
              template,
              codes,
              trips,
              forPrint: forPrint,
              onWasForced: forPrint ? (v) { wasForced = v; } : null,
              entryOnly: entryOnly,
              cardAspectRatio: cardAspectRatio,
              heartOrder: heartOrder,
              dateLabel: dateLabel,
              titleOverride: titleOverride,
              stampColor: stampColor,
              dateColor: dateColor,
              transparentBackground: transparentBackground,
              onAssetsLoaded: assetsCompleter != null
                  ? () {
                      if (!assetsCompleter.isCompleted) {
                        assetsCompleter.complete();
                      }
                    }
                  : null,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    // For passport: wait until SVG stamp assets have loaded and setState has
    // been called before scheduling the capture callback. The next
    // addPostFrameCallback will then fire after the rebuilt frame that contains
    // the actual SVG stamps. Timeout guards against the widget being disposed
    // before onAssetsLoaded fires (e.g. user navigates away).
    if (assetsCompleter != null) {
      await assetsCompleter.future
          .timeout(const Duration(seconds: 10), onTimeout: () {});
    }

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
        final bytes = byteData.buffer.asUint8List();
        final imageHash = sha256.convert(bytes).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        completer.complete(CardRenderResult(
          bytes: bytes,
          imageHash: imageHash,
          wasForced: wasForced,
        ));
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        entry?.remove();
      }
    });

    return completer.future;
  }

  static Widget _cardWidget(
    CardTemplateType template,
    List<String> codes,
    List<TripRecord> trips, {
    bool forPrint = false,
    ValueChanged<bool>? onWasForced,
    bool entryOnly = false,
    double cardAspectRatio = 3.0 / 2.0,
    HeartFlagOrder heartOrder = HeartFlagOrder.randomized,
    String dateLabel = '',
    String? titleOverride,
    Color? stampColor,
    Color? dateColor,
    bool transparentBackground = false,
    VoidCallback? onAssetsLoaded,
    }) {
    switch (template) {
      case CardTemplateType.grid:
        return GridFlagsCard(
          countryCodes: codes,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
        );
      case CardTemplateType.heart:
        return HeartFlagsCard(
          countryCodes: codes,
          trips: trips,
          flagOrder: heartOrder,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
        );
      case CardTemplateType.passport:
        return PassportStampsCard(
          countryCodes: codes,
          trips: trips,
          entryOnly: entryOnly,
          forPrint: forPrint,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
          titleOverride: titleOverride,
          stampColor: stampColor,
          dateColor: dateColor,
          transparentBackground: transparentBackground,
          onWasForced: onWasForced,
          onAssetsLoaded: onAssetsLoaded,
        );

      case CardTemplateType.timeline:
        return TimelineCard(
          countryCodes: codes,
          trips: trips,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
        );
    }
  }
}
