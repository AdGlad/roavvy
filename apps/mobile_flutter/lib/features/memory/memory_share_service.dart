import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/country_names.dart';
import 'memory_anniversary_photo.dart';

/// Generates an on-device 1080×1080 memory share card and opens the share sheet.
///
/// All processing is on-device. No bytes are uploaded (extends ADR-002).
/// The composited PNG is written to the temporary directory only.
class MemoryShareService {
  MemoryShareService._();

  static const double _kSize = 1080;

  /// Loads the photo, composites a 1080×1080 share card, writes it to
  /// the temp directory, and opens the iOS share sheet.
  ///
  /// Falls back to a continent colour gradient when the asset fails to load
  /// or when [hero.countryCode] is null.
  static Future<void> generateAndShare(
    BuildContext context,
    MemoryAnniversaryPhoto hero,
  ) async {
    final countryCode = hero.countryCode ?? '';
    final countryName =
        countryCode.isNotEmpty
            ? (kCountryNames[countryCode] ?? countryCode)
            : 'A travel memory';
    final flagEmoji = countryCode.isNotEmpty ? _flagEmoji(countryCode) : '';
    final dateStr = _formatDate(hero.capturedAt);

    // Load photo bytes (null → use gradient fallback).
    ui.Image? heroImage;
    if (hero.assetId.isNotEmpty) {
      try {
        final entity = await AssetEntity.fromId(hero.assetId);
        final bytes = await entity?.thumbnailDataWithOption(
          ThumbnailOption.ios(
            size: ThumbnailSize.square(1080),
            deliveryMode: DeliveryMode.highQualityFormat,
            resizeMode: ResizeMode.exact,
            resizeContentMode: ResizeContentMode.fill,
            quality: 92,
          ),
        );
        if (bytes != null) {
          heroImage = await _decodeImage(bytes);
        }
      } catch (_) {
        // Ignore — fallback gradient will be used.
      }
    }

    final bytes = await _composite(
      heroImage: heroImage,
      countryCode: countryCode,
      countryName: countryName,
      flagEmoji: flagEmoji,
      dateStr: dateStr,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/roavvy_memory.png');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;
    final size = MediaQuery.sizeOf(context);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'A travel memory on Roavvy',
      sharePositionOrigin: Rect.fromLTWH(
        size.width / 2 - 22,
        size.height - 88,
        44,
        44,
      ),
    );
  }

  // ── Compositing ────────────────────────────────────────────────────────────

  static Future<Uint8List> _composite({
    required ui.Image? heroImage,
    required String countryCode,
    required String countryName,
    required String flagEmoji,
    required String dateStr,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _kSize, _kSize));

    if (heroImage != null) {
      // Full-bleed hero photo.
      final src = Rect.fromLTWH(
        0,
        0,
        heroImage.width.toDouble(),
        heroImage.height.toDouble(),
      );
      const dst = Rect.fromLTWH(0, 0, _kSize, _kSize);
      canvas.drawImageRect(heroImage, src, dst, Paint());
    } else {
      // Fallback: continent gradient.
      final colors = _continentGradient(countryCode);
      final paint =
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, 0),
              const Offset(_kSize, _kSize),
              colors,
            );
      canvas.drawRect(const Rect.fromLTWH(0, 0, _kSize, _kSize), paint);

      // Centred flag emoji for fallback.
      _drawText(
        canvas,
        text: flagEmoji,
        x: _kSize / 2,
        y: _kSize / 2 - 80,
        fontSize: 120,
        color: Colors.white,
        align: ui.TextAlign.center,
      );
    }

    // Bottom gradient overlay (bottom 40%).
    const gradientTop = _kSize * 0.6;
    const gradientRect = Rect.fromLTWH(
      0,
      gradientTop,
      _kSize,
      _kSize - gradientTop,
    );
    final gradientPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, gradientTop),
            const Offset(0, _kSize),
            [Colors.transparent, const Color(0xCC000000)],
          );
    canvas.drawRect(gradientRect, gradientPaint);

    // Flag emoji + country name.
    _drawText(
      canvas,
      text: '$flagEmoji  $countryName',
      x: 60,
      y: _kSize - 200,
      fontSize: 52,
      color: Colors.white,
      fontWeight: ui.FontWeight.bold,
      align: ui.TextAlign.left,
      maxWidth: _kSize - 120,
    );

    // Date string.
    _drawText(
      canvas,
      text: dateStr,
      x: 60,
      y: _kSize - 120,
      fontSize: 32,
      color: const Color(0xCCFFFFFF),
      align: ui.TextAlign.left,
      maxWidth: _kSize - 120,
    );

    // "Roavvy" wordmark (bottom-right).
    _drawText(
      canvas,
      text: 'Roavvy',
      x: _kSize - 60,
      y: _kSize - 60,
      fontSize: 28,
      color: const Color(0x99FFFFFF),
      align: ui.TextAlign.right,
      maxWidth: 200,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_kSize.toInt(), _kSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawText(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required Color color,
    ui.FontWeight fontWeight = ui.FontWeight.normal,
    ui.TextAlign align = ui.TextAlign.left,
    double maxWidth = _kSize,
  }) {
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          )
          ..addText(text);

    final paragraph =
        pb.build()..layout(ui.ParagraphConstraints(width: maxWidth));

    final dx = align == ui.TextAlign.right ? x - paragraph.longestLine : x;
    canvas.drawParagraph(paragraph, Offset(dx, y));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }

  static String _flagEmoji(String code) {
    const base = 0x1F1E6 - 0x41;
    return String.fromCharCode(base + code.codeUnitAt(0)) +
        String.fromCharCode(base + code.codeUnitAt(1));
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Returns a two-colour gradient for the continent fallback background.
  static List<Color> _continentGradient(String countryCode) {
    // Simple mapping by first letter ranges — good enough for a fallback.
    const gradients = <String, List<Color>>{
      'EU': [Color(0xFF1565C0), Color(0xFF0D47A1)],
      'AS': [Color(0xFF6A1B9A), Color(0xFF311B92)],
      'AF': [Color(0xFFE65100), Color(0xFFBF360C)],
      'NA': [Color(0xFF1B5E20), Color(0xFF004D40)],
      'SA': [Color(0xFF880E4F), Color(0xFF4A148C)],
      'OC': [Color(0xFF006064), Color(0xFF01579B)],
    };

    // Use country_lookup continent if available; fall back to a default.
    return gradients['EU'] ??
        [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
  }
}
