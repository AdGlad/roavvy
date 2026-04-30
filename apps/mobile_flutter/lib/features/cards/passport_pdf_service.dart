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
  /// Each trip produces an entry + exit stamp = 2 stamps per trip,
  /// so [tripsPerPage] = 4 gives ~8 stamps per page.
  static const int tripsPerPage = 4;

  /// Deep navy background for cover and summary pages.
  static const Color coverBackground = Color(0xFF0A1628);

  /// Aged cream background for stamp pages.
  static const Color stampPageBackground = Color(0xFFF5F0E8);

  /// Gold accent colour matching the Roavvy brand.
  static const Color gold = Color(0xFFD4A017);
}

// ── Page model ────────────────────────────────────────────────────────────────

/// Type of page in the passport book.
enum PassportPdfPageType { cover, stamps, summary }

/// Represents one logical page in the passport book with its pre-computed stamps.
///
/// Not exposed beyond [PassportPdfService] — callers use [PassportPdfResult].
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
/// 2. [renderPage] renders each page to a PNG using [ui.PictureRecorder]
///    + [StampPainter] — all existing drawing logic is reused unchanged.
/// 3. [generate] assembles page PNGs into a multi-page PDF via the `pdf` package.
///
/// Pages are rendered serially to bound peak memory usage (ADR-140 §5).
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
  /// Always produces at least one stamp page (blank cream if no data).
  static List<PassportPdfPage> buildPages(
    List<TripRecord> trips,
    List<String> countryCodes,
  ) {
    final pages = <PassportPdfPage>[];

    // Cover
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

      // Collect country codes for this page, deduped.
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

    // Summary
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

    // Navy background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = PassportPrintConfig.coverBackground,
    );

    // Subtle horizontal microprint lines (passport aesthetic)
    final linePaint = Paint()
      ..color = PassportPrintConfig.gold.withValues(alpha: 0.1)
      ..strokeWidth = 1.5;
    for (var y = 0.0; y < h; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }

    // "ROAVVY" title
    _paintCentred(
      canvas,
      'ROAVVY',
      fontSize: 148,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: 14,
      y: h * 0.37,
      maxWidth: w,
    );

    // Gold horizontal rule
    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, h * 0.455, w * 0.6, 3),
      Paint()..color = PassportPrintConfig.gold,
    );

    // "PASSPORT" subtitle
    _paintCentred(
      canvas,
      'PASSPORT',
      fontSize: 60,
      fontWeight: FontWeight.w300,
      color: PassportPrintConfig.gold,
      letterSpacing: 16,
      y: h * 0.472,
      maxWidth: w,
    );

    // Year range at bottom
    final range = _yearRange(page.trips);
    if (range != null) {
      _paintCentred(
        canvas,
        range,
        fontSize: 40,
        fontWeight: FontWeight.w400,
        color: Colors.white54,
        y: h * 0.88,
        maxWidth: w,
      );
    }

    return _finish(recorder);
  }

  // ── Stamp page ─────────────────────────────────────────────────────────────

  static Future<Uint8List> _renderStamps(PassportPdfPage page) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = PassportPrintConfig.pageWidthPx;
    const h = PassportPrintConfig.pageHeightPx;

    // Aged cream base
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = PassportPrintConfig.stampPageBackground,
    );

    // Subtle paper grain
    final rng = math.Random(42);
    for (var i = 0; i < 600; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * w,
          rng.nextDouble() * h,
          1 + rng.nextDouble(),
          1 + rng.nextDouble(),
        ),
        Paint()..color = const Color.fromARGB(10, 140, 110, 80),
      );
    }

    // Draw each stamp using existing StampPainter (ADR-140 §2)
    for (final stamp in page.stamps) {
      StampPainter(stamp).paint(canvas, _pageSize);
    }

    return _finish(recorder);
  }

  // ── Summary page ───────────────────────────────────────────────────────────

  static Future<Uint8List> _renderSummary(PassportPdfPage page) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = PassportPrintConfig.pageWidthPx;
    const h = PassportPrintConfig.pageHeightPx;

    // Navy background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = PassportPrintConfig.coverBackground,
    );

    // Decorative lines
    final linePaint = Paint()
      ..color = PassportPrintConfig.gold.withValues(alpha: 0.1)
      ..strokeWidth = 1.5;
    for (var y = 0.0; y < h; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }

    // "YOUR TRAVELS" header
    _paintCentred(
      canvas,
      'YOUR TRAVELS',
      fontSize: 72,
      fontWeight: FontWeight.w700,
      color: PassportPrintConfig.gold,
      letterSpacing: 6,
      y: 80,
      maxWidth: w,
    );

    // Thin rule under header
    canvas.drawRect(
      Rect.fromLTWH(w * 0.15, 188, w * 0.7, 2),
      Paint()..color = PassportPrintConfig.gold.withValues(alpha: 0.45),
    );

    // Alphabetically sorted country list, 2-column layout
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
      if (col > 1) break; // max 2 columns
      final x = col == 0 ? leftX : rightX;
      final y = startY + (i % maxPerCol) * itemH;
      final code = sorted[i];
      final flag = _flagEmoji(code);
      final name = kCountryNames[code] ?? code;

      _paintAt(
        canvas,
        '$flag  $name',
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.88),
        x: x,
        y: y,
        maxWidth: w / 2 - 100,
      );
    }

    // Footer: count + year range
    final range = _yearRange(page.trips);
    final count = page.countryCodes.length;
    final countStr = '$count ${count == 1 ? 'country' : 'countries'}';
    final footer = range != null ? '$countStr · $range' : countStr;
    _paintCentred(
      canvas,
      footer,
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: PassportPrintConfig.gold,
      y: h - 110,
      maxWidth: w,
    );

    return _finish(recorder);
  }

  // ── PDF assembly ───────────────────────────────────────────────────────────

  /// Generates the full Passport Book PDF.
  ///
  /// Renders pages serially, then assembles them into a multi-page PDF.
  /// Returns a [PassportPdfResult] containing both the PDF and the preview
  /// PNGs so the caller avoids double-rendering (ADR-140 §4).
  static Future<PassportPdfResult> generate(
    List<TripRecord> trips,
    List<String> countryCodes,
  ) async {
    final logicalPages = buildPages(trips, countryCodes);
    final renderedPages = <Uint8List>[];

    // Serial rendering to bound peak memory (ADR-140 §5)
    for (final page in logicalPages) {
      renderedPages.add(await renderPage(page));
    }

    // Assemble PDF — each page = full-bleed raster image (ADR-140 §1)
    // PDF uses points (1/72 in). A6 at 300 DPI → pt = px × 72/300.
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
