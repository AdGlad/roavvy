import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'passport_layout_engine.dart';
import 'passport_stamp_model.dart';
import 'stamp_asset_loader.dart';
import 'stamp_painter.dart';

/// Physical dimensions and layout constants for the Passport PDF book.
///
/// All pixel values assume 300 DPI at A6 paper size (105 mm × 148 mm).
/// (ADR-140)
abstract final class PassportPrintConfig {
  /// A6 page width at 300 DPI  (4.133 in × 300 = 1240 px).
  static const double pageWidthPx = 1240;

  /// A6 page height at 300 DPI (5.827 in × 300 = 1748 px).
  static const double pageHeightPx = 1748;

  /// Number of trips placed on each stamp page.
  /// Each trip produces an entry + exit stamp, so [tripsPerPage] = 4
  /// gives 8 stamps per page — enough for a full, well-spaced page.
  static const int tripsPerPage = 4;

  /// Scale multiplier applied to stamp radii on PDF pages.
  /// Larger than the default card value so stamps fill the A6 page.
  static const double stampSizeMultiplier = 1.8;

  /// Jitter factor for stamp placement on PDF pages.
  /// Increased from the card default (0.4) to allow natural overlap.
  static const double stampJitterFactor = 0.7;

  /// Deep navy background for cover and summary pages.
  static const Color coverBackground = Color(0xFF0A1628);

  /// Warm cream base for stamp pages (parchment feel).
  static const Color stampPageBackground = Color(0xFFF8F2E0);

  /// Gold accent colour matching the Roavvy brand.
  static const Color gold = Color(0xFFD4A017);
}

// ── Page model ────────────────────────────────────────────────────────────────

/// Type of page in the passport book.
enum PassportPdfPageType { cover, stamps, summary }

/// Represents one logical page in the passport book with its pre-computed stamps.
class PassportPdfPage {
  const PassportPdfPage({
    required this.type,
    required this.stamps,
    required this.trips,
    required this.countryCodes,
  });

  final PassportPdfPageType type;

  /// Pre-computed [StampData] items for stamp pages; empty for cover/summary.
  final List<StampData> stamps;

  /// All trips in the book (for year range on cover; list on summary).
  final List<TripRecord> trips;

  /// All country codes in the book.
  final List<String> countryCodes;
}

// ── Result ────────────────────────────────────────────────────────────────────

/// The result of [PassportPdfService.generate].
///
/// Contains both the assembled PDF bytes and the per-page PNG images so the
/// [PassportBookScreen] can display previews without re-rendering (ADR-140 §4).
class PassportPdfResult {
  const PassportPdfResult({
    required this.pdfBytes,
    required this.pages,
  });

  /// Complete multi-page PDF file bytes.
  final Uint8List pdfBytes;

  /// Per-page PNG images in page order (index 0 = cover).
  final List<Uint8List> pages;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Generates the Passport Book PDF from the user's stamp collection.
///
/// Rendering pipeline (ADR-140):
/// 1. [buildPages] distributes trips across cover + stamp + summary pages.
/// 2. [renderPage] renders each page to a PNG using [ui.PictureRecorder]:
///    - Stamp pages use real PNG assets via [StampAssetLoader] with
///      [BlendMode.multiply] ink-on-parchment compositing, falling back
///      to procedural [StampPainter] when no asset exists.
///    - Stamp pages have a guilloché passport background pattern.
/// 3. [generate] assembles page PNGs into a multi-page PDF via the `pdf` package.
///
/// Pages are rendered serially to bound peak memory (ADR-140 §5).
abstract final class PassportPdfService {
  static const _pageSize = Size(
    PassportPrintConfig.pageWidthPx,
    PassportPrintConfig.pageHeightPx,
  );

  // ── Page distribution ──────────────────────────────────────────────────────

  /// Builds the ordered list of [PassportPdfPage]s for the book.
  ///
  /// Structure: cover → N stamp pages → summary.
  /// Each stamp page holds [PassportPrintConfig.tripsPerPage] trips.
  /// Extra country codes (no trip) are appended to the last stamp page.
  /// Always produces at least one stamp page (blank parchment if no data).
  static List<PassportPdfPage> buildPages(
    List<TripRecord> trips,
    List<String> countryCodes,
  ) {
    final pages = <PassportPdfPage>[];

    pages.add(PassportPdfPage(
      type: PassportPdfPageType.cover,
      stamps: const [],
      trips: trips,
      countryCodes: countryCodes,
    ));

    final sorted = List<TripRecord>.from(trips)
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    final tripCodes = sorted.map((t) => t.countryCode).toSet();
    final extraCodes =
        countryCodes.where((c) => !tripCodes.contains(c)).toList();

    const n = PassportPrintConfig.tripsPerPage;
    final stampPageCount =
        sorted.isEmpty ? 1 : ((sorted.length + n - 1) ~/ n);

    for (var p = 0; p < stampPageCount; p++) {
      final start = p * n;
      final end = math.min(start + n, sorted.length);
      final pageTrips =
          sorted.isEmpty ? <TripRecord>[] : sorted.sublist(start, end);

      final pageCodes = pageTrips.map((t) => t.countryCode).toSet().toList();

      // Append extra codes (countries without trips) to the last stamp page.
      if (p == stampPageCount - 1 && extraCodes.isNotEmpty) {
        for (final c in extraCodes) {
          if (!pageCodes.contains(c)) pageCodes.add(c);
        }
      }

      List<StampData> stamps = const [];
      if (pageTrips.isNotEmpty || pageCodes.isNotEmpty) {
        final result = PassportLayoutEngine.layout(
          trips: pageTrips,
          countryCodes: pageCodes,
          canvasSize: _pageSize,
          forPrint: true,
          entryOnly: false,
          sizeMultiplier: PassportPrintConfig.stampSizeMultiplier,
          jitterFactor: PassportPrintConfig.stampJitterFactor,
        );
        stamps = result.stamps;
      }

      pages.add(PassportPdfPage(
        type: PassportPdfPageType.stamps,
        stamps: stamps,
        trips: sorted,
        countryCodes: countryCodes,
      ));
    }

    pages.add(PassportPdfPage(
      type: PassportPdfPageType.summary,
      stamps: const [],
      trips: sorted,
      countryCodes: countryCodes,
    ));

    return pages;
  }

  // ── Page rendering ─────────────────────────────────────────────────────────

  /// Renders [page] to a PNG [Uint8List] at A6 / 300 DPI dimensions.
  static Future<Uint8List> renderPage(PassportPdfPage page) {
    return switch (page.type) {
      PassportPdfPageType.cover => _renderCover(page),
      PassportPdfPageType.stamps => _renderStamps(page),
      PassportPdfPageType.summary => _renderSummary(page),
    };
  }

  // ── Cover ──────────────────────────────────────────────────────────────────

  static Future<Uint8List> _renderCover(PassportPdfPage page) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = PassportPrintConfig.pageWidthPx;
    const h = PassportPrintConfig.pageHeightPx;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = PassportPrintConfig.coverBackground,
    );

    // Fine horizontal microprint lines
    final linePaint = Paint()
      ..color = PassportPrintConfig.gold.withValues(alpha: 0.1)
      ..strokeWidth = 1.5;
    for (var y = 0.0; y < h; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }

    _paintCentred(canvas, 'ROAVVY',
        fontSize: 148,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 14,
        y: h * 0.37,
        maxWidth: w);

    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, h * 0.455, w * 0.6, 3),
      Paint()..color = PassportPrintConfig.gold,
    );

    _paintCentred(canvas, 'PASSPORT',
        fontSize: 60,
        fontWeight: FontWeight.w300,
        color: PassportPrintConfig.gold,
        letterSpacing: 16,
        y: h * 0.472,
        maxWidth: w);

    final range = _yearRange(page.trips);
    if (range != null) {
      _paintCentred(canvas, range,
          fontSize: 40,
          fontWeight: FontWeight.w400,
          color: Colors.white54,
          y: h * 0.88,
          maxWidth: w);
    }

    return _finish(recorder);
  }

  // ── Stamp page ─────────────────────────────────────────────────────────────

  /// Renders a stamp page using real PNG assets with guilloché background
  /// and BlendMode.multiply ink-on-parchment compositing.
  static Future<Uint8List> _renderStamps(PassportPdfPage page) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = PassportPrintConfig.pageWidthPx;
    const h = PassportPrintConfig.pageHeightPx;

    // 1. Guilloché passport page background
    _drawPassportPage(canvas, _pageSize);

    // 2. Load real PNG stamp assets (cache hit after first call per country)
    await StampAssetLoader.instance.ensureManifestLoaded();
    final assets = <String, StampAsset>{};
    for (final stamp in page.stamps) {
      final key = StampAssetLoader.assetKey(stamp.countryCode, stamp.isEntry);
      if (!assets.containsKey(key)) {
        final asset = await StampAssetLoader.instance.load(
          stamp.countryCode,
          stamp.isEntry,
        );
        if (asset != null) assets[key] = asset;
      }
    }

    // 3. Stamp compositing with BlendMode.multiply so ink darkens parchment
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..blendMode = BlendMode.multiply,
    );
    for (final stamp in page.stamps) {
      final key = StampAssetLoader.assetKey(stamp.countryCode, stamp.isEntry);
      final asset = assets[key];
      if (asset != null) {
        _drawAssetStamp(canvas, stamp, asset);
      } else {
        // Procedural fallback for countries without a PNG asset
        StampPainter(stamp).paint(canvas, _pageSize);
      }
    }
    canvas.restore(); // end multiply layer

    // 4. Vignette darkens the corners to give a physical page feel
    _drawVignette(canvas, _pageSize);

    return _finish(recorder);
  }

  // ── Summary page ───────────────────────────────────────────────────────────

  static Future<Uint8List> _renderSummary(PassportPdfPage page) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = PassportPrintConfig.pageWidthPx;
    const h = PassportPrintConfig.pageHeightPx;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = PassportPrintConfig.coverBackground,
    );

    final linePaint = Paint()
      ..color = PassportPrintConfig.gold.withValues(alpha: 0.1)
      ..strokeWidth = 1.5;
    for (var y = 0.0; y < h; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }

    _paintCentred(canvas, 'YOUR TRAVELS',
        fontSize: 72,
        fontWeight: FontWeight.w700,
        color: PassportPrintConfig.gold,
        letterSpacing: 6,
        y: 80,
        maxWidth: w);

    canvas.drawRect(
      Rect.fromLTWH(w * 0.15, 188, w * 0.7, 2),
      Paint()..color = PassportPrintConfig.gold.withValues(alpha: 0.45),
    );

    final sorted = List<String>.from(page.countryCodes)
      ..sort((a, b) {
        final na = kCountryNames[a] ?? a;
        final nb = kCountryNames[b] ?? b;
        return na.compareTo(nb);
      });

    const startY = 218.0;
    const itemH = 52.0;
    const leftX = 80.0;
    const rightX = w / 2 + 40;
    final colHeight = h - startY - 140;
    final maxPerCol = (colHeight / itemH).floor();

    for (var i = 0; i < sorted.length; i++) {
      final col = i ~/ maxPerCol;
      if (col > 1) break;
      final x = col == 0 ? leftX : rightX;
      final y = startY + (i % maxPerCol) * itemH;
      final code = sorted[i];
      final flag = _flagEmoji(code);
      final name = kCountryNames[code] ?? code;
      _paintAt(canvas, '$flag  $name',
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.88),
          x: x,
          y: y,
          maxWidth: w / 2 - 100);
    }

    final range = _yearRange(page.trips);
    final count = page.countryCodes.length;
    final countStr = '$count ${count == 1 ? 'country' : 'countries'}';
    final footer = range != null ? '$countStr · $range' : countStr;
    _paintCentred(canvas, footer,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: PassportPrintConfig.gold,
        y: h - 110,
        maxWidth: w);

    return _finish(recorder);
  }

  // ── PDF assembly ───────────────────────────────────────────────────────────

  /// Generates the full Passport Book PDF.
  static Future<PassportPdfResult> generate(
    List<TripRecord> trips,
    List<String> countryCodes,
  ) async {
    final logicalPages = buildPages(trips, countryCodes);
    final renderedPages = <Uint8List>[];

    for (final page in logicalPages) {
      renderedPages.add(await renderPage(page));
    }

    const ptW = PassportPrintConfig.pageWidthPx * 72.0 / 300.0;
    const ptH = PassportPrintConfig.pageHeightPx * 72.0 / 300.0;
    const pageFormat = PdfPageFormat(ptW, ptH);

    final doc = pw.Document();
    for (final pngBytes in renderedPages) {
      final pdfImage = pw.MemoryImage(pngBytes);
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) =>
              pw.Image(pdfImage, fit: pw.BoxFit.fill),
        ),
      );
    }

    return PassportPdfResult(
      pdfBytes: await doc.save(),
      pages: renderedPages,
    );
  }

  // ── Passport page background ───────────────────────────────────────────────

  /// Draws an authentic passport page background: warm parchment + two layers
  /// of guilloché sine-wave lines + subtle paper grain.
  static void _drawPassportPage(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Warm parchment base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = PassportPrintConfig.stampPageBackground,
    );

    // Guilloché layer 1: gold undulating lines, wider spacing
    final p1 = Paint()
      ..color = const Color(0xFFD4A017).withValues(alpha: 0.07)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const lineGap1 = 18.0;
    const amp1 = 16.0;
    final freq1 = 2 * math.pi / (w * 0.13);
    for (var baseY = 0.0; baseY < h; baseY += lineGap1) {
      final path = Path()..moveTo(0, baseY);
      for (var x = 4.0; x <= w; x += 4) {
        path.lineTo(x, baseY + amp1 * math.sin(freq1 * x));
      }
      canvas.drawPath(path, p1);
    }

    // Guilloché layer 2: steel-blue, offset phase + higher frequency
    final p2 = Paint()
      ..color = const Color(0xFF3A5A7A).withValues(alpha: 0.055)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const lineGap2 = 18.0;
    const amp2 = 9.0;
    final freq2 = 2 * math.pi / (w * 0.07);
    for (var baseY = lineGap2 / 2; baseY < h; baseY += lineGap2) {
      final path = Path()..moveTo(0, baseY);
      for (var x = 4.0; x <= w; x += 4) {
        path.lineTo(x, baseY + amp2 * math.sin(freq2 * x + math.pi * 0.4));
      }
      canvas.drawPath(path, p2);
    }

    // Subtle paper grain
    final rng = math.Random(42);
    for (var i = 0; i < 400; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * w,
          rng.nextDouble() * h,
          1 + rng.nextDouble(),
          1 + rng.nextDouble(),
        ),
        Paint()..color = const Color.fromARGB(10, 140, 110, 60),
      );
    }
  }

  // ── Stamp drawing ──────────────────────────────────────────────────────────

  /// Draws a stamp from its real PNG asset with date overlay.
  ///
  /// Mirrors the logic in `_MultiStampPainter._drawAssetStamp` so the book
  /// pages look consistent with the on-screen card preview.
  static void _drawAssetStamp(
      Canvas canvas, StampData stamp, StampAsset asset) {
    final meta = asset.metadata;
    final baseRadius = 38.0 * stamp.scale;
    final targetW = baseRadius * 2.1 * meta.visualScale;
    final targetH = targetW * (meta.imageHeight / meta.imageWidth);

    canvas.save();
    canvas.translate(stamp.center.dx, stamp.center.dy);
    canvas.rotate(stamp.rotation);

    final imgPaint = Paint()
      ..color = Colors.white.withValues(alpha: stamp.ageEffect.opacity);
    canvas.drawImageRect(
      asset.image,
      Rect.fromLTWH(0, 0, meta.imageWidth, meta.imageHeight),
      Rect.fromCenter(center: Offset.zero, width: targetW, height: targetH),
      imgPaint,
    );

    if (stamp.dateLabel != null && stamp.dateLabel!.isNotEmpty) {
      _drawDateOverlay(canvas, stamp, meta, targetW, targetH);
    }

    canvas.restore();
  }

  /// Draws the date text overlay at the position specified in [meta.dateSpec].
  static void _drawDateOverlay(
    Canvas canvas,
    StampData stamp,
    StampMetadata meta,
    double targetW,
    double targetH,
  ) {
    final spec = meta.dateSpec;
    final scaleX = targetW / meta.imageWidth;
    final scaleY = targetH / meta.imageHeight;

    final tp = TextPainter(
      text: TextSpan(
        text: stamp.dateLabel,
        style: TextStyle(
          color:
              stamp.dateColor.withValues(alpha: stamp.ageEffect.opacity),
          fontSize: spec.fontSize * scaleY,
          fontWeight: FontWeight.w700,
          letterSpacing: spec.letterSpacing * scaleX,
          fontFamily: 'Courier New',
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textLeft = spec.x * scaleX - targetW / 2 - tp.width / 2;
    final textTop = spec.y * scaleY - targetH / 2 - tp.height / 2;
    tp.paint(canvas, Offset(textLeft, textTop));
  }

  // ── Vignette ───────────────────────────────────────────────────────────────

  static void _drawVignette(Canvas canvas, Size size) {
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
            colors: const [Color(0x18000000), Color(0x00000000)],
          ).createShader(Offset.zero & size),
      );
    }
  }

  // ── Canvas helpers ─────────────────────────────────────────────────────────

  static Future<Uint8List> _finish(ui.PictureRecorder recorder) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      PassportPrintConfig.pageWidthPx.round(),
      PassportPrintConfig.pageHeightPx.round(),
    );
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  static void _paintCentred(
    Canvas canvas,
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double y,
    required double maxWidth,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset((maxWidth - tp.width) / 2, y));
  }

  static void _paintAt(
    Canvas canvas,
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double x,
    required double y,
    required double maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
  }

  static String? _yearRange(List<TripRecord> trips) {
    if (trips.isEmpty) return null;
    final years = trips.map((t) => t.startedOn.year).toList();
    final minY = years.reduce(math.min);
    final maxY = years.reduce(math.max);
    return minY == maxY ? '$minY' : '$minY – $maxY';
  }

  static String _flagEmoji(String code) {
    if (code.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
        String.fromCharCode(base + code.codeUnitAt(1) - 65);
  }
}
