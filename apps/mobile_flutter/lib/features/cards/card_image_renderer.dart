import 'dart:async';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_models/shared_models.dart';

import 'card_templates.dart';
import 'front_ribbon_card.dart';
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
    String? travelerLevel,
    Color? textColor,
    int? stampSeed,
    double stampSizeMultiplier = 1.0,
    double stampJitterFactor = 0.4,
    Duration assetsTimeout = const Duration(seconds: 10),
  }) {
    final repaintKey = GlobalKey();
    final completer = Completer<CardRenderResult>();

    // Capture wasForced from PassportStampsCard.onWasForced callback (ADR-103).
    bool wasForced = false;

    // ADR-112 fix: PassportStampsCard loads SVG stamp assets asynchronously in
    // _PassportPagePainterState._loadAssets(). We must not register the capture
    // callback until onAssetsLoaded fires (after setState(_assets = loaded)),
    // otherwise _MultiStampPainter falls back to procedural StampPainter.
    //
    // Critically, render() must NOT await assetsCompleter.future itself — that
    // would block the caller's Future chain and prevent the caller from pumping
    // the widget tree (e.g. in widget tests). Instead, we chain via .then() so
    // render() returns completer.future immediately, letting the caller pump
    // freely until the capture is complete.
    final assetsCompleter =
        (template == CardTemplateType.passport || template == CardTemplateType.grid)
            ? Completer<void>()
            : null;

    late OverlayEntry entry;

    void doCapture() {
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
          entry.remove();
        }
      });
    }

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
              travelerLevel: travelerLevel,
              textColor: textColor,
              stampSeed: stampSeed,
              stampSizeMultiplier: stampSizeMultiplier,
              stampJitterFactor: stampJitterFactor,
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

    if (assetsCompleter != null) {
      // Schedule capture after SVG assets have loaded (or timed out).
      // Timeout guards against the widget being disposed before onAssetsLoaded
      // fires (e.g. user navigates away).
      assetsCompleter.future
          .timeout(assetsTimeout, onTimeout: () {})
          .then((_) => doCapture());
    } else {
      doCapture();
    }

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
    String? travelerLevel,
    Color? textColor,
    VoidCallback? onAssetsLoaded,
    int? stampSeed,
    double stampSizeMultiplier = 1.0,
    double stampJitterFactor = 0.4,
    }) {
    switch (template) {
      case CardTemplateType.frontRibbon:
        return FrontRibbonCard(
          countryCodes: codes,
          travelerLevel: travelerLevel ?? 'Explorer',
          textColor: textColor ?? Colors.white,
        );
      case CardTemplateType.grid:
        return GridFlagsCard(
          countryCodes: codes,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
          titleOverride: titleOverride,
          transparentBackground: transparentBackground,
          onAssetsLoaded: onAssetsLoaded,
        );
      case CardTemplateType.heart:
        return HeartFlagsCard(
          countryCodes: codes,
          trips: trips,
          flagOrder: heartOrder,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
          titleOverride: titleOverride,
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
          seed: stampSeed,
          sizeMultiplier: stampSizeMultiplier,
          jitterFactor: stampJitterFactor,
        );

      case CardTemplateType.timeline:
        return TimelineCard(
          countryCodes: codes,
          trips: trips,
          aspectRatio: cardAspectRatio,
          dateLabel: dateLabel,
          titleOverride: titleOverride,
          transparentBackground: transparentBackground,
        );
    }
  }
}
